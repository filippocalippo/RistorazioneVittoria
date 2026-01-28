// Supabase Edge Function to place an order with price validation
// Deploy with: supabase functions deploy place-order
//
// Version: 1.0.0
// Part of Section 8.2 Backend Production Readiness Improvements

// Import shared modules
import { validateRequestSignature, ValidationErrors } from '../_shared/request-validator.ts'
import { initSentry, captureException, addBreadcrumb, setUserContext } from '../_shared/sentry.ts'
import { PerformanceTracker } from '../_shared/performance.ts'
import { validateClientVersion, registerFunctionVersion } from '../_shared/version.ts'

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =============================================================================
// VERSION INFO
// =============================================================================
export const FUNCTION_VERSION = '1.0.0'
export const MIN_CLIENT_VERSION = '1.0.0'
export const DEPLOYED_DATE = '2026-01-27'

// =============================================================================
// CONFIGURATION
// =============================================================================
const STRIPE_SECRET_KEY: string = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const STRIPE_API_VERSION = '2023-10-16'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const ALLOWED_ORIGINS = [
    'capacitor://localhost',
    'http://localhost',
    'https://localhost',
    'http://localhost:3000',
    'http://localhost:5173',
]

// =============================================================================
// RATE LIMITING CONFIGURATION
// =============================================================================
const RATE_LIMIT_MAX_REQUESTS = 20  // 20 orders per hour per organization
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

// =============================================================================
// TYPE DEFINITIONS (matching Dart models)
// =============================================================================

interface MenuItem {
    id: string
    prezzo: number
    prezzo_scontato: number | null
}

interface SizeVariant {
    id: string
    price_multiplier: number
}

interface Ingredient {
    id: string
    prezzo: number
}

interface IngredientSizePrice {
    ingredient_id: string
    size_id: string
    prezzo: number
}

interface SizeAssignment {
    menu_item_id: string
    size_id: string
    price_override: number | null
}

// Matches OrderItemInput from Dart's order_price_models.dart
interface IngredientSelection {
    ingredientId: string
    quantity: number
}

// Order item as received from frontend
interface OrderItemInput {
    menu_item_id: string
    nome_prodotto: string
    quantita: number
    prezzo_unitario: number
    subtotale: number
    note?: string
    varianti: Record<string, any>
}

interface PlaceOrderRequest {
    organizationId?: string  // Multi-tenant: organization to create order for
    timestamp?: string     // Request signing timestamp
    nonce?: string          // Request signing nonce
    signature?: string      // Request signing signature
    items: OrderItemInput[]
    orderType: 'delivery' | 'takeaway' | 'dine_in'
    paymentMethod: 'cash' | 'card' | 'online'
    nomeCliente: string
    telefonoCliente: string
    emailCliente?: string
    indirizzoConsegna?: string
    cittaConsegna?: string
    capConsegna?: string
    deliveryLatitude?: number
    deliveryLongitude?: number
    note?: string
    slotPrenotatoStart?: string
    cashierCustomerId?: string
    zone?: string
    status?: string
    subtotale: number
    costoConsegna: number
    sconto?: number
    totale: number
    orderId?: string
}

interface PlaceOrderResponse {
    success: boolean
    orderId: string
    total: number
    clientSecret?: string
    paymentIntentId?: string
}

// =============================================================================
// PRICE CALCULATOR (exact port of OrderPriceCalculator.dart)
// =============================================================================

class OrderPriceCalculator {
    private menuItems: Map<string, MenuItem>
    private sizeAssignments: SizeAssignment[]
    private sizes: Map<string, number> // id -> price_multiplier
    private ingredients: Map<string, number> // id -> prezzo
    private ingredientSizePrices: Map<string, number> // `${ingredientId}_${sizeId}` -> price

    constructor(
        menuItems: MenuItem[],
        sizeAssignments: SizeAssignment[],
        sizes: SizeVariant[],
        ingredients: Ingredient[],
        ingredientSizePrices: IngredientSizePrice[]
    ) {
        this.menuItems = new Map(menuItems.map(m => [m.id, m]))
        this.sizeAssignments = sizeAssignments
        this.sizes = new Map(sizes.map(s => [s.id, s.price_multiplier]))
        this.ingredients = new Map(ingredients.map(i => [i.id, i.prezzo]))
        this.ingredientSizePrices = new Map(
            ingredientSizePrices.map(sp => [`${sp.ingredient_id}_${sp.size_id}`, sp.prezzo])
        )
    }

