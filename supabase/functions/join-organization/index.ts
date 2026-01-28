// Supabase Edge Function to join an organization by slug or id
// Deploy with: supabase functions deploy join-organization --no-verify-jwt
// IMPORTANT: Use --no-verify-jwt to handle token refresh on client side

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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

  // Section 8.2: Request signing fields
  timestamp?: string
  nonce?: string
  signature?: string
}

// Rate limiting configuration
const RATE_LIMIT_MAX_REQUESTS = 10  // 10 joins per hour per user
const RATE_LIMIT_WINDOW_MINUTES = 60

interface RateLimitResult {
  allowed: boolean
  remaining: number
  reset_at: string
  limit: number
}

function getCorsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin') ?? ''
  const isAllowed = ALLOWED_ORIGINS.some((allowed) => allowed === origin)

  return {
    'Access-Control-Allow-Origin': isAllowed ? origin : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-version, x-platform',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

serve(async (req: Request) => {
  // Section 8.2: Initialize Sentry
  initSentry()

  const requestPerf = new PerformanceTracker('join-organization-total')
  const corsHeaders = getCorsHeaders(req)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Section 8.2: Client version compatibility check
  const clientVersion = req.headers.get('x-client-version')
  if (clientVersion) {
    const versionCheck = await validateClientVersion('join-organization', clientVersion)
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

    const authPerf = new PerformanceTracker('auth_verification')
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    authPerf.end()

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Authentication failed' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Section 8.2: Set user context for Sentry
    setUserContext(user.id, user.email)

    // =========================================================================
    // RATE LIMITING: Check if user has exceeded join-organization rate limit
    // =========================================================================
    const rateLimitPerf = new PerformanceTracker('rate_limit_check')
    const { data: rateLimit, error: rateLimitError } = await supabaseClient.rpc('check_rate_limit', {
      p_identifier: user.id,
      p_endpoint: 'join-organization',
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

    // Section 8.2: Request signature validation (non-blocking for backward compatibility)
    if (body.timestamp && body.nonce && body.signature) {
      // First, try to get the organization ID for signature validation
      let tempOrgId: string | null = null
      if (organizationId) {
        tempOrgId = organizationId
      } else if (slug) {
        // Need to look up org by slug first for signature validation
        const { data: tempOrg } = await supabaseAdmin
          .from('organizations')
          .select('id')
          .eq('slug', slug)
          .eq('is_active', true)
          .maybeSingle()
        tempOrgId = tempOrg?.id ?? null
      }

      if (tempOrgId) {
        const signaturePerf = new PerformanceTracker('signature_validation')
        const validationResult = await validateRequestSignature(req, body, tempOrgId)
        signaturePerf.end({ valid: validationResult.valid })

        if (!validationResult.valid) {
          // Log warning but don't block request for backward compatibility
          addBreadcrumb('signature', 'Invalid signature (continuing for backward compatibility)', {
            reason: validationResult.reason,
            organizationId: tempOrgId
          }, 'warning')
          console.warn(`[SECURITY] Invalid request signature: ${validationResult.reason}`)
        } else {
          addBreadcrumb('signature', 'Valid request signature', { organizationId: tempOrgId }, 'info')
        }
      }
    }

    // Look up organization
    const orgLookupPerf = new PerformanceTracker('db_query', { table: 'organizations' })
    let orgQuery = supabaseAdmin
      .from('organizations')
      .select('id, name, slug, logo_url, address, city, is_active, deleted_at')
      .eq('is_active', true)
      .is('deleted_at', null)

    orgQuery = slug ? orgQuery.eq('slug', slug) : orgQuery.eq('id', organizationId)

    const { data: org, error: orgError } = await orgQuery.maybeSingle()
    orgLookupPerf.end()

    if (orgError || !org) {
      addBreadcrumb('organization', 'Organization lookup failed', { slug, organizationId }, 'warning')
      return new Response(JSON.stringify({ error: 'Organization not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Section 8.2: Set organization context for Sentry
    addBreadcrumb('organization', 'Processing organization join', { organizationId: org.id, slug: org.slug }, 'info')

    // Check membership
    const membershipPerf = new PerformanceTracker('db_query', { table: 'organization_members' })
    const { data: membership } = await supabaseAdmin
      .from('organization_members')
      .select('id, role')
      .eq('organization_id', org.id)
      .eq('user_id', user.id)
      .maybeSingle()
    membershipPerf.end()

    // Create or update membership
    const updatePerf = new PerformanceTracker('db_query', { table: 'organization_members', operation: 'upsert' })
    if (!membership) {
      await supabaseAdmin.from('organization_members').insert({
        organization_id: org.id,
        user_id: user.id,
        role: 'customer',
        accepted_at: new Date().toISOString(),
        is_active: true,
      })
      addBreadcrumb('membership', 'Created new membership', { organizationId: org.id, userId: user.id, role: 'customer' }, 'info')
    } else {
      await supabaseAdmin
        .from('organization_members')
        .update({ is_active: true })
        .eq('id', membership.id)
      addBreadcrumb('membership', 'Reactivated membership', { organizationId: org.id, userId: user.id, role: membership.role }, 'info')
    }
    updatePerf.end()

    // Update current organization
    const profilePerf = new PerformanceTracker('db_query', { table: 'profiles', operation: 'update' })
    await supabaseAdmin
      .from('profiles')
      .update({ current_organization_id: org.id })
      .eq('id', user.id)
    profilePerf.end()

    requestPerf.end({ organizationId: org.id, action: membership ? 'reactivated' : 'joined' })

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

    // Section 8.2: Capture error in Sentry
    captureException(error, {
      function: 'join-organization',
      version: FUNCTION_VERSION,
    })

    return new Response(JSON.stringify({ error: 'Unexpected error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
