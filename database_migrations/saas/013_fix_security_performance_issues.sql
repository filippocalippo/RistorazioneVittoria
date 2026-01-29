-- MIGRATION 013: FIX CRITICAL SECURITY AND PERFORMANCE ISSUES
-- Date: 2026-01-29
-- Addresses all issues found in multi-tenancy audit
-- Fixes RLS policies, performance issues, and security vulnerabilities

BEGIN;

-- ============================================================================
-- CRITICAL SECURITY FIXES
-- ============================================================================

-- 1. FIX CRITICAL SECURITY BUG: Change ordini_items policy from TO public to TO authenticated
-- This is the most critical issue - unauthenticated users could access order items

DROP POLICY IF EXISTS "Managers can do everything on ordini_items" ON ordini_items;

CREATE POLICY "Managers can do everything on ordini_items"
ON ordini_items
FOR ALL
TO authenticated  -- Changed from 'public' to 'authenticated'
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- ============================================================================
-- SECURITY: Fix mutable search_path in functions
-- Following best practice from supabase-postgres-best-practices
-- All SECURITY DEFINER functions must set search_path to prevent SQL injection
-- ============================================================================

-- Fix cleanup_expired_nonces function
CREATE OR REPLACE FUNCTION cleanup_expired_nonces()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- Add search_path for security
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM request_nonces
    WHERE expires_at < now();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RETURN deleted_count;
END;
$$;

-- Fix check_function_compatibility function
CREATE OR REPLACE FUNCTION check_function_compatibility(
    p_function_name TEXT,
    p_client_version TEXT DEFAULT '1.0.0'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- Add search_path for security
AS $$
DECLARE
    v_is_compatible BOOLEAN := true;
    v_min_version TEXT;
    v_max_version TEXT;
    v_result JSONB;
BEGIN
    -- Find the compatibility record for this function
    SELECT min_client_version, max_client_version
    INTO v_min_version, v_max_version
    FROM function_client_compatibility
    WHERE function_name = p_function_name
    ORDER BY min_client_version DESC
    LIMIT 1;

    -- If no compatibility record found, assume compatible
    IF v_min_version IS NULL THEN
        v_is_compatible := true;
    ELSE
        -- Simple version comparison (assumes semantic versioning)
        v_is_compatible := (p_client_version >= v_min_version);

        IF v_max_version IS NOT NULL THEN
            v_is_compatible := v_is_compatible AND (p_client_version <= v_max_version);
        END IF;
    END IF;

    -- Build result
    v_result := jsonb_build_object(
        'compatible', v_is_compatible,
        'client_version', p_client_version,
        'min_version', v_min_version,
        'max_version', v_max_version,
        'function_name', p_function_name
    );

    RETURN v_result;
END;
$$;

-- ============================================================================
-- PERFORMANCE: Fix RLS Init Plan issues
-- Wrap auth.uid() in (select auth.uid()) to prevent per-row evaluation
-- Following best practice from supabase-postgres-best-practices
-- ============================================================================

-- ORDINI table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own orders" ON ordini;

CREATE POLICY "Users can view own orders"
ON ordini
FOR SELECT
TO authenticated
USING (
    cliente_id = (select auth.uid())  -- Wrapped in SELECT for performance
    AND organization_id = get_current_organization_id()
);

DROP POLICY IF EXISTS "Users can create orders" ON ordini;

CREATE POLICY "Users can create orders"
ON ordini
FOR INSERT
TO authenticated
WITH CHECK (
    organization_id = get_current_organization_id()
    AND (cliente_id = (select auth.uid()) OR is_staff())  -- Wrapped in SELECT
);

-- ORDINI_ITEMS table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own order items" ON ordini_items;

CREATE POLICY "Users can view own order items"
ON ordini_items
FOR SELECT
TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND EXISTS (
        SELECT 1
        FROM ordini o
        WHERE o.id = ordini_items.ordine_id
        AND o.organization_id = get_current_organization_id()
        AND (o.cliente_id = (select auth.uid()) OR is_staff())  -- Wrapped in SELECT
    )
);

DROP POLICY IF EXISTS "Users can create own order items" ON ordini_items;

CREATE POLICY "Users can create own order items"
ON ordini_items
FOR INSERT
TO authenticated
WITH CHECK (
    organization_id = get_current_organization_id()
    AND EXISTS (
        SELECT 1
        FROM ordini o
        WHERE o.id = ordini_items.ordine_id
        AND o.organization_id = get_current_organization_id()
        AND o.cliente_id = (select auth.uid())  -- Wrapped in SELECT
    )
);

