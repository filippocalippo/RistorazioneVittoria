// Supabase Edge Function to create Stripe PaymentIntent
// Deploy with: supabase functions deploy create-payment-intent

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const STRIPE_SECRET_KEY: string = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const STRIPE_API_VERSION = '2023-10-16'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const ALLOWED_ORIGINS = [
    'capacitor://localhost',
    'http://localhost',
    'https://localhost',
    'http://localhost:3000',
    'http://localhost:5173',
]

const RATE_LIMIT_MAX_REQUESTS = 10
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

const MAX_QUANTITY_PER_ITEM = 100
const MIN_QUANTITY_PER_ITEM = 1
const MAX_ITEMS_PER_ORDER = 50
const MIN_ORDER_AMOUNT_CENTS = 100

interface CartItem {
    menuItemId: string
    quantity: number
    sizeId?: string
    extraIngredients?: { ingredientId: string; quantity: number }[]
    removedIngredients?: { id: string }[]
    note?: string
    isSplit?: boolean
    secondProductId?: string
    secondSizeId?: string
    secondExtraIngredients?: { ingredientId: string; quantity: number }[]
    specialOptions?: any[]
}

interface PaymentIntentRequest {
    organizationId?: string
    items: CartItem[]
    orderType: 'delivery' | 'takeaway' | 'dine_in'
    deliveryLatitude?: number
    deliveryLongitude?: number
    currency?: string
    customerEmail?: string
    metadata?: Record<string, string>
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

    const response = await fetch('https://api.stripe.com/v1/payment_intents', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Stripe-Version': STRIPE_API_VERSION,
        },
        body: params.toString(),
    })

    if (!response.ok) {
        const error = await response.json()
        console.error('Stripe API error:', error)
        throw new Error('Payment processing failed. Please try again.')
    }

    return await response.json()
}

