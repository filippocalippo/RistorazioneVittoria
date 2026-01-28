// Supabase Edge Function to verify payment and update order status
// Deploy with: supabase functions deploy verify-payment

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

// =============================================================================
// CONFIGURATION
// =============================================================================

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
    // TODO: Add your production domain here (e.g. https://your-app.vercel.app)
]

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

async function retrievePaymentIntent(paymentIntentId: string): Promise<any> {
    const stripePerf = new PerformanceTracker('stripe_api_call', { endpoint: 'retrieve_payment_intent' })
    const response = await fetch(`https://api.stripe.com/v1/payment_intents/${paymentIntentId}`, {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
            'Stripe-Version': STRIPE_API_VERSION,
        },
    })
    stripePerf.end()

    if (!response.ok) {
        const error = await response.json()
        captureException(new Error('Failed to retrieve payment intent'), { error, function: 'verify-payment' })
        throw new Error('Failed to retrieve payment intent')
    }

    return await response.json()
}

serve(async (req: Request) => {
    // Section 8.2: Initialize Sentry
    initSentry()

    const requestPerf = new PerformanceTracker('verify-payment-total')
    const corsHeaders = getCorsHeaders(req)
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

    // Section 8.2: Client version compatibility check
    const clientVersion = req.headers.get('x-client-version')
    if (clientVersion) {
        const versionCheck = await validateClientVersion('verify-payment', clientVersion)
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
        const { orderId, paymentIntentId } = await req.json()
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Authentication required')

        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        const supabaseClient = createClient(
            SUPABASE_URL,
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const authPerf = new PerformanceTracker('auth_verification')
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        authPerf.end()

        if (userError || !user) throw new Error('Authentication failed')

        // Section 8.2: Set user context for Sentry
        setUserContext(user.id, user.email)
        addBreadcrumb('verify_payment', 'Verifying payment', { orderId, paymentIntentId }, 'info')

        // 1. Verify Stripe Status
        const stripeVerifyPerf = new PerformanceTracker('verify_stripe_status')
        const pi = await retrievePaymentIntent(paymentIntentId)
        stripeVerifyPerf.end()

        if (pi.status !== 'succeeded') {
            addBreadcrumb('stripe', 'Payment not successful', { status: pi.status }, 'warning')
            throw new Error(`Payment not successful: ${pi.status}`)
        }

        // 2. Verify Metadata matches Order
        if (pi.metadata.orderId !== orderId) {
            addBreadcrumb('stripe', 'Payment metadata mismatch', {
                paymentOrderId: pi.metadata.orderId,
                requestOrderId: orderId
            }, 'error')
            throw new Error('Payment mismatch')
        }

        // 3. Verify Order Ownership (Security)
        const orderLookupPerf = new PerformanceTracker('db_query', { table: 'ordini' })
        const { data: orderData, error: orderLookupError } = await supabaseAdmin
            .from('ordini')
            .select('cliente_id, organization_id')
            .eq('id', orderId)
            .single()
        orderLookupPerf.end()

        if (orderLookupError || !orderData) {
            captureException(orderLookupError || new Error('Order not found'), {
                context: 'order_lookup',
                orderId,
                userId: user.id
            })
            throw new Error('Order not found')
        }

        if (orderData.cliente_id !== user.id) {
            addBreadcrumb('security', 'Unauthorized order access attempt', {
                userId: user.id,
                orderClientId: orderData.cliente_id,
                orderId
            }, 'error')
            throw new Error('Unauthorized: Order does not belong to user')
        }

        if (pi.metadata.organizationId && orderData.organization_id && pi.metadata.organizationId !== orderData.organization_id) {
            addBreadcrumb('security', 'Organization mismatch', {
                paymentOrgId: pi.metadata.organizationId,
                orderOrgId: orderData.organization_id
            }, 'error')
            throw new Error('Payment organization mismatch')
        }

        // Section 8.2: Set organization context for Sentry
        if (orderData.organization_id) {
            addBreadcrumb('organization', 'Processing payment verification', { organizationId: orderData.organization_id }, 'info')
        }

        // 4. Update Order in DB
        const updatePerf = new PerformanceTracker('db_query', { table: 'ordini', operation: 'update' })
        const { error: updateError } = await supabaseAdmin
            .from('ordini')
            .update({
                pagato: true,
                stato: 'confirmed', // Confirmed now that it's paid
                confermato_at: new Date().toISOString()
            })
            .eq('id', orderId)
        updatePerf.end()

        if (updateError) {
            console.error('Order update error:', updateError)
            captureException(updateError, {
                context: 'order_update',
                orderId,
                userId: user.id,
                organizationId: orderData.organization_id
            })
            throw new Error('Failed to update order status')
        }

        requestPerf.end({ orderId, paymentIntentId })

        addBreadcrumb('verify_payment', 'Payment verified and order updated', {
            orderId,
            paymentIntentId,
            status: 'confirmed'
        }, 'info')

        return new Response(
            JSON.stringify({ success: true }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (err) {
        const error = err as Error
        console.error('Verify payment error:', error)

        // Section 8.2: Capture error in Sentry
        captureException(error, {
            function: 'verify-payment',
            version: FUNCTION_VERSION,
        })

        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
