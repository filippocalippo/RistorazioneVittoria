-- =============================================================================
-- Migration 012: Fix Dashboard Security RLS for Multi-Tenancy
-- =============================================================================
-- Security Fix: Update dashboard_security table and RLS policies to use
-- organization-specific role checks instead of global profiles.ruolo
--
-- Issue: Manager from Org A could access Org B's dashboard password
-- Fix: Add organization_id column and update policies to use org-specific roles
-- =============================================================================

-- Step 1: Add organization_id column to dashboard_security
ALTER TABLE public.dashboard_security
ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- Step 2: Ensure all existing rows have an organization_id
-- If there's a single row without organization_id, we need to handle it
-- This is a singleton table (one row per organization)

-- Step 3: Make organization_id NOT NULL after ensuring data integrity
-- First, check if there are any NULL values and handle them
DO $$
DECLARE
  null_count int;
BEGIN
  SELECT COUNT(*) INTO null_count
  FROM public.dashboard_security
  WHERE organization_id IS NULL;

  IF null_count > 0 THEN
    RAISE WARNING 'Found % dashboard_security row(s) without organization_id. These will be deleted.', null_count;
    -- Delete rows without organization context as they're security-sensitive
    DELETE FROM public.dashboard_security WHERE organization_id IS NULL;
  END IF;
END $$;

-- Now add NOT NULL constraint
ALTER TABLE public.dashboard_security
ALTER COLUMN organization_id SET NOT NULL;

-- Step 4: Drop old insecure policies
DROP POLICY IF EXISTS "Managers can view security settings" ON public.dashboard_security;
DROP POLICY IF EXISTS "Managers can update security settings" ON public.dashboard_security;
DROP POLICY IF EXISTS "Managers can insert security settings" ON public.dashboard_security;

-- Step 5: Create new secure organization-aware policies
-- These use the is_organization_admin() helper which checks organization_members

-- Policy: Organization admins can VIEW security settings for their org
CREATE POLICY "Org admins can view security settings"
ON public.dashboard_security
FOR SELECT
TO authenticated
USING (
  organization_id = get_current_organization_id()
  AND is_organization_admin(organization_id)
);

-- Policy: Organization admins can UPDATE security settings for their org
CREATE POLICY "Org admins can update security settings"
ON public.dashboard_security
FOR UPDATE
TO authenticated
USING (
  organization_id = get_current_organization_id()
  AND is_organization_admin(organization_id)
)
WITH CHECK (
  organization_id = get_current_organization_id()
  AND is_organization_admin(organization_id)
);

-- Policy: Organization admins can INSERT security settings for their org
CREATE POLICY "Org admins can insert security settings"
ON public.dashboard_security
FOR INSERT
TO authenticated
WITH CHECK (
  organization_id = get_current_organization_id()
  AND is_organization_admin(organization_id)
);

-- Step 6: Add unique constraint to ensure one dashboard_security row per organization
-- This prevents multiple password records for the same org
ALTER TABLE public.dashboard_security
DROP CONSTRAINT IF EXISTS dashboard_security_pkey;

ALTER TABLE public.dashboard_security
ADD CONSTRAINT dashboard_security_pkey PRIMARY KEY (organization_id);

-- Drop the old id column as it's no longer needed (organization_id is now the PK)
ALTER TABLE public.dashboard_security
DROP COLUMN IF EXISTS id;

-- Step 7: Add index for performance
CREATE INDEX IF NOT EXISTS idx_dashboard_security_org_id
ON public.dashboard_security(organization_id);

-- Step 8: Add comment for documentation
COMMENT ON TABLE public.dashboard_security IS 'Dashboard security settings (password protection) per organization. One row per organization with organization_id as primary key.';

COMMENT ON COLUMN public.dashboard_security.organization_id IS 'Primary key - one security record per organization';
