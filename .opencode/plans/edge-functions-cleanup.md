# Edge Functions Cleanup Plan

## Overview
Remove request signing, Sentry, and performance tracking from all Supabase Edge Functions to simplify the codebase.

## Database Changes

### Migration: remove_request_signing_infrastructure.sql
```sql
-- Remove request signing infrastructure completely

-- 1. Drop request_nonces table
DROP TABLE IF EXISTS request_nonces;

-- 2. Drop cleanup_expired_nonces function
DROP FUNCTION IF EXISTS cleanup_expired_nonces();

-- 3. Remove request_signing_secret column from organizations
ALTER TABLE organizations DROP COLUMN IF EXISTS request_signing_secret;
```

## File Changes

### 1. Delete Files
- [ ] `supabase/functions/_shared/request-validator.ts` - No longer needed
- [ ] `supabase/functions/_shared/sentry.ts` - No longer needed
- [ ] `supabase/functions/_shared/performance.ts` - No longer needed

### 2. Update `create-payment-intent/index.ts`
**Remove:**
- Import: `../_shared/sentry.ts`
- Import: `../_shared/performance.ts`
- Import: `../_shared/request-validator.ts`
- All `initSentry()` calls
- All `PerformanceTracker` usage
- All `captureException`, `setUserContext`, `addBreadcrumb` calls
- All `requestPerf` tracking variables
- Request signature validation logic

**Keep:**
- JWT authentication
- Rate limiting (via `check_rate_limit` RPC)
- Server-side price calculation
- CORS handling
- Cart validation
- Stripe integration

### 3. Update `join-organization/index.ts`
**Remove:**
- Import: `../_shared/sentry.ts`
- Import: `../_shared/performance.ts`
- Import: `../_shared/request-validator.ts`
- All `initSentry()` calls
- All `PerformanceTracker` usage
- All `captureException`, `setUserContext`, `addBreadcrumb` calls
- Request signature validation logic
- Remove timestamp, nonce, signature from interface

**Keep:**
- JWT authentication
- Rate limiting
- Organization lookup logic
- Membership creation/update
- CORS handling

### 4. Update `place-order/index.ts`
**Remove:**
- Import: `../_shared/sentry.ts`
- Import: `../_shared/performance.ts`
- Import: `../_shared/request-validator.ts`
- All `initSentry()` calls
- All `PerformanceTracker` usage
- All `captureException`, `setUserContext`, `addBreadcrumb` calls
- Request signature validation logic
- Remove timestamp, nonce, signature from interface

**Keep:**
- JWT authentication
- Rate limiting
- Server-side price validation (CRITICAL - do not remove)
- Order creation/update logic
- Stripe payment intent creation
- CORS handling

### 5. Update `verify-payment/index.ts`
**Remove:**
- Import: `../_shared/sentry.ts`
- Import: `../_shared/performance.ts`
- All `initSentry()` calls
- All `PerformanceTracker` usage
- All `captureException`, `setUserContext`, `addBreadcrumb` calls

**Keep:**
- JWT authentication
- Stripe payment verification
- Order status update
- CORS handling

### 6. Update `send-notification/index.ts`
**Remove:**
- Import: `../_shared/sentry.ts`
- Import: `../_shared/performance.ts`
- All `initSentry()` calls
- All `PerformanceTracker` usage
- All `captureException`, `addBreadcrumb` calls

**Keep:**
- Webhook authentication (service role key check)
- FCM notification sending
- Cross-tenant notification blocking

## Security Post-Cleanup

The following security measures remain in place:

1. **JWT Authentication** - All requests require valid Supabase auth token
2. **HTTPS Encryption** - All traffic encrypted in transit
3. **Rate Limiting** - Prevents abuse via `check_rate_limit` RPC
4. **Server-Side Validation** - Prices calculated from database, not trusted from client
5. **RLS Policies** - Database row-level security enforces tenant isolation
6. **CORS Configuration** - Only allowed origins can access functions

## Files to Verify After Changes

Ensure these files compile and deploy successfully:
- [ ] `supabase/functions/create-payment-intent/index.ts`
- [ ] `supabase/functions/join-organization/index.ts`
- [ ] `supabase/functions/place-order/index.ts`
- [ ] `supabase/functions/verify-payment/index.ts`
- [ ] `supabase/functions/send-notification/index.ts`

## Deployment Commands

After making changes, deploy with:
```bash
supabase functions deploy create-payment-intent
supabase functions deploy join-organization
supabase functions deploy place-order
supabase functions deploy verify-payment
supabase functions deploy send-notification
```

## Rollback Plan

If issues occur, restore from git:
```bash
git checkout HEAD -- supabase/functions/
```

Or manually re-add files if needed (stored in version history).