    // Exact port of OrderPriceCalculator._findMenuItem
    private findMenuItem(id: string): MenuItem | null {
        return this.menuItems.get(id) ?? null
    }

    // Exact port of OrderPriceCalculator._calculateBasePrice
    private calculateBasePrice(menuItemId: string, sizeId: string | null): number {
        const menuItem = this.findMenuItem(menuItemId)
        if (!menuItem) return 0

        // Get effective base price (discounted if available)
        // Matches Dart: menuItem.prezzoEffettivo which is prezzo_scontato ?? prezzo
        const effectivePrice = menuItem.prezzo_scontato ?? menuItem.prezzo

        // If no size selected, return base price
        if (sizeId === null || sizeId === undefined) {
            return effectivePrice
        }

        // Check for product-specific priceOverride first
        const assignment = this.sizeAssignments.find(
            a => a.menu_item_id === menuItemId && a.size_id === sizeId
        )

        if (assignment?.price_override !== null && assignment?.price_override !== undefined) {
            // Use direct override - ignores multiplier
            return assignment.price_override
        }

        // Fall back to size multiplier
        const multiplier = this.sizes.get(sizeId)
        if (multiplier !== undefined) {
            return effectivePrice * multiplier
        }

        // Size not found, return base price
        return effectivePrice
    }

    // Exact port of OrderPriceCalculator._calculateIngredientsCost
    private calculateIngredientsCost(selections: IngredientSelection[], sizeId: string | null): number {
        let total = 0.0

        for (const selection of selections) {
            const basePrice = this.ingredients.get(selection.ingredientId)
            if (basePrice !== undefined) {
                // Use size-specific price if available
                // Exact port of Dart: ingredient.getPriceForSize(sizeId)
                let price = basePrice
                if (sizeId) {
                    const sizeKey = `${selection.ingredientId}_${sizeId}`
                    const sizePrice = this.ingredientSizePrices.get(sizeKey)
                    if (sizePrice !== undefined) {
                        price = sizePrice
                    }
                }
                total += price * selection.quantity
            }
        }

        return total
    }

    // Exact port of OrderPriceCalculator._calculateSplitItemPrice
    calculateSplitItemPrice(
        firstMenuItemId: string,
        secondMenuItemId: string,
        sizeId: string | null,
        secondSizeId: string | null,
        firstAddedIngredients: IngredientSelection[],
        secondAddedIngredients: IngredientSelection[],
        quantity: number
    ): { unitPrice: number; subtotal: number } {
        // 1. Find both menu items
        const firstItem = this.findMenuItem(firstMenuItemId)
        const secondItem = this.findMenuItem(secondMenuItemId)

        if (!firstItem || !secondItem) {
            return { unitPrice: 0, subtotal: 0 }
        }

        // 2. Calculate first product total (base + ingredients)
        const firstBase = this.calculateBasePrice(firstMenuItemId, sizeId)
        const firstIngredients = this.calculateIngredientsCost(firstAddedIngredients, sizeId)
        const firstTotal = firstBase + firstIngredients

        // 3. Calculate second product total (base + ingredients)
        const secondBase = this.calculateBasePrice(secondMenuItemId, secondSizeId)
        const secondIngredients = this.calculateIngredientsCost(secondAddedIngredients, secondSizeId)
        const secondTotal = secondBase + secondIngredients

        console.log(`[SPLIT] First product: base=€${firstBase.toFixed(2)}, ingredients=€${firstIngredients.toFixed(2)} (${firstAddedIngredients.length} items), total=€${firstTotal.toFixed(2)}`)
        console.log(`[SPLIT] Second product: base=€${secondBase.toFixed(2)}, ingredients=€${secondIngredients.toFixed(2)} (${secondAddedIngredients.length} items), total=€${secondTotal.toFixed(2)}`)

        // 4. Average the two totals
        const rawAverage = (firstTotal + secondTotal) / 2

        // 5. Round UP to nearest €0.50
        // Exact port of Dart: (rawAverage * 2).ceil() / 2.0
        const roundedUnitPrice = Math.ceil(rawAverage * 2) / 2.0

        console.log(`[SPLIT] Raw average: €${rawAverage.toFixed(2)}, Rounded to €0.50: €${roundedUnitPrice.toFixed(2)}`)

        // 6. Calculate subtotal
        const subtotal = roundedUnitPrice * quantity

        return { unitPrice: roundedUnitPrice, subtotal }
    }

