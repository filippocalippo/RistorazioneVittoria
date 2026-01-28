-- Migration: 011_add_request_signing_and_versioning.sql
-- Purpose: Add request signing secrets and function version tracking infrastructure
-- Date: 2026-01-27
-- Related: Section 8.2 Backend improvements

BEGIN;

-- =============================================================================
-- 1. REQUEST SIGNING
-- =============================================================================

-- Add request signing secret column to organizations table
-- This per-organization secret ensures tenant isolation for request signing
ALTER TABLE organizations
ADD COLUMN IF NOT EXISTS request_signing_secret TEXT;

-- Generate unique secrets for existing organizations
-- Using 32 bytes (256 bits) encoded as hex for strong security
UPDATE organizations
SET request_signing_secret = encode(gen_random_bytes(32), 'hex')
WHERE request_signing_secret IS NULL;

-- Create comment for documentation
COMMENT ON COLUMN organizations.request_signing_secret IS
'HMAC secret for request signing verification. Unique per organization for tenant isolation.';

-- =============================================================================
-- 2. FUNCTION VERSION TRACKING
-- =============================================================================

-- Table to track deployed versions of edge functions
-- This enables safe rollbacks and version compatibility management
CREATE TABLE IF NOT EXISTS function_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    function_name TEXT NOT NULL,
    version TEXT NOT NULL,
    deployed_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    rollback_version TEXT,
    changelog TEXT,
    created_by UUID REFERENCES auth.users(id),
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(function_name, deployed_at)
);

-- Index for active version lookups
CREATE INDEX IF NOT EXISTS idx_function_versions_active
ON function_versions(function_name, is_active);

-- Index for organization-specific versions (for multi-tenant versioning)
CREATE INDEX IF NOT EXISTS idx_function_versions_org
ON function_versions(organization_id, function_name);

-- Comments for documentation
COMMENT ON TABLE function_versions IS
'Tracks deployed versions of Supabase Edge Functions for safe rollbacks and compatibility management.';

COMMENT ON COLUMN function_versions.is_active IS
'True if this version is currently deployed and serving requests.';

COMMENT ON COLUMN function_versions.rollback_version IS
'The version to rollback to if this version needs to be reverted.';

-- =============================================================================
-- 3. CLIENT COMPATIBILITY TRACKING
-- =============================================================================

-- Table to track compatible client versions for each function version
CREATE TABLE IF NOT EXISTS function_client_compatibility (
    function_name TEXT NOT NULL,
    min_client_version TEXT NOT NULL,
    max_client_version TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (function_name, min_client_version)
);

-- Comment for documentation
COMMENT ON TABLE function_client_compatibility IS
'Tracks which Flutter client versions are compatible with each edge function version.';

-- =============================================================================
-- 4. NONCE STORAGE (for replay attack prevention)
-- =============================================================================

-- Table to store used nonces for request signing
-- Nonces are unique values that can only be used once within a time window
CREATE TABLE IF NOT EXISTS request_nonces (
    nonce TEXT PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for cleanup of expired nonces
CREATE INDEX IF NOT EXISTS idx_request_nonces_expires
ON request_nonces(expires_at);

-- Comment for documentation
COMMENT ON TABLE request_nonces IS
'Stores used request nonces to prevent replay attacks. Nonces are automatically cleaned up after expiry.';

-- =============================================================================
-- 5. INSERT CURRENT FUNCTION VERSIONS
-- =============================================================================

-- Register the current versions of all edge functions
INSERT INTO function_versions (function_name, version, is_active, changelog) VALUES
('place-order', '1.0.0', true, 'Initial version with signing, Sentry, performance tracking, and versioning'),
('create-payment-intent', '1.0.0', true, 'Initial version with signing, Sentry, performance tracking, and versioning'),
('verify-payment', '1.0.0', true, 'Initial version with Sentry, performance tracking, and versioning'),
('join-organization', '1.0.0', true, 'Initial version with signing, Sentry, performance tracking, and versioning'),
('send-notification', '1.0.0', true, 'Initial version with Sentry, performance tracking, and versioning')
ON CONFLICT (function_name, deployed_at) DO NOTHING;

-- Set default client compatibility (all versions compatible with 1.0.0+)
INSERT INTO function_client_compatibility (function_name, min_client_version, max_client_version, notes) VALUES
('place-order', '1.0.0', NULL, 'Requires client with request signing support'),
('create-payment-intent', '1.0.0', NULL, 'Requires client with request signing support'),
('verify-payment', '1.0.0', NULL, 'Compatible with all clients'),
('join-organization', '1.0.0', NULL, 'Requires client with request signing support'),
('send-notification', '1.0.0', NULL, 'Server-side only, no client requirements')
ON CONFLICT (function_name, min_client_version) DO NOTHING;

-- =============================================================================
-- 6. CLEANUP FUNCTION (for expired nonces)
-- =============================================================================

-- Function to clean up expired nonces (call periodically via pg_cron or manually)
CREATE OR REPLACE FUNCTION cleanup_expired_nonces()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM request_nonces
    WHERE expires_at < now();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Comment for documentation
COMMENT ON FUNCTION cleanup_expired_nonces IS
'Clean up expired nonces to prevent table bloat. Returns number of rows deleted.';

-- =============================================================================
-- 7. FUNCTION TO CHECK CLIENT COMPATIBILITY
-- =============================================================================

-- Helper function to check if a client version is compatible with a function
CREATE OR REPLACE FUNCTION check_function_compatibility(
    p_function_name TEXT,
    p_client_version TEXT
)
RETURNS JSONB AS $$
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
        -- For production, use a proper semver comparison function
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
$$ LANGUAGE plpgsql;

-- Comment for documentation
COMMENT ON FUNCTION check_function_compatibility IS
'Check if a client version is compatible with an edge function version.';

COMMIT;

-- =============================================================================
-- ROLLBACK INSTRUCTIONS
-- =============================================================================
-- If you need to rollback this migration, execute:
/*
BEGIN;

-- Drop helper functions
DROP FUNCTION IF EXISTS cleanup_expired_nonces();
DROP FUNCTION IF EXISTS check_function_compatibility(TEXT, TEXT);

-- Drop nonce storage
DROP TABLE IF EXISTS request_nonces;

-- Drop compatibility tracking
DROP TABLE IF EXISTS function_client_compatibility;

-- Drop version tracking
DROP TABLE IF EXISTS function_versions;

-- Remove request signing secret
ALTER TABLE organizations DROP COLUMN IF EXISTS request_signing_secret;

COMMIT;
*/
