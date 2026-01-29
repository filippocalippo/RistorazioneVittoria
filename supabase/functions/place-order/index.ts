// Supabase Edge Function to place an order with price validation
// Deploy with: supabase functions deploy place-order

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

const RATE_LIMIT_MAX_REQUESTS = 20
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

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

interface IngredientSelection {
    ingredientId: string
    quantity: number
}

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
    organizationId?: string
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

class OrderPriceCalculator {
    private menuItems: Map<string, MenuItem>
    private sizeAssignments: SizeAssignment[]
    private sizes: Map<string, number>
    private ingredients: Map<string, number>
    private ingredientSizePrices: Map<string, number>

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

    private findMenuItem(id: string): MenuItem | null {
        return this.menuItems.get(id) ?? null
    }

    private calculateBasePrice(menuItemId: string, sizeId: string | null): number {
        const menuItem = this.findMenuItem(menuItemId)
        if (!menuItem) return 0

        const effectivePrice = menuItem.prezzo_scontato ?? menuItem.prezzo

        if (sizeId === null || sizeId === undefined) {
            return effectivePrice
        }

        const assignment = this.sizeAssignments.find(
            a => a.menu_item_id === menuItemId && a.size_id === sizeId
        )

        if (assignment?.price_override !== null && assignment?.price_override !== undefined) {
            return assignment.price_override
        }

        const multiplier = this.sizes.get(sizeId)
        if (multiplier !== undefined) {
            return effectivePrice * multiplier
        }

        return effectivePrice
    }

    private calculateIngredientsCost(selections: IngredientSelection[], sizeId: string | null): number {
        let total = 0.0

        for (const selection of selections) {
            const basePrice = this.ingredients.get(selection.ingredientId)
            if (basePrice !== undefined) {
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

    calculateSplitItemPrice(
        firstMenuItemId: string,
        secondMenuItemId: string,
        sizeId: string | null,
        secondSizeId: string | null,
        firstAddedIngredients: IngredientSelection[],
        secondAddedIngredients: IngredientSelection[],
        quantity: number
    ): { unitPrice: number; subtotal: number } {
        const firstItem = this.findMenuItem(firstMenuItemId)
        const secondItem = this.findMenuItem(secondMenuItemId)

        if (!firstItem || !secondItem) {
            return { unitPrice: 0, subtotal: 0 }
        }

        const firstBase = this.calculateBasePrice(firstMenuItemId, sizeId)
        const firstIngredients = this.calculateIngredientsCost(firstAddedIngredients, sizeId)
        const firstTotal = firstBase + firstIngredients

        const secondBase = this.calculateBasePrice(secondMenuItemId, secondSizeId)
        const secondIngredients = this.calculateIngredientsCost(secondAddedIngredients, secondSizeId)
        const secondTotal = secondBase + secondIngredients

        const rawAverage = (firstTotal + secondTotal) / 2
        const roundedUnitPrice = Math.ceil(rawAverage * 2) / 2.0

        const subtotal = roundedUnitPrice * quantity

        return { unitPrice: roundedUnitPrice, subtotal }
    }

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

        const basePrice = this.calculateBasePrice(menuItemId, sizeId)
        const ingredientsCost = this.calculateIngredientsCost(addedIngredients, sizeId)

        const unitPrice = basePrice + ingredientsCost
        const subtotal = unitPrice * quantity

        return { unitPrice, subtotal }
    }
}

async function validateAndCorrectPrices(
    supabaseAdmin: ReturnType<typeof createClient>,
    items: OrderItemInput[],
    organizationId?: string
): Promise<{ items: OrderItemInput[]; corrected: boolean }> {
    console.log(`[VALIDATION] Checking ${items.length} items for price corrections`)

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

    if (!organizationId) {
        throw new Error('Organization context required for price validation')
    }

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

    const calculator = new OrderPriceCalculator(
        menuItems || [],
        sizeAssignments,
        sizes,
        ingredients,
        ingredientSizePrices
    )

    const correctedItems: OrderItemInput[] = []
    let hasCorrections = false

    for (const item of items) {
        const variants = item.varianti || {}
        const sizeId = variants.size?.id ?? null

        let expectedUnitPrice = 0
        let expectedSubtotal = 0

        if (variants.isSplit && variants.secondProduct?.id) {
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
                } else {
                    firstProductIngredients.push({
                        ingredientId: ing.id,
                        quantity: ing.quantity || 1
                    })
                }
            }

            const result = calculator.calculateSplitItemPrice(
                item.menu_item_id,
                variants.secondProduct.id,
                sizeId,
                sizeId,
                firstProductIngredients,
                secondProductIngredients,
                item.quantita
            )
            expectedUnitPrice = result.unitPrice
            expectedSubtotal = result.subtotal
        } else {
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

        const priceDiff = Math.abs(expectedUnitPrice - item.prezzo_unitario)
        const subtotalDiff = Math.abs(expectedSubtotal - item.subtotale)

        if (priceDiff > 0.01 || subtotalDiff > 0.01) {
            console.log(`[VALIDATION] CORRECTING ${item.nome_prodotto}:`)
            console.log(`  Client unit price: €${item.prezzo_unitario.toFixed(2)} -> Server: €${expectedUnitPrice.toFixed(2)}`)
            console.log(`  Client subtotal: €${item.subtotale.toFixed(2)} -> Server: €${expectedSubtotal.toFixed(2)}`)
            hasCorrections = true
        }

        correctedItems.push({
            ...item,
            prezzo_unitario: expectedUnitPrice,
            subtotale: expectedSubtotal
        })
    }

    return { items: correctedItems, corrected: hasCorrections }
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

        const body: PlaceOrderRequest = await req.json()
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Authentication required')

        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        const supabaseClient = createClient(
            SUPABASE_URL,
            SUPABASE_ANON_KEY,
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error('Authentication failed')

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
            throw new Error('Organization context required. Please select a restaurant before placing an order.')
        }

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

        // Rate limiting
        const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
            p_identifier: organizationId,
            p_endpoint: 'place-order',
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

        // VALIDATE AND CORRECT PRICES
        const priceCheck = await validateAndCorrectPrices(supabaseAdmin, body.items, organizationId)
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

        // HANDLE PAYMENT
        let response: PlaceOrderResponse = {
            success: true,
            orderId: order.id,
            total: total
        }

        if (body.paymentMethod === 'card' && !isStaff) {
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

            response.clientSecret = paymentIntent.client_secret
            response.paymentIntentId = paymentIntent.id
        }

        return new Response(
            JSON.stringify(response),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (err) {
        const error = err as Error
        console.error('Error placing order:', error)

        return new Response(
            JSON.stringify({ error: error.message, code: 'order_error' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