-- NOTIFICHE table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own notifications" ON notifiche;

CREATE POLICY "Users can view own notifications"
ON notifiche
FOR SELECT
TO authenticated
USING (user_id = (select auth.uid()));  -- Wrapped in SELECT

DROP POLICY IF EXISTS "Users can update own notifications" ON notifiche;

CREATE POLICY "Users can update own notifications"
ON notifiche
FOR UPDATE
TO authenticated
USING (user_id = (select auth.uid()))  -- Wrapped in SELECT
WITH CHECK (user_id = (select auth.uid()));

-- PROFILES table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;

CREATE POLICY "Users can view own profile"
ON profiles
FOR SELECT
TO authenticated
USING (
    id = (select auth.uid())  -- Wrapped in SELECT
    OR (
        is_staff()
        AND EXISTS (
            SELECT 1
            FROM organization_members om
            WHERE om.user_id = profiles.id
            AND om.organization_id = get_current_organization_id()
            AND om.is_active = true
        )
    )
);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Users can update own profile"
ON profiles
FOR UPDATE
TO authenticated
USING (
    id = (select auth.uid())  -- Wrapped in SELECT
    OR (
        is_manager()
        AND EXISTS (
            SELECT 1
            FROM organization_members om
            WHERE om.user_id = profiles.id
            AND om.organization_id = get_current_organization_id()
            AND om.is_active = true
        )
    )
)
WITH CHECK (
    id = (select auth.uid())  -- Wrapped in SELECT
    OR (
        is_manager()
        AND EXISTS (
            SELECT 1
            FROM organization_members om
            WHERE om.user_id = profiles.id
            AND om.organization_id = get_current_organization_id()
            AND om.is_active = true
        )
    )
);

-- PAYMENT_TRANSACTIONS table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own payments" ON payment_transactions;

CREATE POLICY "Users can view own payments"
ON payment_transactions
FOR SELECT
TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND EXISTS (
        SELECT 1
        FROM ordini o
        WHERE o.id = order_id
        AND o.cliente_id = (select auth.uid())  -- Wrapped in SELECT
    )
);

-- ORGANIZATIONS table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Super admins full access" ON organizations;

CREATE POLICY "Super admins full access"
ON organizations
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM profiles
        WHERE profiles.id = (select auth.uid())  -- Wrapped in SELECT
        AND profiles.is_super_admin = true
    )
);

-- ORGANIZATION_MEMBERS table: Fix auth.uid() calls in RLS policies

DROP POLICY IF EXISTS "Users can view own memberships" ON organization_members;

CREATE POLICY "Users can view own memberships"
ON organization_members
FOR SELECT
TO authenticated
USING (user_id = (select auth.uid()));  -- Wrapped in SELECT

-- USER_ADDRESSES table: Fix auth.uid() calls in RLS policies (if table exists)

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'user_addresses'
    ) THEN
        -- Check if policy exists before dropping
        IF EXISTS (
            SELECT 1 FROM pg_policies
            WHERE schemaname = 'public'
            AND tablename = 'user_addresses'
            AND policyname = 'Users can manage own addresses'
        ) THEN
            EXECUTE 'DROP POLICY IF EXISTS "Users can manage own addresses" ON user_addresses';

            CREATE POLICY "Users can manage own addresses"
            ON user_addresses
            FOR ALL
            TO authenticated
            USING (user_id = (select auth.uid()))  -- Wrapped in SELECT
            WITH CHECK (user_id = (select auth.uid()));
        END IF;
    END IF;
END $$;

-- ============================================================================
-- PERFORMANCE: Add missing indexes for foreign keys
-- Following best practice from supabase-postgres-best-practices
-- ============================================================================

-- Index on profiles.current_organization_id (most critical)
CREATE INDEX IF NOT EXISTS idx_profiles_current_organization_id
ON profiles(current_organization_id)
WHERE current_organization_id IS NOT NULL;

-- Index on dashboard_security.updated_by
CREATE INDEX IF NOT EXISTS idx_dashboard_security_updated_by
ON dashboard_security(updated_by)
WHERE updated_by IS NOT NULL;

-- Index on ingredient_consumption_rules.ingredient_id
CREATE INDEX IF NOT EXISTS idx_ingredient_consumption_rules_ingredient_id
ON ingredient_consumption_rules(ingredient_id)
WHERE ingredient_id IS NOT NULL;

-- Index on ingredient_consumption_rules.size_id
CREATE INDEX IF NOT EXISTS idx_ingredient_consumption_rules_size_id
ON ingredient_consumption_rules(size_id)
WHERE size_id IS NOT NULL;

