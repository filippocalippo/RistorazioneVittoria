// Supabase Edge Function to create Stripe PaymentIntent
// Deploy with: supabase functions deploy create-payment-intent
// Add secret: supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =============================================================================
// SECTION 8.2: Backend Production Readiness
// =============================================================================

// Version management
export const FUNCTION_VERSION = '1.0.0'
export const MIN_CLIENT_VERSION = '1.0.0'
export const DEPLOYED_DATE = '2026-01-27'

// Shared module imports
import { initSentry, captureException, setUserContext, addBreadcrumb } from '../_shared/sentry.ts'
import { PerformanceTracker } from '../_shared/performance.ts'
import { validateClientVersion } from '../_shared/version.ts'
import { validateRequestSignature } from '../_shared/request-validator.ts'

// =============================================================================
// CONFIGURATION
// =============================================================================

const STRIPE_SECRET_KEY: string = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const STRIPE_API_VERSION = '2023-10-16'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// SECURITY: Allowed origins for CORS
const ALLOWED_ORIGINS = [
    'capacitor://localhost',           // iOS app
    'http://localhost',                // Android app / local dev
    'https://localhost',               // Secure local dev
    'http://localhost:3000',           // Web dev server
    'http://localhost:5173',           // Vite dev server
]

// =============================================================================
// RATE LIMITING CONFIGURATION
// =============================================================================
const RATE_LIMIT_MAX_REQUESTS = 10  // 10 payment intents per hour per user
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

// SECURITY: Validation constants
const MAX_QUANTITY_PER_ITEM = 100
const MIN_QUANTITY_PER_ITEM = 1
const MAX_ITEMS_PER_ORDER = 50
const MIN_ORDER_AMOUNT_CENTS = 100  // €1.00 minimum

interface CartItem {
    menuItemId: string
    quantity: number
    sizeId?: string
    extraIngredients?: { ingredientId: string; quantity: number }[]
    removedIngredients?: { id: string }[]
    note?: string

    // Split Pizza Support
    isSplit?: boolean
    secondProductId?: string
    secondSizeId?: string
    secondExtraIngredients?: { ingredientId: string; quantity: number }[]

    // Pass-through display data
    specialOptions?: any[]
}

interface PaymentIntentRequest {
    organizationId?: string  // Multi-tenant: organization context
    items: CartItem[]
    orderType: 'delivery' | 'takeaway' | 'dine_in'
    deliveryLatitude?: number
    deliveryLongitude?: number
    currency?: string
    customerEmail?: string
    metadata?: Record<string, string>

    // Section 8.2: Request signing fields
    timestamp?: string
    nonce?: string
    signature?: string
}

interface PaymentIntentResponse {
    clientSecret: string
    paymentIntentId: string
    amount: number
    currency: string
    calculatedTotal: number
    calculatedSubtotal: number
    calculatedDeliveryFee: number
}

// Create a Stripe PaymentIntent using the REST API
async function createPaymentIntent(
    amount: number,
    currency: string,
    customerEmail?: string,
    metadata?: Record<string, string>
): Promise<{ client_secret: string; id: string }> {
    const params = new URLSearchParams()
    params.append('amount', amount.toString())
    params.append('currency', currency)
    params.append('automatic_payment_methods[enabled]', 'true')

    if (customerEmail) {
        params.append('receipt_email', customerEmail)
    }

    if (metadata) {
        for (const [key, value] of Object.entries(metadata)) {
            params.append(`metadata[${key}]`, value)
        }
    }

    const stripePerf = new PerformanceTracker('stripe_api_call', { endpoint: 'create_payment_intent' })
    const response = await fetch('https://api.stripe.com/v1/payment_intents', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Stripe-Version': STRIPE_API_VERSION,
        },
        body: params.toString(),
    })
    stripePerf.end()

    if (!response.ok) {
        const error = await response.json()
        console.error('Stripe API error:', error)
        captureException(new Error('Stripe API error'), { error, function: 'create-payment-intent' })
        throw new Error('Payment processing failed. Please try again.')
    }

    return await response.json()
}

