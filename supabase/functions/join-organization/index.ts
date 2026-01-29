// Supabase Edge Function to join an organization by slug or id
// Deploy with: supabase functions deploy join-organization --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const ALLOWED_ORIGINS = [
  'capacitor://localhost',
  'http://localhost',
  'https://localhost',
  'http://localhost:3000',
  'http://localhost:5173',
  'https://rotante.app',
]

interface JoinOrganizationRequest {
  slug?: string
  organizationId?: string
}

const RATE_LIMIT_MAX_REQUESTS = 10
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

function getCorsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin') ?? ''
  const isAllowed = ALLOWED_ORIGINS.some((allowed) =>
    allowed === origin
  )

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
    const body: JoinOrganizationRequest = await req.json()
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authentication required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseClient = createClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      { global: { headers: { Authorization: authHeader } } },
    )
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Authentication failed' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Rate limiting
    const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
      p_identifier: user.id,
      p_endpoint: 'join-organization',
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
        error: 'Too many organization join attempts. Please try again later.',
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

    const slug = body.slug?.trim()
    const organizationId = body.organizationId?.trim()
    if (!slug && !organizationId) {
      return new Response(JSON.stringify({ error: 'Slug or organizationId required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Look up organization
    let orgQuery = supabaseAdmin
      .from('organizations')
      .select('id, name, slug, logo_url, address, city, is_active, deleted_at')
      .eq('is_active', true)
      .is('deleted_at', null)

    orgQuery = slug ? orgQuery.eq('slug', slug) : orgQuery.eq('id', organizationId)

    const { data: org, error: orgError } = await orgQuery.maybeSingle()

    if (orgError || !org) {
      return new Response(JSON.stringify({ error: 'Organization not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check membership
    const { data: membership } = await supabaseAdmin
      .from('organization_members')
      .select('id, role')
      .eq('organization_id', org.id)
      .eq('user_id', user.id)
      .maybeSingle()

    // Create or update membership
    if (!membership) {
      await supabaseAdmin.from('organization_members').insert({
        organization_id: org.id,
        user_id: user.id,
        role: 'customer',
        accepted_at: new Date().toISOString(),
        is_active: true,
      })
    } else {
      await supabaseAdmin
        .from('organization_members')
        .update({ is_active: true })
        .eq('id', membership.id)
    }

    // Update current organization
    await supabaseAdmin
      .from('profiles')
      .update({ current_organization_id: org.id })
      .eq('id', user.id)

    return new Response(
      JSON.stringify({
        organization: {
          id: org.id,
          name: org.name,
          slug: org.slug,
          logo_url: org.logo_url,
          address: org.address,
          city: org.city,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (e) {
    const error = e as Error
    console.error('Join organization error:', error)

    return new Response(JSON.stringify({ error: 'Unexpected error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
