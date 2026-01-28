// Supabase Edge Function to send FCM push notifications
// Deploy with: supabase functions deploy send-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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

const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const FIREBASE_PRIVATE_KEY = Deno.env.get('FIREBASE_PRIVATE_KEY')!
const FIREBASE_CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL')!

let cachedAccessToken: string | null = null
let accessTokenExpiresAt = 0
let cachedSigningKey: CryptoKey | null = null

interface NotificationPayload {
  token: string
  title: string
  body: string
  data?: Record<string, string>
}

async function getSigningKey(): Promise<CryptoKey> {
  if (cachedSigningKey) {
    return cachedSigningKey
  }

  const normalizedPem = FIREBASE_PRIVATE_KEY
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '')

  const binaryKey = str2ab(atob(normalizedPem))

  cachedSigningKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  )

  return cachedSigningKey
}

// Get Firebase access token using service account
async function getAccessToken(): Promise<string> {
  const nowMs = Date.now()
  if (cachedAccessToken && nowMs < accessTokenExpiresAt) {
    return cachedAccessToken
  }

  const jwtHeader = btoa(JSON.stringify({
    alg: "RS256",
    typ: "JWT"
  }))

  const now = Math.floor(nowMs / 1000)
  const jwtClaimSet = btoa(JSON.stringify({
    iss: FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }))

  const unsignedToken = `${jwtHeader}.${jwtClaimSet}`

  const signingKey = await getSigningKey()

  // Sign the token
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(unsignedToken)
  )

  const signedToken = `${unsignedToken}.${btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`

  // Exchange JWT for access token
  const oauthPerf = new PerformanceTracker('firebase_oauth_token')
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedToken
    })
  })
  oauthPerf.end()

  if (!response.ok) {
    const error = await response.text()
    captureException(new Error(`OAuth error: ${error}`), { function: 'send-notification' })
    throw new Error(`OAuth error: ${error}`)
  }

  const data = await response.json()
  cachedAccessToken = data.access_token

  const expiresIn = typeof data.expires_in === 'number' ? data.expires_in : 3600
  accessTokenExpiresAt = nowMs + Math.max((expiresIn - 60), 300) * 1000

  return cachedAccessToken
}

function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length)
  const bufView = new Uint8Array(buf)
  for (let i = 0; i < str.length; i++) {
    bufView[i] = str.charCodeAt(i)
  }
  return buf
}

// Send FCM notification
async function sendNotification(payload: NotificationPayload): Promise<void> {
  const accessToken = await getAccessToken()

  const message = {
    message: {
      token: payload.token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "default",
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          }
        }
      }
    }
  }

  const fcmPerf = new PerformanceTracker('fcm_send_notification', {
    projectId: FIREBASE_PROJECT_ID
  })
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    }
  )
  fcmPerf.end()

  if (!response.ok) {
    const error = await response.text()
    captureException(new Error(`FCM error: ${error}`), {
      function: 'send-notification',
      token: payload.token.substring(0, 10) + '...',
      title: payload.title
    })
    throw new Error(`FCM error: ${error}`)
  }
}

serve(async (req) => {
  // Section 8.2: Initialize Sentry
  initSentry()

  const requestPerf = new PerformanceTracker('send-notification-total')

  // SECURITY: Verify request is from Supabase webhook
  // Supabase sends the service role key in Authorization header for webhook calls
  const authHeader = req.headers.get('Authorization')
  const expectedKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!authHeader || authHeader !== `Bearer ${expectedKey}`) {
    console.error('[SECURITY] Unauthorized notification attempt')
    addBreadcrumb('security', 'Unauthorized notification request', {}, 'error')
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Section 8.2: Client version compatibility check
  const clientVersion = req.headers.get('x-client-version')
  if (clientVersion) {
    const versionCheck = await validateClientVersion('send-notification', clientVersion)
    if (!versionCheck.compatible) {
      return new Response(JSON.stringify({
        error: 'Client version outdated',
        code: 'version_mismatch',
        currentVersion: FUNCTION_VERSION,
        minVersion: MIN_CLIENT_VERSION,
      }), {
        status: 426,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  }

  try {
    const { record } = await req.json()

    console.log('New notification:', record)

    addBreadcrumb('notification', 'Processing notification', {
      tipo: record.tipo,
      userId: record.user_id,
      organizationId: record.organization_id
    }, 'info')

    // SECURITY: Verify recipient is member of the organization
    // This prevents cross-tenant notification spam
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const membershipPerf = new PerformanceTracker('verify_organization_membership')
    const membershipResponse = await fetch(
      `${supabaseUrl}/rest/v1/organization_members?organization_id=eq.${record.organization_id}&user_id=eq.${record.user_id}&is_active=eq.true&select=id`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        }
      }
    )
    membershipPerf.end()

    const memberships = await membershipResponse.json()

    if (!memberships || memberships.length === 0) {
      console.error('[SECURITY] Notification target is not a member of the organization', {
        userId: record.user_id,
        organizationId: record.organization_id
      })
      addBreadcrumb('security', 'Cross-tenant notification blocked', {
        targetUserId: record.user_id,
        organizationId: record.organization_id
      }, 'warning')
      // Return success to prevent webhook retry, but log the security issue
      return new Response(JSON.stringify({
        success: false,
        reason: 'Recipient not a member of organization'
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const profilePerf = new PerformanceTracker('db_query', { table: 'profiles' })
    const profileResponse = await fetch(
      `${supabaseUrl}/rest/v1/profiles?id=eq.${record.user_id}&select=fcm_token`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        }
      }
    )
    profilePerf.end()

    const profiles = await profileResponse.json()

    if (!profiles || profiles.length === 0) {
      console.log('No profile found for user:', record.user_id)
      addBreadcrumb('notification', 'User profile not found', { userId: record.user_id }, 'warning')
      return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 })
    }

    const fcmToken = profiles[0].fcm_token

    if (!fcmToken) {
      console.log('No FCM token for user:', record.destinatario_id)
      addBreadcrumb('notification', 'No FCM token for user', { userId: record.user_id }, 'warning')
      return new Response(JSON.stringify({ error: 'No FCM token' }), { status: 200 })
    }

    // Send notification
    await sendNotification({
      token: fcmToken,
      title: record.titolo,
      body: record.messaggio,
      data: {
        tipo: record.tipo,
        notification_id: record.id,
        organization_id: record.organization_id,
        ...(record.data || {})
      }
    })

    console.log('Notification sent successfully')

    requestPerf.end({
      userId: record.user_id,
      tipo: record.tipo,
      organizationId: record.organization_id
    })

    addBreadcrumb('notification', 'Notification sent successfully', {
      userId: record.user_id,
      tipo: record.tipo
    }, 'info')

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200
      },
    )
  } catch (error) {
    console.error('Error sending notification:', error)

    // Section 8.2: Capture error in Sentry
    captureException(error, {
      function: 'send-notification',
      version: FUNCTION_VERSION,
    })

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500
      },
    )
  }
})
