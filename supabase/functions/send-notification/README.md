# Send Notification Edge Function

This Supabase Edge Function sends FCM push notifications when new records are inserted into the `notifiche` table.

## Setup

### 1. Get Firebase Service Account Key

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate New Private Key"
3. Download the JSON file

### 2. Set Environment Variables

Set these secrets in Supabase:

```bash
supabase secrets set FIREBASE_PROJECT_ID="your-project-id"
supabase secrets set FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com"
supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYourPrivateKeyHere\n-----END PRIVATE KEY-----"
```

### 3. Deploy the Function

```bash
supabase functions deploy send-notification
```

### 4. Create Database Trigger

Run this SQL in your Supabase SQL editor:

```sql
-- Create trigger to call Edge Function when notification is created
CREATE OR REPLACE FUNCTION trigger_send_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  request_id bigint;
BEGIN
  -- Call the Edge Function using pg_net
  SELECT net.http_post(
    url := (SELECT url FROM vault.decrypted_secrets WHERE name = 'SUPABASE_FUNCTION_URL') || '/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT value FROM vault.decrypted_secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY')
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  ) INTO request_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_notification_created
  AFTER INSERT ON notifiche
  FOR EACH ROW
  EXECUTE FUNCTION trigger_send_push_notification();
```

**Alternative simpler approach using webhooks:**

1. In Supabase Dashboard > Database > Webhooks
2. Create new webhook:
   - Table: `notifiche`
   - Events: `INSERT`
   - Type: `HTTP Request`
   - Method: `POST`
   - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification`
   - Headers: `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`

## Testing

Test the function locally:

```bash
supabase functions serve send-notification
```

Then in another terminal:

```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-notification' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "record": {
      "id": "test-id",
      "destinatario_id": "user-id",
      "titolo": "Test",
      "messaggio": "Test message",
      "tipo": "test",
      "dati": {}
    }
  }'
```

## How It Works

1. When a new row is inserted into `notifiche` table
2. Database trigger/webhook calls this Edge Function
3. Function fetches the user's FCM token from `profiles` table
4. Sends push notification via Firebase Cloud Messaging API
5. Notification appears on user's device (even when app is closed)