    // Exact port of OrderPriceCalculator._calculateRegularItemPrice
    calculateRegularItemPrice(
        menuItemId: string,
        sizeId: string | null,
        addedIngredients: IngredientSelection[],
        quantity: number
    ): { unitPrice: number; subtotal: number } {
        const menuItem = this.findMenuItem(menuItemId)
        if (!menuItem) {
            return { unitPrice: 0, subtotal: 0 }
        }

        // Calculate base price (with size if applicable)
        const basePrice = this.calculateBasePrice(menuItemId, sizeId)

        // Calculate ingredients cost
        const ingredientsCost = this.calculateIngredientsCost(addedIngredients, sizeId)

        // Calculate final prices
        const unitPrice = basePrice + ingredientsCost
        const subtotal = unitPrice * quantity

        console.log(`[REGULAR] base=€${basePrice.toFixed(2)}, ingredients=€${ingredientsCost.toFixed(2)} (${addedIngredients.length} items), unitPrice=€${unitPrice.toFixed(2)}`)

        return { unitPrice, subtotal }
    }
}

// =============================================================================
// PRICE VALIDATION (using the calculator class above)
// =============================================================================

async function validateAndCorrectPrices(
    supabaseAdmin: ReturnType<typeof createClient>,
    items: OrderItemInput[],
    organizationId?: string
): Promise<{ items: OrderItemInput[]; corrected: boolean }> {
    console.log(`[VALIDATION] Checking ${items.length} items for price corrections`)

    // Collect all IDs we need
    const menuItemIds = new Set<string>()
    const sizeIds = new Set<string>()
    const ingredientIds = new Set<string>()

    for (const item of items) {
        menuItemIds.add(item.menu_item_id)
        const variants = item.varianti || {}

        if (variants.size?.id) sizeIds.add(variants.size.id)
        if (variants.isSplit && variants.secondProduct?.id) {
            menuItemIds.add(variants.secondProduct.id)
        }
        if (variants.addedIngredients) {
            for (const ing of variants.addedIngredients) {
                if (ing.id) ingredientIds.add(ing.id)
            }
        }
    }

    console.log(`[VALIDATION] Fetching: ${menuItemIds.size} menu items, ${sizeIds.size} sizes, ${ingredientIds.size} ingredients`)

    // SECURITY: Require organization context to prevent cross-tenant data access
    if (!organizationId) {
        throw new Error('Organization context required for price validation')
    }

    // Fetch all required data from database (no .is.null - strict tenant isolation)
    const { data: menuItems } = await supabaseAdmin
        .from('menu_items')
        .select('id, prezzo, prezzo_scontato')
        .in('id', Array.from(menuItemIds))
        .eq('organization_id', organizationId)

    let sizes: SizeVariant[] = []
    let sizeAssignments: SizeAssignment[] = []
    if (sizeIds.size > 0) {
        const { data: sizesData } = await supabaseAdmin
            .from('sizes_master')
            .select('id, price_multiplier')
            .in('id', Array.from(sizeIds))
            .eq('organization_id', organizationId)
        sizes = sizesData || []

        const { data: assignmentsData } = await supabaseAdmin
            .from('menu_item_sizes')
            .select('menu_item_id, size_id, price_override')
            .in('menu_item_id', Array.from(menuItemIds))
            .in('size_id', Array.from(sizeIds))
            .eq('organization_id', organizationId)
        sizeAssignments = assignmentsData || []
    }

    let ingredients: Ingredient[] = []
    let ingredientSizePrices: IngredientSizePrice[] = []
    if (ingredientIds.size > 0) {
        const ids = Array.from(ingredientIds)
        const { data: ingredientsData } = await supabaseAdmin
            .from('ingredients')
            .select('id, prezzo')
            .in('id', ids)
            .eq('organization_id', organizationId)
        ingredients = ingredientsData || []

        if (sizeIds.size > 0) {
            const { data: sizePricesData } = await supabaseAdmin
                .from('ingredient_size_prices')
                .select('ingredient_id, size_id, prezzo')
                .in('ingredient_id', ids)
                .in('size_id', Array.from(sizeIds))
                .eq('organization_id', organizationId)
            ingredientSizePrices = sizePricesData || []
        }
    }

    console.log(`[VALIDATION] Loaded: ${menuItems?.length || 0} menu items, ${sizes.length} sizes, ${ingredients.length} ingredients, ${ingredientSizePrices.length} ingredient size prices`)

    // Create calculator instance (exact port of OrderPriceCalculator)
    const calculator = new OrderPriceCalculator(
        menuItems || [],
        sizeAssignments,
        sizes,
        ingredients,
        ingredientSizePrices
    )

    // Calculate and correct each item
    const correctedItems: OrderItemInput[] = []
    let hasCorrections = false

    for (const item of items) {
        const variants = item.varianti || {}
        const sizeId = variants.size?.id ?? null

        let expectedUnitPrice = 0
        let expectedSubtotal = 0

        if (variants.isSplit && variants.secondProduct?.id) {
            // SPLIT PRODUCT
            console.log(`[SPLIT] Processing: ${item.nome_prodotto}`)
            console.log(`[SPLIT] First product ID: ${item.menu_item_id}`)
            console.log(`[SPLIT] Second product ID: ${variants.secondProduct.id}`)
            console.log(`[SPLIT] Second product name: ${variants.secondProduct.name}`)

            // Parse added ingredients and split them between first and second product
            const allIngredients = variants.addedIngredients || []
            const secondProductName = variants.secondProduct.name || ''

            const firstProductIngredients: IngredientSelection[] = []
            const secondProductIngredients: IngredientSelection[] = []

            for (const ing of allIngredients) {
                const ingName = ing.name || ''
                if (ingName.includes(`: ${secondProductName}`)) {
                    secondProductIngredients.push({
                        ingredientId: ing.id,
                        quantity: ing.quantity || 1
                    })
                    console.log(`[SPLIT] Ingredient "${ingName}" -> SECOND product`)
                } else {
                    firstProductIngredients.push({
                        ingredientId: ing.id,
                        quantity: ing.quantity || 1
                    })
                    console.log(`[SPLIT] Ingredient "${ingName}" -> FIRST product`)
                }
            }

            const result = calculator.calculateSplitItemPrice(
                item.menu_item_id,
                variants.secondProduct.id,
                sizeId,
                sizeId, // secondSizeId - same as first in current implementation
                firstProductIngredients,
                secondProductIngredients,
                item.quantita
            )
            expectedUnitPrice = result.unitPrice
            expectedSubtotal = result.subtotal
        } else {
            // REGULAR PRODUCT
            console.log(`[REGULAR] Processing: ${item.nome_prodotto}`)

            // Map variants.addedIngredients to IngredientSelection[]
            const addedIngredients: IngredientSelection[] = (variants.addedIngredients || []).map((ing: any) => ({
                ingredientId: ing.id,
                quantity: ing.quantity || 1
            }))

            const result = calculator.calculateRegularItemPrice(
                item.menu_item_id,
                sizeId,
                addedIngredients,
                item.quantita
            )
            expectedUnitPrice = result.unitPrice
            expectedSubtotal = result.subtotal
        }

        // Check for price mismatch
        const priceDiff = Math.abs(expectedUnitPrice - item.prezzo_unitario)
        const subtotalDiff = Math.abs(expectedSubtotal - item.subtotale)

        if (priceDiff > 0.01 || subtotalDiff > 0.01) {
            console.log(`[VALIDATION] CORRECTING ${item.nome_prodotto}:`)
            console.log(`  Client unit price: €${item.prezzo_unitario.toFixed(2)} -> Server: €${expectedUnitPrice.toFixed(2)}`)
            console.log(`  Client subtotal: €${item.subtotale.toFixed(2)} -> Server: €${expectedSubtotal.toFixed(2)}`)
            hasCorrections = true
        } else {
            console.log(`[VALIDATION] Price OK for ${item.nome_prodotto}: €${expectedUnitPrice.toFixed(2)}`)
        }

        // Always use server-calculated price
        correctedItems.push({
            ...item,
            prezzo_unitario: expectedUnitPrice,
            subtotale: expectedSubtotal
        })
    }

    if (hasCorrections) {
        console.log(`[VALIDATION] Corrected prices for some items`)
    } else {
        console.log('[VALIDATION] All prices valid, no corrections needed')
    }

    return { items: correctedItems, corrected: hasCorrections }
}

