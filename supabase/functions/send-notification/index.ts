// Supabase Edge Function to send FCM push notifications
// Deploy with: supabase functions deploy send-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedToken
    })
  })

  if (!response.ok) {
    const error = await response.text()
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

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`FCM error: ${error}`)
  }
}

serve(async (req) => {
  try {
    const { record } = await req.json()
    
    console.log('New notification:', record)

    // Get user's FCM token from profiles
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const profileResponse = await fetch(
      `${supabaseUrl}/rest/v1/profiles?id=eq.${record.destinatario_id}&select=fcm_token`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        }
      }
    )

    const profiles = await profileResponse.json()
    
    if (!profiles || profiles.length === 0) {
      console.log('No profile found for user:', record.destinatario_id)
      return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 })
    }

    const fcmToken = profiles[0].fcm_token
    
    if (!fcmToken) {
      console.log('No FCM token for user:', record.destinatario_id)
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
        ...(record.dati || {})
      }
    })

    console.log('Notification sent successfully')

    return new Response(
      JSON.stringify({ success: true }),
      { 
        headers: { "Content-Type": "application/json" },
        status: 200 
      },
    )
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { "Content-Type": "application/json" },
        status: 500 
      },
    )
  }
})
