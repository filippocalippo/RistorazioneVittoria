-- ===========================================================================
-- MIGRATION 007: FIX PUBLIC ORG LOOKUP VULNERABILITY
-- Critical Security Fix - Remove public access to organizations table
-- ===========================================================================
-- Author: Security Fix
-- Date: 2026-01-27
-- Purpose: Prevent unauthenticated enumeration of all organizations
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- SECURITY ISSUE: The current policy allows unauthenticated users (anon role)
-- to query and enumerate all organizations, exposing sensitive data:
-- - Organization names, emails, phones, addresses
-- - Subscription tiers and status
-- - Business contact information
-- ---------------------------------------------------------------------------

-- Drop the vulnerable public policy
DROP POLICY IF EXISTS "Public can read basic org info by slug" ON organizations;

-- Create new policy that requires authentication
-- Users must be logged in (authenticated role) to look up organizations
-- This preserves the join flow while preventing anonymous enumeration
CREATE POLICY "Authenticated can read basic org info by slug"
ON organizations FOR SELECT TO authenticated
USING (is_active = true AND deleted_at IS NULL);

-- ---------------------------------------------------------------------------
-- VERIFICATION QUERIES
-- ---------------------------------------------------------------------------

-- Verify the policy no longer allows public access:
-- SELECT policyname, roles FROM pg_policies WHERE tablename = 'organizations';
-- Expected: roles should be "{authenticated}", NOT "{public}"

-- Test unauthenticated access (should fail):
-- set local role anon;
-- SELECT * FROM organizations WHERE is_active = true;
-- Expected: Permission denied error

-- Test authenticated access (should succeed):
-- set local role authenticated;
-- SELECT id, name, slug FROM organizations WHERE is_active = true;
-- Expected: Returns organizations

-- ---------------------------------------------------------------------------
-- IMPACT ASSESSMENT
-- ---------------------------------------------------------------------------
-- - Join flow: UNAFFECTED - Users authenticate before joining organizations
-- - QR code lookup: UNAFFECTED - Requires authenticated user context
-- - Organization switcher: UNAFFECTED - Already authenticated
-- - Security: IMPROVED - Anonymous enumeration now blocked
-- ---------------------------------------------------------------------------

COMMIT;

-- ===========================================================================
-- END MIGRATION 007
-- ===========================================================================
