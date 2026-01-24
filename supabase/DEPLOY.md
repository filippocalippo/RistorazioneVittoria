# Supabase Edge Functions Deployment

## Prerequisites

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF
```

## Set Firebase Secrets

Get these values from your Firebase Service Account JSON:

```bash
supabase secrets set FIREBASE_PROJECT_ID="your-firebase-project-id"

supabase secrets set FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com"

supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
...your private key here...
...keep the line breaks...
-----END PRIVATE KEY-----"
```

## Deploy Functions

```bash
# Deploy send-notification function
supabase functions deploy send-notification

# View deployed functions
supabase functions list

# View function logs (real-time)
supabase functions logs send-notification --tail

# View recent logs
supabase functions logs send-notification
```

## Verify Secrets

```bash
supabase secrets list
```

You should see:
- FIREBASE_PROJECT_ID
- FIREBASE_CLIENT_EMAIL  
- FIREBASE_PRIVATE_KEY

## Test Function Locally

```bash
# Start local Supabase
supabase start

# Serve function locally
supabase functions serve send-notification

# In another terminal, test it
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-notification' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "record": {
      "id": "test-id",
      "destinatario_id": "USER_ID_FROM_PROFILES",
      "titolo": "Test Notification",
      "messaggio": "Testing push notifications",
      "tipo": "test",
      "dati": {"test": true}
    }
  }'
```

## Setup Webhook (EASIEST METHOD)

Instead of SQL trigger, use Supabase Dashboard Webhooks:

1. Go to https://app.supabase.com/project/YOUR_PROJECT/database/hooks
2. Create new webhook:
   - **Name**: `send_push_notification`
   - **Table**: `notifiche`
   - **Events**: ✓ Insert
   - **Type**: HTTP Request
   - **Method**: POST
   - **URL**: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification`
   - **HTTP Headers**:
     ```
     Authorization: Bearer YOUR_SERVICE_ROLE_KEY
     Content-Type: application/json
     ```
3. Save

## Quick Commands

```bash
# Redeploy after changes
supabase functions deploy send-notification --no-verify-jwt

# Delete function
supabase functions delete send-notification

# View all secrets
supabase secrets list

# Update a secret
supabase secrets set FIREBASE_PROJECT_ID="new-value"
```

## Project URLs

- Supabase Dashboard: https://app.supabase.com/project/YOUR_PROJECT
- API URL: https://YOUR_PROJECT_REF.supabase.co
- Function URL: https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification

## Troubleshooting

### Function not receiving trigger
- Check webhook is created correctly
- View webhook logs in Supabase Dashboard
- Check function logs: `supabase functions logs send-notification`

### FCM sending fails
- Verify Firebase secrets are correct
- Check Firebase project has Cloud Messaging API enabled
- Ensure service account has correct permissions

### Token not found
- Ensure user's FCM token is saved in `profiles.fcm_token`
- Check Flutter app logs for "FCM token saved to database"