// SECURITY: Get CORS headers based on request origin
function getCorsHeaders(req: Request): Record<string, string> {
    const origin = req.headers.get('origin') ?? ''

    // Check if origin is allowed
    const isAllowed = ALLOWED_ORIGINS.some(allowed => {
        if (allowed.includes('*')) {
            // Wildcard matching (e.g., https://*.example.com)
            const pattern = allowed.replace('*', '.*')
            return new RegExp(`^${pattern}$`).test(origin)
        }
        return allowed === origin
    })

    return {
        'Access-Control-Allow-Origin': isAllowed ? origin : ALLOWED_ORIGINS[0],
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-version, x-platform',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
}

// SECURITY: Validate cart item
function validateCartItem(item: CartItem, index: number): void {
    if (!item.menuItemId || typeof item.menuItemId !== 'string') {
        throw new Error(`Invalid item at position ${index + 1}: missing product ID`)
    }

    if (typeof item.quantity !== 'number' || !Number.isInteger(item.quantity)) {
        throw new Error(`Invalid item at position ${index + 1}: quantity must be a whole number`)
    }

    if (item.quantity < MIN_QUANTITY_PER_ITEM) {
        throw new Error(`Invalid item at position ${index + 1}: quantity must be at least ${MIN_QUANTITY_PER_ITEM}`)
    }

    if (item.quantity > MAX_QUANTITY_PER_ITEM) {
        throw new Error(`Invalid item at position ${index + 1}: quantity cannot exceed ${MAX_QUANTITY_PER_ITEM}`)
    }

    // Validate extra ingredients if present
    if (item.extraIngredients) {
        if (!Array.isArray(item.extraIngredients)) {
            throw new Error(`Invalid item at position ${index + 1}: extraIngredients must be an array`)
        }

        for (const extra of item.extraIngredients) {
            if (!extra.ingredientId || typeof extra.ingredientId !== 'string') {
                throw new Error(`Invalid item at position ${index + 1}: invalid extra ingredient ID`)
            }
            if (typeof extra.quantity !== 'number' || extra.quantity < 1 || extra.quantity > 10) {
                throw new Error(`Invalid item at position ${index + 1}: extra ingredient quantity must be between 1 and 10`)
            }
        }
    }

    // Split validation
    if (item.isSplit) {
        if (!item.secondProductId || typeof item.secondProductId !== 'string') {
            throw new Error(`Invalid item at position ${index + 1}: missing second product ID for split item`)
        }
        if (item.secondExtraIngredients) {
            if (!Array.isArray(item.secondExtraIngredients)) {
                throw new Error(`Invalid item at position ${index + 1}: secondExtraIngredients must be an array`)
            }
        }
    }
}

// Calculate delivery fee based on radial zones
async function calculateDeliveryFee(
    supabaseAdmin: ReturnType<typeof createClient>,
    orderType: string,
    subtotal: number,
    latitude?: number,
    longitude?: number,
    organizationId?: string
): Promise<number> {
    const deliveryPerf = new PerformanceTracker('calculate_delivery_fee')

    // No delivery fee for non-delivery orders
    if (orderType !== 'delivery') {
        deliveryPerf.end({ orderType, reason: 'not_delivery' })
        return 0
    }

    // Fetch delivery configuration
    const configPerf = new PerformanceTracker('db_query', { table: 'delivery_configuration' })
    const { data: config } = await supabaseAdmin
        .from('delivery_configuration')
        .select('*')
        .eq('organization_id', organizationId ?? '')
        .limit(1)
        .maybeSingle()
    configPerf.end()

    if (!config) {
        // Default delivery fee if no config
        deliveryPerf.end({ orderType, reason: 'no_config' })
        return 3.00
    }

    // Check Free Delivery Threshold
    if (config.consegna_gratuita_sopra && config.consegna_gratuita_sopra > 0) {
        if (subtotal >= config.consegna_gratuita_sopra) {
            deliveryPerf.end({ orderType, reason: 'free_threshold' })
            return 0.0
        }
    }

    // Fetch pizzeria coordinates
    const pizzeriaPerf = new PerformanceTracker('db_query', { table: 'business_rules' })
    const { data: pizzeria } = await supabaseAdmin
        .from('business_rules')
        .select('latitude, longitude')
        .eq('organization_id', organizationId ?? '')
        .limit(1)
        .maybeSingle()
    pizzeriaPerf.end()

    // If no coordinates provided or pizzeria location unknown, use base fee
    if (!latitude || !longitude || !pizzeria?.latitude || !pizzeria?.longitude) {
        deliveryPerf.end({ orderType, reason: 'no_coordinates' })
        return config.costo_consegna_base ?? 3.00
    }

    // Calculate distance using Haversine formula
    const R = 6371 // Earth's radius in km
    const dLat = (latitude - pizzeria.latitude) * Math.PI / 180
    const dLon = (longitude - pizzeria.longitude) * Math.PI / 180
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(pizzeria.latitude * Math.PI / 180) * Math.cos(latitude * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    const distance = R * c

    // Radial Calculation
    if (config.tipo_calcolo_consegna === 'radiale' && config.costo_consegna_radiale) {
        const tiers = config.costo_consegna_radiale as { km: number, price: number }[]
        // Sort tiers by distance
        tiers.sort((a, b) => a.km - b.km)

        for (const tier of tiers) {
            if (distance <= tier.km) {
                deliveryPerf.end({ orderType, method: 'radial', distance: distance.toFixed(2) })
                return tier.price
            }
        }
        // Outside max radius
        deliveryPerf.end({ orderType, method: 'radial', distance: distance.toFixed(2), reason: 'outside_radius' })
        return config.prezzo_fuori_raggio ?? config.costo_consegna_base ?? 3.00
    }

    // Per KM Calculation
    if (config.tipo_calcolo_consegna === 'per_km') {
        const baseFee = config.costo_consegna_base ?? 3.00
        const perKmFee = config.costo_consegna_per_km ?? 0.50
        const fee = baseFee + (distance * perKmFee)
        deliveryPerf.end({ orderType, method: 'per_km', distance: distance.toFixed(2) })
        return fee
    }

    deliveryPerf.end({ orderType, method: 'base' })
    return config.costo_consegna_base ?? 3.00
}

serve(async (req: Request) => {
    // Section 8.2: Initialize Sentry
    initSentry()

    const requestPerf = new PerformanceTracker('create-payment-intent-total')
    const corsHeaders = getCorsHeaders(req)

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    // Section 8.2: Client version compatibility check
    const clientVersion = req.headers.get('x-client-version')
    if (clientVersion) {
        const versionCheck = await validateClientVersion('create-payment-intent', clientVersion)
        if (!versionCheck.compatible) {
            return new Response(JSON.stringify({
                error: 'Client version outdated',
                code: 'version_mismatch',
                currentVersion: FUNCTION_VERSION,
                minVersion: MIN_CLIENT_VERSION,
            }), {
                status: 426,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }
    }

    try {
        // Validate Stripe secret key is configured
        if (!STRIPE_SECRET_KEY) {
            console.error('STRIPE_SECRET_KEY not configured')
            captureException(new Error('STRIPE_SECRET_KEY not configured'), { function: 'create-payment-intent' })
            throw new Error('Payment service temporarily unavailable')
        }

        const body: PaymentIntentRequest = await req.json()

        // Get the authorization header to verify user
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Authentication required')
        }

        // Create Supabase client with service role to access menu data
        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        // Create client with user token to verify identity
        const supabaseClient = createClient(
            SUPABASE_URL,
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        // Get the authenticated user
        const authPerf = new PerformanceTracker('auth_verification')
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        authPerf.end()

        if (userError || !user) {
            throw new Error('Authentication failed')
        }

        // Section 8.2: Set user context for Sentry
        setUserContext(user.id, user.email)

        // =========================================================================
        // RATE LIMITING: Check if user has exceeded payment intent rate limit
        // =========================================================================
        const rateLimitPerf = new PerformanceTracker('rate_limit_check')
        const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
            p_identifier: user.id,
            p_endpoint: 'create-payment-intent',
            p_max_requests: RATE_LIMIT_MAX_REQUESTS,
            p_window_minutes: RATE_LIMIT_WINDOW_MINUTES,
        })
        rateLimitPerf.end()

        if (rateLimitError) {
            console.error('Rate limit check error:', rateLimitError)
            addBreadcrumb('rate_limit', 'Rate limit check failed (continuing)', { error: rateLimitError.message }, 'warning')
        } else if (rateLimit && !(rateLimit as RateLimitResult).allowed) {
            const limitResult = rateLimit as RateLimitResult
            const resetDate = new Date(limitResult.reset_at)
            const retryAfterSeconds = Math.max(1, Math.ceil((resetDate.getTime() - Date.now()) / 1000))

            return new Response(JSON.stringify({
                error: 'Too many payment attempts. Please try again later.',
                code: 'rate_limit_exceeded',
                resetAt: limitResult.reset_at,
                retryAfter: retryAfterSeconds,
            }), {
                status: 429,
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'application/json',
                    'Retry-After': retryAfterSeconds.toString(),
                },
            })
        }

        // Multi-tenant: Get organization ID from request or user profile
        const orgPerf = new PerformanceTracker('get_organization_context')
        let organizationId = body.organizationId
        if (!organizationId) {
            const { data: profile } = await supabaseAdmin
                .from('profiles')
                .select('current_organization_id')
                .eq('id', user.id)
                .single()
            organizationId = profile?.current_organization_id
        }

        // SECURITY: Require organization context - no fallback to random org
        if (!organizationId) {
            orgPerf.end({ organizationId: 'none' })
            addBreadcrumb('security', 'Organization context missing', {
                userId: user.id,
                hasBodyOrgId: !!body.organizationId
            }, 'error')
            throw new Error('Organization context required. Please select a restaurant before proceeding with payment.')
        }

        // Verify user is actually a member of this organization
        const { data: membership, error: memberError } = await supabaseAdmin
            .from('organization_members')
            .select('id, is_active, role')
            .eq('organization_id', organizationId)
            .eq('user_id', user.id)
            .maybeSingle()

        if (memberError) {
            console.error('Error checking organization membership:', memberError)
        }

        if (!membership || !membership.is_active) {
            orgPerf.end({ organizationId, membership: membership ? 'inactive' : 'none' })
            addBreadcrumb('security', 'User not member of organization', {
                userId: user.id,
                organizationId,
                membership: membership ? 'inactive' : 'none'
            }, 'error')
            throw new Error('You are not a member of this organization. Please join the restaurant first.')
        }

        orgPerf.end({ organizationId, userRole: membership?.role })

        // Section 8.2: Set organization context for Sentry
        addBreadcrumb('organization', 'Processing payment intent', { organizationId }, 'info')

        // Section 8.2: Request signature validation (non-blocking for backward compatibility)
        if (body.timestamp && body.nonce && body.signature) {
            const signaturePerf = new PerformanceTracker('signature_validation')
            const validationResult = await validateRequestSignature(req, body, organizationId)
            signaturePerf.end({ valid: validationResult.valid })

            if (!validationResult.valid) {
                // Log warning but don't block request for backward compatibility
                addBreadcrumb('signature', 'Invalid signature (continuing for backward compatibility)', {
                    reason: validationResult.reason,
                    organizationId
                }, 'warning')
                console.warn(`[SECURITY] Invalid request signature: ${validationResult.reason}`)
            } else {
                addBreadcrumb('signature', 'Valid request signature', { organizationId }, 'info')
            }
        }

        // SECURITY: Validate cart is not empty
        if (!body.items || !Array.isArray(body.items) || body.items.length === 0) {
            throw new Error('Cart is empty')
        }

        // SECURITY: Validate cart size
        if (body.items.length > MAX_ITEMS_PER_ORDER) {
            throw new Error(`Order cannot contain more than ${MAX_ITEMS_PER_ORDER} items`)
        }

        // SECURITY: Validate each cart item
        for (let i = 0; i < body.items.length; i++) {
            validateCartItem(body.items[i], i)
        }

        // SECURITY: Calculate total server-side from database
        let calculatedSubtotal = 0

        // Fetch all menu items in the cart (including splits)
        const menuItemIds = new Set<string>()
        body.items.forEach(item => {
            menuItemIds.add(item.menuItemId)
            if (item.isSplit && item.secondProductId) menuItemIds.add(item.secondProductId)
        })

        const menuPerf = new PerformanceTracker('db_query', { table: 'menu_items' })
        const { data: menuItems, error: menuError } = await supabaseAdmin
            .from('menu_items')
            .select('id, prezzo, prezzo_scontato, disponibile')
            .in('id', Array.from(menuItemIds))
            .eq('organization_id', organizationId)
        menuPerf.end()

        if (menuError) {
            console.error('Menu fetch error:', menuError)
            captureException(menuError, { context: 'menu_fetch', organizationId })
            throw new Error('Unable to validate cart items')
        }

        // Collect all size IDs from cart for batch fetch
        const sizeIds = new Set<string>()
        body.items.forEach(item => {
            if (item.sizeId) sizeIds.add(item.sizeId)
            if (item.secondSizeId) sizeIds.add(item.secondSizeId)
        })

        // Fetch size multipliers if sizes are used
        let sizeMultipliers: Record<string, number> = {}
        let sizePriceOverrides: Record<string, Record<string, number | null>> = {}

        if (sizeIds.size > 0) {
            const sizesPerf = new PerformanceTracker('db_query', { table: 'sizes_master' })
            const { data: sizes } = await supabaseAdmin
                .from('sizes_master')
                .select('id, price_multiplier')
                .in('id', Array.from(sizeIds))
                .eq('organization_id', organizationId)
            sizesPerf.end()

            sizes?.forEach((s: any) => sizeMultipliers[s.id] = s.price_multiplier ?? 1.0)

            const sizeAssignPerf = new PerformanceTracker('db_query', { table: 'menu_item_sizes' })
            const { data: sizeAssignments } = await supabaseAdmin
                .from('menu_item_sizes')
                .select('menu_item_id, size_id, price_override')
                .in('menu_item_id', Array.from(menuItemIds))
                .in('size_id', Array.from(sizeIds))
                .eq('organization_id', organizationId)
            sizeAssignPerf.end()

            sizeAssignments?.forEach((a: any) => {
                if (!sizePriceOverrides[a.menu_item_id]) sizePriceOverrides[a.menu_item_id] = {}
                sizePriceOverrides[a.menu_item_id][a.size_id] = a.price_override
            })
        }

        // Collect all ingredient IDs for batch fetch
        const allIngredientIds = new Set<string>()
        body.items.forEach(item => {
            item.extraIngredients?.forEach(ex => allIngredientIds.add(ex.ingredientId))
            item.secondExtraIngredients?.forEach(ex => allIngredientIds.add(ex.ingredientId))
        })

        // Fetch all ingredients with their base prices
        let ingredientPrices: Record<string, number> = {}
        let ingredientSizePrices: Record<string, Record<string, number>> = {}

        if (allIngredientIds.size > 0) {
            const ids = Array.from(allIngredientIds)
            const ingPerf = new PerformanceTracker('db_query', { table: 'ingredients' })
            const { data: ingredients } = await supabaseAdmin
                .from('ingredients')
                .select('id, prezzo')
                .in('id', ids)
                .eq('organization_id', organizationId)
            ingPerf.end()

            ingredients?.forEach((ing: any) => ingredientPrices[ing.id] = ing.prezzo ?? 0)

            // Fetch size-specific ingredient prices if sizes are used
            if (sizeIds.size > 0) {
                const sizePricePerf = new PerformanceTracker('db_query', { table: 'ingredient_size_prices' })
                const { data: sizePrices } = await supabaseAdmin
                    .from('ingredient_size_prices')
                    .select('ingredient_id, size_id, prezzo')
                    .in('ingredient_id', ids)
                    .in('size_id', Array.from(sizeIds))
                    .eq('organization_id', organizationId)
                sizePricePerf.end()

                sizePrices?.forEach((sp: any) => {
                    if (!ingredientSizePrices[sp.ingredient_id]) ingredientSizePrices[sp.ingredient_id] = {}
                    ingredientSizePrices[sp.ingredient_id][sp.size_id] = sp.prezzo
                })
            }
        }

        // Helper: Calculate Part Price
        const calculatePart = (
            prodId: string,
            sizeId: string | undefined,
            extras: { ingredientId: string, quantity: number }[] | undefined
        ): number => {
            const menuItem = menuItems?.find(m => m.id === prodId)
            if (!menuItem) throw new Error('One or more products are no longer available')
            if (!menuItem.disponibile) throw new Error('One or more products are no longer available')

            let base = menuItem.prezzo_scontato ?? menuItem.prezzo

            if (sizeId) {
                const override = sizePriceOverrides[prodId]?.[sizeId]
                if (override !== null && override !== undefined) {
                    base = override
                } else {
                    base *= (sizeMultipliers[sizeId] ?? 1.0)
                }
            }

            let extrasCost = 0
            if (extras) {
                for (const extra of extras) {
                    let ingPrice = ingredientPrices[extra.ingredientId] ?? 0
                    if (sizeId && ingredientSizePrices[extra.ingredientId]?.[sizeId] !== undefined) {
                        ingPrice = ingredientSizePrices[extra.ingredientId][sizeId]
                    }
                    extrasCost += ingPrice * extra.quantity
                }
            }
            return base + extrasCost
        }

        // Calculate total from database prices
        for (const cartItem of body.items) {
            let unitPrice = 0
            let itemTotal = 0

            if (cartItem.isSplit && cartItem.secondProductId) {
                // SPLIT
                const p1 = calculatePart(cartItem.menuItemId, cartItem.sizeId, cartItem.extraIngredients)
                const p2 = calculatePart(cartItem.secondProductId, cartItem.secondSizeId || cartItem.sizeId, cartItem.secondExtraIngredients)

                const rawAverage = (p1 + p2) / 2
                unitPrice = Math.ceil(rawAverage * 2) / 2.0
            } else {
                // REGULAR
                unitPrice = calculatePart(cartItem.menuItemId, cartItem.sizeId, cartItem.extraIngredients)
            }

            itemTotal = unitPrice * cartItem.quantity
            calculatedSubtotal += itemTotal
        }

        // SECURITY: Calculate delivery fee server-side
        const deliveryFee = await calculateDeliveryFee(
            supabaseAdmin,
            body.orderType ?? 'takeaway',
            calculatedSubtotal, // Pass subtotal for free delivery check
            body.deliveryLatitude,
            body.deliveryLongitude,
            organizationId
        )

        const calculatedTotal = calculatedSubtotal + deliveryFee

        // Convert to cents for Stripe
        const amountInCents = Math.round(calculatedTotal * 100)

        // SECURITY: Validate minimum order amount
        if (amountInCents < MIN_ORDER_AMOUNT_CENTS) {
            throw new Error(`Minimum order amount is €${(MIN_ORDER_AMOUNT_CENTS / 100).toFixed(2)}`)
        }

        const currency = body.currency || 'eur'

        console.log(`Creating PaymentIntent: ${amountInCents} cents (€${calculatedTotal.toFixed(2)}) for user ${user.id}`)

        const paymentIntent = await createPaymentIntent(
            amountInCents,
            currency,
            body.customerEmail,
            {
                ...body.metadata,
                userId: user.id,
                organizationId: organizationId || '',  // Multi-tenant
                calculatedSubtotal: calculatedSubtotal.toFixed(2),
                calculatedDeliveryFee: deliveryFee.toFixed(2),
                calculatedTotal: calculatedTotal.toFixed(2)
            }
        )

        const response: PaymentIntentResponse = {
            clientSecret: paymentIntent.client_secret,
            paymentIntentId: paymentIntent.id,
            amount: amountInCents,
            currency: currency,
            calculatedTotal: calculatedTotal,
            calculatedSubtotal: calculatedSubtotal,
            calculatedDeliveryFee: deliveryFee,
        }

        requestPerf.end({ paymentIntentId: paymentIntent.id })

        console.log(`PaymentIntent created: ${paymentIntent.id}`)

        addBreadcrumb('payment_intent', 'PaymentIntent created successfully', {
            paymentIntentId: paymentIntent.id,
            amount: amountInCents,
            currency
        }, 'info')

        return new Response(
            JSON.stringify(response),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )
    } catch (err) {
        const error = err as Error
        console.error('Error creating PaymentIntent:', error)

        // Section 8.2: Capture error in Sentry
        captureException(error, {
            function: 'create-payment-intent',
            version: FUNCTION_VERSION,
        })

        // SECURITY: Return sanitized error message
        return new Response(
            JSON.stringify({
                error: error.message || 'An error occurred. Please try again.',
                code: 'payment_intent_error'
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
