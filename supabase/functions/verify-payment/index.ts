// Supabase Edge Function to verify payment and update order status
// Deploy with: supabase functions deploy verify-payment

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
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
}

async function retrievePaymentIntent(paymentIntentId: string): Promise<any> {
    const response = await fetch(`https://api.stripe.com/v1/payment_intents/${paymentIntentId}`, {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
            'Stripe-Version': STRIPE_API_VERSION,
        },
    })
    
    if (!response.ok) {
        throw new Error('Failed to retrieve payment intent')
    }
    
    return await response.json()
}

serve(async (req: Request) => {
    const corsHeaders = getCorsHeaders(req)
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

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

        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error('Authentication failed')

        // 1. Verify Stripe Status
        const pi = await retrievePaymentIntent(paymentIntentId)
        if (pi.status !== 'succeeded') {
            throw new Error(`Payment not successful: ${pi.status}`)
        }

        // 2. Verify Metadata matches Order
        if (pi.metadata.orderId !== orderId) {
            throw new Error('Payment mismatch')
        }

        // 3. Verify Order Ownership (Security)
        const { data: orderData, error: orderLookupError } = await supabaseAdmin
            .from('ordini')
            .select('cliente_id')
            .eq('id', orderId)
            .single()

        if (orderLookupError || !orderData) {
            throw new Error('Order not found')
        }

        if (orderData.cliente_id !== user.id) {
            throw new Error('Unauthorized: Order does not belong to user')
        }

        // 4. Update Order in DB 
        // No, trigger allows service_role? Yes, I added IF auth.role() = 'authenticated')
        // Service Role updates should pass.)
        
        const { error: updateError } = await supabaseAdmin
            .from('ordini')
            .update({
                pagato: true,
                stato: 'confirmed', // Confirmed now that it's paid
                confermato_at: new Date().toISOString()
            })
            .eq('id', orderId)

        if (updateError) {
            console.error('Order update error:', updateError)
            throw new Error('Failed to update order status')
        }

        return new Response(
            JSON.stringify({ success: true }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (err) {
        const error = err as Error
        console.error('Verify payment error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