// =============================================================================
// STRIPE PAYMENT INTENT
// =============================================================================

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

// =============================================================================
// CORS HANDLING
// =============================================================================

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
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-version, x-platform',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
}

// =============================================================================
// MAIN HANDLER
// =============================================================================

serve(async (req: Request) => {
    // Track overall function performance
    const perfTracker = new PerformanceTracker('place-order', { function: 'place-order' })

    // Initialize Sentry for error tracking
    initSentry()

    const corsHeaders = getCorsHeaders(req)
    if (req.method === 'OPTIONS') {
        perfTracker.end()
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Validate Stripe secret key is configured
        if (!STRIPE_SECRET_KEY) {
            console.error('STRIPE_SECRET_KEY not configured')
            throw new Error('Payment service temporarily unavailable')
        }

        const body: PlaceOrderRequest = await req.json()
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Authentication required')

        // Get client version for compatibility check
        const clientVersion = req.headers.get('X-Client-Version')
        if (clientVersion) {
            addBreadcrumb('client', 'Client version check', { version: clientVersion })
        }

        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        const supabaseClient = createClient(
            SUPABASE_URL,
            SUPABASE_ANON_KEY,
            { global: { headers: { Authorization: authHeader } } }
        )

        // Get the authenticated user
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error('Authentication failed')

        // Set user context in Sentry
        setUserContext(user.id, user.email)

        // Get organization ID
        let organizationId = body.organizationId || body.organizationId
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
            addBreadcrumb('security', 'Organization context missing', {
                userId: user.id,
                hasBodyOrgId: !!body.organizationId
            }, 'error')
            throw new Error('Organization context required. Please select a restaurant before placing an order.')
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
            addBreadcrumb('security', 'User not member of organization', {
                userId: user.id,
                organizationId,
                membership: membership ? 'inactive' : 'none'
            }, 'error')
            throw new Error('You are not a member of this organization. Please join the restaurant first.')
        }

        // =========================================================================
        // VERSION COMPATIBILITY CHECK
        // =========================================================================
        if (clientVersion) {
            const compatResult = await validateClientVersion('place-order', clientVersion)
            if (!compatResult.valid && compatResult.response) {
                perfTracker.end({ status: 'upgrade_required' })
                return compatResult.response
            }
        }

        // =========================================================================
        // REQUEST SIGNING VALIDATION
        // =========================================================================
        const signaturePerf = new PerformanceTracker('signature_validation')
        if (body.timestamp && body.nonce && body.signature) {
            const validationResult = await validateRequestSignature(
                req,
                body,
                organizationId
            )

            if (!validationResult.valid) {
                signaturePerf.end({ valid: false, error: validationResult.error_code })
                console.warn(`[Signature] ${validationResult.error}`)

                // Don't block requests without signature for backward compatibility
                // Log the warning and continue
            } else {
                console.log('[Signature] Valid signature verified')
            }
        }
        signaturePerf.end()

        // =========================================================================
        // RATE LIMITING: Check if organization has exceeded order rate limit
        // =========================================================================
        const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
            p_identifier: organizationId,
            p_endpoint: 'place-order',
            p_max_requests: RATE_LIMIT_MAX_REQUESTS,
            p_window_minutes: RATE_LIMIT_WINDOW_MINUTES,
        })

        if (rateLimitError) {
            console.error('Rate limit check error:', rateLimitError)
            // Continue on error (fail open for reliability)
        } else if (rateLimit && !(rateLimit as RateLimitResult).allowed) {
            const limitResult = rateLimit as RateLimitResult
            const resetDate = new Date(limitResult.reset_at)
            const retryAfterSeconds = Math.max(1, Math.ceil((resetDate.getTime() - Date.now()) / 1000))

            return new Response(JSON.stringify({
                error: 'Too many orders. Please try again later.',
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

        const { data: membership } = await supabaseAdmin
            .from('organization_members')
            .select('role, is_active')
            .eq('organization_id', organizationId)
            .eq('user_id', user.id)
            .maybeSingle()

        const { data: profile } = await supabaseAdmin
            .from('profiles')
            .select('ruolo')
            .eq('id', user.id)
            .single()

        const legacyRole = profile?.ruolo ?? ''
        const isStaff = ['owner', 'manager', 'kitchen', 'delivery'].includes(membership?.role ?? legacyRole)

        if (!membership) {
            const initialRole = ['manager', 'kitchen', 'delivery'].includes(legacyRole) ? legacyRole : 'customer'
            await supabaseAdmin.from('organization_members').upsert({
                organization_id: organizationId,
                user_id: user.id,
                role: initialRole,
                accepted_at: new Date().toISOString(),
                is_active: true
            }, { onConflict: 'organization_id,user_id' })
        }

        console.log(`[ORDER] User: ${user.email}, Staff: ${isStaff}, Org: ${organizationId}, Items: ${body.items.length}`)

        // VALIDATE AND CORRECT PRICES - Always validate, use server prices if mismatch found
        const priceCheckPerf = new PerformanceTracker('price_validation')
        const priceCheck = await validateAndCorrectPrices(supabaseAdmin, body.items, organizationId)
        priceCheckPerf.end({
            items_validated: priceCheck.items.length,
            corrections_made: priceCheck.corrected
        })
        const correctedItems = priceCheck.items

        if (priceCheck.corrected) {
            console.log('[ORDER] Using server-corrected prices for order')
        }

        // Calculate totals from corrected items
        const subtotal = correctedItems.reduce((sum, item) => sum + item.subtotale, 0)
        const deliveryFee = body.costoConsegna
        const discount = body.sconto || 0
        const total = subtotal + deliveryFee - discount

        console.log(`[ORDER] Subtotal: €${subtotal.toFixed(2)}, Delivery: €${deliveryFee.toFixed(2)}, Total: €${total.toFixed(2)}`)

        // CREATE OR UPDATE ORDER
        const isUpdate = !!body.orderId

        const orderPerf = new PerformanceTracker('order_crud')

        let order: any

        if (isUpdate) {
            if (!isStaff) throw new Error('Only staff can update orders')

            const { data: existing } = await supabaseAdmin
                .from('ordini')
                .select('numero_ordine, created_at, organization_id')
                .eq('id', body.orderId)
                .single()

            if (!existing) throw new Error('Order not found')
            if (existing.organization_id !== organizationId) {
                throw new Error('Order belongs to a different organization')
            }

            const orderData = {
                tipo: body.orderType,
                nome_cliente: body.nomeCliente,
                telefono_cliente: body.telefonoCliente,
                email_cliente: body.emailCliente,
                indirizzo_consegna: body.indirizzoConsegna,
                citta_consegna: body.cittaConsegna,
                cap_consegna: body.capConsegna,
                latitude_consegna: body.deliveryLatitude,
                longitude_consegna: body.deliveryLongitude,
                note: body.note,
                subtotale: subtotal,
                costo_consegna: deliveryFee,
                sconto: discount,
                totale: total,
                metodo_pagamento: body.paymentMethod,
                slot_prenotato_start: body.slotPrenotatoStart,
                cashier_customer_id: body.cashierCustomerId,
                zone: body.zone,
                stato: body.status || 'confirmed',
                printed: false,
                updated_at: new Date().toISOString()
            }

            const { data: updatedOrder, error: updateError } = await supabaseAdmin
                .from('ordini')
                .update(orderData)
                .eq('id', body.orderId)
                .select()
                .single()

            if (updateError) {
                console.error('Order update error:', updateError)
                throw new Error('Failed to update order')
            }

            // Delete old items and insert new ones
            await supabaseAdmin
                .from('ordini_items')
                .delete()
                .eq('ordine_id', body.orderId)

            const itemsWithOrderId = correctedItems.map(item => ({
                ...item,
                ordine_id: body.orderId,
                organization_id: organizationId
            }))
            const { error: itemsError } = await supabaseAdmin
                .from('ordini_items')
                .insert(itemsWithOrderId)

            if (itemsError) {
                console.error('Order items error:', itemsError)
                throw new Error('Failed to update order items')
            }

            order = updatedOrder
            console.log(`[ORDER] Updated order ${body.orderId}`)
        } else {
            // CREATE NEW ORDER
            let status = 'pending'
            if (body.paymentMethod === 'cash') status = 'confirmed'
            if (isStaff && body.status) status = body.status

            const orderData = {
                cliente_id: isStaff ? null : user.id,
                organization_id: organizationId,
                cashier_customer_id: body.cashierCustomerId,
                stato: status,
                tipo: body.orderType,
                nome_cliente: body.nomeCliente,
                telefono_cliente: body.telefonoCliente,
                email_cliente: body.emailCliente ?? (isStaff ? null : user.email),
                indirizzo_consegna: body.indirizzoConsegna,
                citta_consegna: body.cittaConsegna,
                cap_consegna: body.capConsegna,
                latitude_consegna: body.deliveryLatitude,
                longitude_consegna: body.deliveryLongitude,
                note: body.note,
                subtotale: subtotal,
                costo_consegna: deliveryFee,
                sconto: discount,
                totale: total,
                metodo_pagamento: body.paymentMethod,
                pagato: false,
                slot_prenotato_start: body.slotPrenotatoStart,
                zone: body.zone,
                created_at: new Date().toISOString()
            }

            const { data: newOrder, error: orderError } = await supabaseAdmin
                .from('ordini')
                .insert(orderData)
                .select()
                .single()

            if (orderError) {
                console.error('Order creation error:', orderError)
                throw new Error('Failed to create order')
            }

            // Insert items with server-corrected prices
            const itemsWithOrderId = correctedItems.map(item => ({
                ...item,
                ordine_id: newOrder.id,
                organization_id: organizationId
            }))
            const { error: itemsError } = await supabaseAdmin
                .from('ordini_items')
                .insert(itemsWithOrderId)

            if (itemsError) {
                await supabaseAdmin.from('ordini').delete().eq('id', newOrder.id)
                console.error('Order items error:', itemsError)
                throw new Error('Failed to add items to order')
            }

            order = newOrder
            console.log(`[ORDER] Created order ${order.id}`)
        }

        orderPerf.end({ order_type: isUpdate ? 'update' : 'create' })

        // HANDLE PAYMENT
        let response: PlaceOrderResponse = {
            success: true,
            orderId: order.id,
            total: total
        }

        if (body.paymentMethod === 'card' && !isStaff) {
            const stripePerf = new PerformanceTracker('stripe_payment_intent')
            const amountInCents = Math.round(total * 100)
            if (amountInCents < 50) throw new Error('Amount too small for card payment')

            const paymentIntent = await createPaymentIntent(
                amountInCents,
                'eur',
                body.emailCliente ?? user.email,
                {
                    userId: user.id,
                    orderId: order.id,
                    organizationId: organizationId,
                }
            )

            stripePerf.end({ amount: amountInCents })

            response.clientSecret = paymentIntent.client_secret
            response.paymentIntentId = paymentIntent.id
        }

        // Complete performance tracking
        perfTracker.end({
            success: true,
            organization_id: organizationId,
            user_id: user.id,
            items_count: body.items.length
        })

        return new Response(
            JSON.stringify(response),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (err) {
        const error = err as Error
        console.error('Error placing order:', error)

        // Capture exception in Sentry with context
        captureException(error, {
            function: 'place-order',
            timestamp: new Date().toISOString(),
        })

        // Complete performance tracking with error
        perfTracker.end({
            success: false,
            error: error.message
        })

        return new Response(
            JSON.stringify({ error: error.message, code: 'order_error' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
