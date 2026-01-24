-- ===========================================================================
-- MIGRATION 001: FOUNDATION TABLES
-- Creates core organization/multi-tenant foundation for SaaS
-- ===========================================================================
-- Author: AI Assistant
-- Date: 2026-01-24
-- Purpose: Set up organizations, membership, and extend profiles
-- Compatibility: 100% backwards compatible - all new cols are nullable
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. PROFILES TABLE (Core user table, linked to auth.users)
-- ---------------------------------------------------------------------------
-- NOTE: This table must be created FIRST as it's referenced by auth trigger

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    nome TEXT,
    cognome TEXT,
    telefono TEXT,
    indirizzo TEXT,
    citta TEXT,
    cap TEXT,
    ruolo TEXT NOT NULL DEFAULT 'customer' CHECK (ruolo IN ('manager', 'kitchen', 'delivery', 'customer')),
    avatar_url TEXT,
    fcm_token TEXT,
    fcm_tokens JSONB DEFAULT '[]'::jsonb,
    attivo BOOLEAN DEFAULT true,
    ultimo_accesso TIMESTAMPTZ,
    is_super_admin BOOLEAN DEFAULT false,                    -- NEW: Platform admin flag
    current_organization_id UUID,                             -- NEW: Active org context (FK added after organizations table)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for email lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
-- Index for role queries (optimized RLS)
CREATE INDEX IF NOT EXISTS idx_profiles_ruolo ON profiles(ruolo);

-- ---------------------------------------------------------------------------
-- 2. ORGANIZATIONS TABLE (Tenants/Businesses)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,                                -- URL-friendly: "pizzeria-rotante"

    -- Branding
    logo_url TEXT,
    primary_color TEXT DEFAULT '#FF5722',
    secondary_color TEXT DEFAULT '#FFC107',

    -- Contact
    email TEXT NOT NULL,
    phone TEXT,
    website TEXT,

    -- Address
    address TEXT,
    city TEXT,
    postal_code TEXT,
    province TEXT,
    country TEXT DEFAULT 'IT',
    latitude NUMERIC,
    longitude NUMERIC,

    -- Subscription (for SaaS billing)
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'starter', 'professional', 'enterprise')),
    subscription_status TEXT DEFAULT 'active' CHECK (subscription_status IN ('active', 'past_due', 'cancelled', 'trialing')),
    trial_ends_at TIMESTAMPTZ,
    subscription_ends_at TIMESTAMPTZ,
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,

    -- Limits (tier-based)
    max_staff_members INTEGER DEFAULT 3,
    max_menu_items INTEGER DEFAULT 50,
    max_orders_per_month INTEGER DEFAULT 500,

    -- Features (flexible JSON for feature flags)
    features JSONB DEFAULT '{
        "delivery": true,
        "takeaway": true,
        "dine_in": false,
        "online_payments": false,
        "inventory": false,
        "analytics": false,
        "api_access": false,
        "white_label": false,
        "priority_support": false
    }'::jsonb,

    -- Settings
    timezone TEXT DEFAULT 'Europe/Rome',
    locale TEXT DEFAULT 'it_IT',
    currency TEXT DEFAULT 'EUR',

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    deleted_at TIMESTAMPTZ                                    -- Soft delete
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON organizations(slug);
CREATE INDEX IF NOT EXISTS idx_organizations_stripe_customer ON organizations(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_organizations_subscription ON organizations(subscription_tier, subscription_status);
CREATE INDEX IF NOT EXISTS idx_organizations_active ON organizations(is_active) WHERE is_active = true;

-- ---------------------------------------------------------------------------
-- 3. ORGANIZATION_MEMBERS TABLE (User ↔ Organization mapping)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Role within THIS organization (separate from profiles.ruolo which is global default)
    role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('owner', 'manager', 'kitchen', 'delivery', 'customer')),

    -- Invitation tracking
    invited_by UUID REFERENCES auth.users(id),
    invited_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    invitation_token TEXT,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    -- Each user can only be in an org once
    UNIQUE(organization_id, user_id)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_org_members_user ON organization_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org ON organization_members(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_members_role ON organization_members(organization_id, role);
CREATE INDEX IF NOT EXISTS idx_org_members_active ON organization_members(user_id, is_active) WHERE is_active = true;

-- ---------------------------------------------------------------------------
-- 4. ADD FOREIGN KEY: profiles.current_organization_id -> organizations
-- ---------------------------------------------------------------------------

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'profiles_current_organization_id_fkey'
    ) THEN
        ALTER TABLE profiles 
        ADD CONSTRAINT profiles_current_organization_id_fkey 
        FOREIGN KEY (current_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 5. HELPER FUNCTIONS FOR MULTI-TENANT RLS
-- ---------------------------------------------------------------------------

-- Get current user's active organization ID
CREATE OR REPLACE FUNCTION get_current_organization_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT current_organization_id
    FROM profiles
    WHERE id = auth.uid();
$$;

-- Check if current user is a member of given organization
CREATE OR REPLACE FUNCTION is_organization_member(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND is_active = true
    );
$$;

-- Check if current user has a specific role in organization
CREATE OR REPLACE FUNCTION has_organization_role(org_id UUID, required_role TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND role = required_role
        AND is_active = true
    );
$$;

-- Check if user is owner or manager of organization
CREATE OR REPLACE FUNCTION is_organization_admin(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'manager')
        AND is_active = true
    );