function getCorsHeaders(req: Request): Record<string, string> {
    const origin = req.headers.get('origin') ?? ''

    const isAllowed = ALLOWED_ORIGINS.some(allowed => {
        if (allowed.includes('*')) {
            const pattern = allowed.replace('*', '.*')
            return new RegExp(`^${pattern}$`).test(origin)
        }
        return allowed === origin
    })

    return {
        'Access-Control-Allow-Origin': isAllowed ? origin : ALLOWED_ORIGINS[0],
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-platform',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
}

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

async function calculateDeliveryFee(
    supabaseAdmin: ReturnType<typeof createClient>,
    orderType: string,
    subtotal: number,
    latitude?: number,
    longitude?: number,
    organizationId?: string
): Promise<number> {
    if (orderType !== 'delivery') {
        return 0
    }

    const { data: config } = await supabaseAdmin
        .from('delivery_configuration')
        .select('*')
        .eq('organization_id', organizationId ?? '')
        .limit(1)
        .maybeSingle()

    if (!config) {
        return 3.00
    }

    if (config.consegna_gratuita_sopra && config.consegna_gratuita_sopra > 0) {
        if (subtotal >= config.consegna_gratuita_sopra) {
            return 0.0
        }
    }

    const { data: pizzeria } = await supabaseAdmin
        .from('business_rules')
        .select('latitude, longitude')
        .eq('organization_id', organizationId ?? '')
        .limit(1)
        .maybeSingle()

    if (!latitude || !longitude || !pizzeria?.latitude || !pizzeria?.longitude) {
        return config.costo_consegna_base ?? 3.00
    }

    const R = 6371
    const dLat = (latitude - pizzeria.latitude) * Math.PI / 180
    const dLon = (longitude - pizzeria.longitude) * Math.PI / 180
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(pizzeria.latitude * Math.PI / 180) * Math.cos(latitude * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    const distance = R * c

    if (config.tipo_calcolo_consegna === 'radiale' && config.costo_consegna_radiale) {
        const tiers = config.costo_consegna_radiale as { km: number, price: number }[]
        tiers.sort((a, b) => a.km - b.km)

        for (const tier of tiers) {
            if (distance <= tier.km) {
                return tier.price
            }
        }
        return config.prezzo_fuori_raggio ?? config.costo_consegna_base ?? 3.00
    }

    if (config.tipo_calcolo_consegna === 'per_km') {
        const baseFee = config.costo_consegna_base ?? 3.00
        const perKmFee = config.costo_consegna_per_km ?? 0.50
        return baseFee + (distance * perKmFee)
    }

    return config.costo_consegna_base ?? 3.00
}

serve(async (req: Request) => {
    const corsHeaders = getCorsHeaders(req)

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        if (!STRIPE_SECRET_KEY) {
            console.error('STRIPE_SECRET_KEY not configured')
            throw new Error('Payment service temporarily unavailable')
        }

        const body: PaymentIntentRequest = await req.json()

        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Authentication required')
        }

        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        const supabaseClient = createClient(
            SUPABASE_URL,
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

        if (userError || !user) {
            throw new Error('Authentication failed')
        }

        // Rate limiting
        const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
            p_identifier: user.id,
            p_endpoint: 'create-payment-intent',
            p_max_requests: RATE_LIMIT_MAX_REQUESTS,
            p_window_minutes: RATE_LIMIT_WINDOW_MINUTES,
        })

        if (rateLimitError) {
            console.error('Rate limit check error:', rateLimitError)
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

        // Get organization ID
        let organizationId = body.organizationId
        if (!organizationId) {
            const { data: profile } = await supabaseAdmin
                .from('profiles')
                .select('current_organization_id')
                .eq('id', user.id)
                .single()
            organizationId = profile?.current_organization_id
        }

        if (!organizationId) {
            throw new Error('Organization context required. Please select a restaurant before proceeding with payment.')
        }

        // Verify user is member of organization
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
            throw new Error('You are not a member of this organization. Please join the restaurant first.')
        }

        // Validate cart
        if (!body.items || !Array.isArray(body.items) || body.items.length === 0) {
            throw new Error('Cart is empty')
        }

        if (body.items.length > MAX_ITEMS_PER_ORDER) {
            throw new Error(`Order cannot contain more than ${MAX_ITEMS_PER_ORDER} items`)
        }

        for (let i = 0; i < body.items.length; i++) {
            validateCartItem(body.items[i], i)
        }

        // Calculate total server-side
        let calculatedSubtotal = 0

        const menuItemIds = new Set<string>()
        body.items.forEach(item => {
            menuItemIds.add(item.menuItemId)
            if (item.isSplit && item.secondProductId) menuItemIds.add(item.secondProductId)
        })

        const { data: menuItems, error: menuError } = await supabaseAdmin
            .from('menu_items')
            .select('id, prezzo, prezzo_scontato, disponibile')
            .in('id', Array.from(menuItemIds))
            .eq('organization_id', organizationId)

        if (menuError) {
            console.error('Menu fetch error:', menuError)
            throw new Error('Unable to validate cart items')
        }

        const sizeIds = new Set<string>()
        body.items.forEach(item => {
            if (item.sizeId) sizeIds.add(item.sizeId)
            if (item.secondSizeId) sizeIds.add(item.secondSizeId)
        })

        let sizeMultipliers: Record<string, number> = {}
        let sizePriceOverrides: Record<string, Record<string, number | null>> = {}

        if (sizeIds.size > 0) {
            const { data: sizes } = await supabaseAdmin
                .from('sizes_master')
                .select('id, price_multiplier')
                .in('id', Array.from(sizeIds))
                .eq('organization_id', organizationId)

            sizes?.forEach((s: any) => sizeMultipliers[s.id] = s.price_multiplier ?? 1.0)

            const { data: sizeAssignments } = await supabaseAdmin
                .from('menu_item_sizes')
                .select('menu_item_id, size_id, price_override')
                .in('menu_item_id', Array.from(menuItemIds))
                .in('size_id', Array.from(sizeIds))
                .eq('organization_id', organizationId)

            sizeAssignments?.forEach((a: any) => {
                if (!sizePriceOverrides[a.menu_item_id]) sizePriceOverrides[a.menu_item_id] = {}
                sizePriceOverrides[a.menu_item_id][a.size_id] = a.price_override
            })
        }

        const allIngredientIds = new Set<string>()
        body.items.forEach(item => {
            item.extraIngredients?.forEach(ex => allIngredientIds.add(ex.ingredientId))
            item.secondExtraIngredients?.forEach(ex => allIngredientIds.add(ex.ingredientId))
        })

        let ingredientPrices: Record<string, number> = {}
        let ingredientSizePrices: Record<string, Record<string, number>> = {}

        if (allIngredientIds.size > 0) {
            const ids = Array.from(allIngredientIds)
            const { data: ingredients } = await supabaseAdmin
                .from('ingredients')
                .select('id, prezzo')
                .in('id', ids)
                .eq('organization_id', organizationId)

            ingredients?.forEach((ing: any) => ingredientPrices[ing.id] = ing.prezzo ?? 0)

            if (sizeIds.size > 0) {
                const { data: sizePrices } = await supabaseAdmin
                    .from('ingredient_size_prices')
                    .select('ingredient_id, size_id, prezzo')
                    .in('ingredient_id', ids)
                    .in('size_id', Array.from(sizeIds))
                    .eq('organization_id', organizationId)

                sizePrices?.forEach((sp: any) => {
                    if (!ingredientSizePrices[sp.ingredient_id]) ingredientSizePrices[sp.ingredient_id] = {}
                    ingredientSizePrices[sp.ingredient_id][sp.size_id] = sp.prezzo
                })
            }
        }

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

        for (const cartItem of body.items) {
            let unitPrice = 0
            let itemTotal = 0

            if (cartItem.isSplit && cartItem.secondProductId) {
                const p1 = calculatePart(cartItem.menuItemId, cartItem.sizeId, cartItem.extraIngredients)
                const p2 = calculatePart(cartItem.secondProductId, cartItem.secondSizeId || cartItem.sizeId, cartItem.secondExtraIngredients)

                const rawAverage = (p1 + p2) / 2
                unitPrice = Math.ceil(rawAverage * 2) / 2.0
            } else {
                unitPrice = calculatePart(cartItem.menuItemId, cartItem.sizeId, cartItem.extraIngredients)
            }

            itemTotal = unitPrice * cartItem.quantity
            calculatedSubtotal += itemTotal
        }

        const deliveryFee = await calculateDeliveryFee(
            supabaseAdmin,
            body.orderType ?? 'takeaway',
            calculatedSubtotal,
            body.deliveryLatitude,
            body.deliveryLongitude,
            organizationId
        )

        const calculatedTotal = calculatedSubtotal + deliveryFee

        const amountInCents = Math.round(calculatedTotal * 100)

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
                organizationId: organizationId || '',
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

        console.log(`PaymentIntent created: ${paymentIntent.id}`)

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
