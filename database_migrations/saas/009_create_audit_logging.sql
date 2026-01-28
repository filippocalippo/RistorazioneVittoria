-- ===========================================================================
-- MIGRATION 009: CREATE AUDIT LOGGING INFRASTRUCTURE
-- Compliance and Security - Track all critical data changes
-- ===========================================================================
-- Author: Security Fix
-- Date: 2026-01-27
-- Purpose: Log changes for compliance and security investigation
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- AUDIT LOGS TABLE
-- Stores comprehensive audit trail for all critical operations
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,                    -- INSERT, UPDATE, DELETE, JOIN, LEAVE, etc.
    table_name TEXT NOT NULL,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_org_created ON audit_logs(organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_created ON audit_logs(table_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created ON audit_logs(action, created_at DESC);

-- ---------------------------------------------------------------------------
-- RLS POLICIES - Only admins can view audit logs
-- ---------------------------------------------------------------------------

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Organization admins can view audit logs" ON audit_logs;
CREATE POLICY "Organization admins can view audit logs"
ON audit_logs FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- Service role can insert logs (triggers, edge functions)
DROP POLICY IF EXISTS "Service role can insert audit logs" ON audit_logs;
CREATE POLICY "Service role can insert audit logs"
ON audit_logs FOR INSERT TO service_role
WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- LOG_AUDIT FUNCTION - Helper function for logging events
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_audit(
    p_table_name TEXT,
    p_record_id UUID,
    p_action TEXT,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_log_id UUID;
    v_org_id UUID;
BEGIN
    v_org_id := get_current_organization_id();

    INSERT INTO audit_logs (
        organization_id,
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        v_org_id,
        auth.uid(),
        p_action,
        p_table_name,
        p_record_id,
        p_old_values,
        p_new_values
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

-- Grant execute on log_audit to authenticated users (for application-level logging)
GRANT EXECUTE ON FUNCTION log_audit(TEXT, UUID, TEXT, JSONB, JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- AUDIT TRIGGER FUNCTION - Automatically logs changes to critical tables
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Log UPDATE operations
    IF (TG_OP = 'UPDATE') THEN
        PERFORM log_audit(
            TG_TABLE_NAME::TEXT,
            OLD.id,
            'UPDATE',
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
        RETURN NEW;

    -- Log DELETE operations
    ELSIF (TG_OP = 'DELETE') THEN
        PERFORM log_audit(
            TG_TABLE_NAME::TEXT,
            OLD.id,
            'DELETE',
            to_jsonb(OLD),
            NULL
        );
        RETURN OLD;

    -- Log INSERT operations (for critical tables only)
    ELSIF (TG_OP = 'INSERT') THEN
        PERFORM log_audit(
            TG_TABLE_NAME::TEXT,
            NEW.id,
            'INSERT',
            NULL,
            to_jsonb(NEW)
        );
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- APPLY AUDIT TRIGGERS TO CRITICAL TABLES
-- ---------------------------------------------------------------------------

-- Organization members (role changes, joins, leaves)
DROP TRIGGER IF EXISTS audit_organization_members ON organization_members;
CREATE TRIGGER audit_organization_members
    AFTER INSERT OR UPDATE OR DELETE ON organization_members
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- Organizations (settings changes)
DROP TRIGGER IF EXISTS audit_organizations ON organizations;
CREATE TRIGGER audit_organizations
    AFTER UPDATE OR DELETE ON organizations
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- Menu items (price changes are critical for revenue tracking)
DROP TRIGGER IF EXISTS audit_menu_items ON menu_items;
CREATE TRIGGER audit_menu_items
    AFTER UPDATE OR DELETE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- Orders (status changes for compliance)
DROP TRIGGER IF EXISTS audit_ordini ON ordini;
CREATE TRIGGER audit_ordini
    AFTER INSERT OR UPDATE ON ordini
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_func();

COMMIT;

-- ===========================================================================
-- END MIGRATION 009
-- ===========================================================================