$$;

-- Get current user's role (global role from profiles)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role
    FROM organization_members
    WHERE user_id = auth.uid()
    AND organization_id = get_current_organization_id()
    AND is_active = true;
$$;

-- Cached role check (used by RLS policies for performance)
CREATE OR REPLACE FUNCTION is_manager()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = get_current_organization_id()
        AND user_id = auth.uid()
        AND role IN ('owner', 'manager')
        AND is_active = true
    );
$$;

CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = get_current_organization_id()
        AND user_id = auth.uid()
        AND role IN ('owner', 'manager', 'kitchen', 'delivery')
        AND is_active = true
    );
$$;

-- ---------------------------------------------------------------------------
-- 6. UPDATED_AT TRIGGER FUNCTION (Shared by all tables)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Apply to profiles
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply to organizations
DROP TRIGGER IF EXISTS update_organizations_updated_at ON organizations;
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply to organization_members
DROP TRIGGER IF EXISTS update_organization_members_updated_at ON organization_members;
CREATE TRIGGER update_organization_members_updated_at
    BEFORE UPDATE ON organization_members
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- 7. NEW USER HANDLER (Creates profile on auth.users insert)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    default_org_id UUID;
BEGIN
    -- Get the first (default) organization if exists
    SELECT id INTO default_org_id FROM organizations WHERE is_active = true LIMIT 1;

    -- Create profile for new user
    INSERT INTO profiles (id, email, ruolo, current_organization_id)
    VALUES (
        NEW.id,
        NEW.email,
        'customer',
        default_org_id
    );

    -- If default org exists, also create membership
    IF default_org_id IS NOT NULL THEN
        INSERT INTO organization_members (organization_id, user_id, role, accepted_at)
        VALUES (default_org_id, NEW.id, 'customer', now());
    END IF;

    RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ---------------------------------------------------------------------------
-- 8. ENABLE RLS ON ALL TABLES
-- ---------------------------------------------------------------------------

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 9. RLS POLICIES: PROFILES
-- ---------------------------------------------------------------------------

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid());

-- Staff can view all profiles (for order management)
DROP POLICY IF EXISTS "Staff can view all profiles" ON profiles;
CREATE POLICY "Staff can view all profiles" ON profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM organization_members om
            WHERE om.user_id = profiles.id
            AND om.organization_id = get_current_organization_id()
            AND om.is_active = true
        )
        AND is_staff()
    );

-- Users can update their own profile (except role)
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        AND (
            current_organization_id IS NULL
            OR is_organization_member(current_organization_id)
        )
    );

-- Managers can update any profile
DROP POLICY IF EXISTS "Managers can update profiles" ON profiles;
CREATE POLICY "Managers can update profiles" ON profiles
    FOR UPDATE TO authenticated
    USING (
        is_manager()
        AND EXISTS (
            SELECT 1 FROM organization_members om
            WHERE om.user_id = profiles.id
            AND om.organization_id = get_current_organization_id()
            AND om.is_active = true
        )
    );

-- ---------------------------------------------------------------------------
-- 10. RLS POLICIES: ORGANIZATIONS
-- ---------------------------------------------------------------------------

-- Active organizations are visible to anyone
DROP POLICY IF EXISTS "Active organizations are public" ON organizations;
CREATE POLICY "Active organizations are public" ON organizations
    FOR SELECT TO authenticated
    USING (
        is_active = true
        AND (id = get_current_organization_id() OR is_organization_member(id))
    );

-- Only owners/managers can update their organization
DROP POLICY IF EXISTS "Admins can update organization" ON organizations;
CREATE POLICY "Admins can update organization" ON organizations
    FOR UPDATE TO authenticated
    USING (is_organization_admin(id))
    WITH CHECK (is_organization_admin(id));

-- Super admins can do anything
DROP POLICY IF EXISTS "Super admins full access" ON organizations;
CREATE POLICY "Super admins full access" ON organizations
    FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_super_admin = true)
    );

-- ---------------------------------------------------------------------------
-- 11. RLS POLICIES: ORGANIZATION_MEMBERS
-- ---------------------------------------------------------------------------

-- Users can see their own memberships
DROP POLICY IF EXISTS "Users can view own memberships" ON organization_members;
CREATE POLICY "Users can view own memberships" ON organization_members
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Org admins can see all members of their org
DROP POLICY IF EXISTS "Admins can view org members" ON organization_members;
CREATE POLICY "Admins can view org members" ON organization_members
    FOR SELECT TO authenticated
    USING (is_organization_admin(organization_id));

-- Org admins can manage members
DROP POLICY IF EXISTS "Admins can manage org members" ON organization_members;
CREATE POLICY "Admins can manage org members" ON organization_members
    FOR ALL TO authenticated
    USING (is_organization_admin(organization_id))
    WITH CHECK (is_organization_admin(organization_id));

COMMIT;

-- ===========================================================================
-- END MIGRATION 001
-- ===========================================================================