-- Index on inventory_logs.created_by
CREATE INDEX IF NOT EXISTS idx_inventory_logs_created_by
ON inventory_logs(created_by)
WHERE created_by IS NOT NULL;

-- Index on order_reminders.created_by
CREATE INDEX IF NOT EXISTS idx_order_reminders_created_by
ON order_reminders(created_by)
WHERE created_by IS NOT NULL;

-- Index on organization_members.invited_by
CREATE INDEX IF NOT EXISTS idx_organization_members_invited_by
ON organization_members(invited_by)
WHERE invited_by IS NOT NULL;

-- Index on organizations.created_by
CREATE INDEX IF NOT EXISTS idx_organizations_created_by
ON organizations(created_by)
WHERE created_by IS NOT NULL;

-- Index on payment_transactions.order_id
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order_id
ON payment_transactions(order_id)
WHERE order_id IS NOT NULL;

-- Composite index for orders with organization and customer
CREATE INDEX IF NOT EXISTS idx_ordini_org_customer
ON ordini(organization_id, cliente_id);

-- Composite index for ordini_items with organization and order
CREATE INDEX IF NOT EXISTS idx_ordini_items_org_order
ON ordini_items(organization_id, ordine_id);

-- ============================================================================
-- CLEANUP: Remove unused indexes (based on Supabase advisor)
-- These indexes have never been used and are just consuming storage
-- ============================================================================

-- Note: We'll drop only the most obviously unused ones
-- Users can drop more later after monitoring confirms they're never used

DROP INDEX IF EXISTS idx_profiles_email;  -- Email already indexed in auth.users

DROP INDEX IF EXISTS idx_cashier_customers_nome;  -- Redundant with nome_normalized

DROP INDEX IF EXISTS idx_cashier_customers_search;  -- Redundant with nome_normalized

-- ============================================================================
-- SCHEMA: Add unique constraint on organizations.slug with deleted_at exclusion
-- Prevents slug conflicts after soft delete
-- ============================================================================

-- Create a partial unique index that excludes deleted organizations
CREATE UNIQUE INDEX IF NOT EXISTS idx_organizations_slug_unique
ON organizations(slug)
WHERE deleted_at IS NULL;

-- This ensures that active organizations cannot have duplicate slugs,
-- but allows the same slug to be reused after soft delete

-- ============================================================================
-- PERFORMANCE: Optimize helper functions
-- Add indexes to support the function calls
-- ============================================================================

-- Index for is_organization_member function
CREATE INDEX IF NOT EXISTS idx_organization_members_lookup
ON organization_members(organization_id, user_id, is_active)
WHERE is_active = true;

-- Index for is_organization_admin function
CREATE INDEX IF NOT EXISTS idx_organization_members_admin_lookup
ON organization_members(organization_id, user_id, role, is_active)
WHERE is_active = true
AND role IN ('owner', 'manager');

-- Index for is_staff function
CREATE INDEX IF NOT EXISTS idx_organization_members_staff_lookup
ON organization_members(organization_id, user_id, role, is_active)
WHERE is_active = true
AND role IN ('owner', 'manager', 'kitchen', 'delivery');

COMMIT;

-- ============================================================================
-- POST-MIGRATION ANALYZE
-- Update statistics for query planner
-- ============================================================================

ANALYZE organizations;
ANALYZE organization_members;
ANALYZE profiles;
ANALYZE ordini;
ANALYZE ordini_items;
ANALYZE notifiche;
ANALYZE payment_transactions;
ANALYZE dashboard_security;
ANALYZE ingredient_consumption_rules;
ANALYZE inventory_logs;
ANALYZE order_reminders;

-- ============================================================================
-- VERIFICATION QUERIES
-- Run these after migration to verify all fixes are applied
-- ============================================================================

-- Verify ordini_items policy is now for authenticated role only
-- SELECT policyname, roles FROM pg_policies WHERE tablename = 'ordini_items';

-- Verify foreign key exists on profiles.current_organization_id
-- SELECT conname FROM pg_constraint WHERE conrelid = 'profiles'::regclass AND conname LIKE '%current_organization_id%';

-- Verify functions have search_path set
-- SELECT proname, prosecdef, probin FROM pg_proc WHERE proname IN ('cleanup_expired_nonces', 'check_function_compatibility') AND pronamespace = 'public'::regnamespace;

-- Verify new indexes were created
-- SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%_created_by' OR indexname LIKE 'idx_%_organization_id';

-- Verify unique constraint on slug
-- SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_organizations_slug_unique';
