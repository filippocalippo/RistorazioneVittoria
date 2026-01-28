-- ===========================================================================
-- MIGRATION 010: CREATE RATE LIMITING INFRASTRUCTURE
-- Abuse Prevention - Prevent API abuse and brute force attacks
-- ===========================================================================
-- Author: Security Fix
-- Date: 2026-01-27
-- Purpose: Database-backed rate limiting for edge functions
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- RATE LIMITS TABLE
-- Stores request counters for rate limiting enforcement
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier TEXT NOT NULL,              -- user_id, organization_id, or IP address
    endpoint TEXT NOT NULL,                -- edge function name or API route
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMPTZ DEFAULT now(),
    window_end TIMESTAMPTZ DEFAULT now() + INTERVAL '1 hour',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Unique constraint to prevent duplicate limit records per identifier/endpoint/window
CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_limits_identifier_endpoint_window
ON rate_limits(identifier, endpoint, window_start);

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_rate_limits_identifier_endpoint_time
ON rate_limits(identifier, endpoint, window_start DESC);

-- Auto-delete old records (cleanup after 24 hours)
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_end
ON rate_limits(window_end)
WHERE window_end < now() - INTERVAL '24 hours';

-- ---------------------------------------------------------------------------
-- RLS POLICIES - Service role manages rate limits
-- ---------------------------------------------------------------------------

ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage rate limits" ON rate_limits;
CREATE POLICY "Service role can manage rate limits"
ON rate_limits FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- CHECK_RATE_LIMIT FUNCTION
-- Rate limit checker with configurable windows and limits
-- Returns JSONB with allowed, remaining, and reset_at
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_rate_limit(
    p_identifier TEXT,
    p_endpoint TEXT,
    p_max_requests INTEGER DEFAULT 10,
    p_window_minutes INTEGER DEFAULT 60
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_limit_record rate_limits;
    v_now TIMESTAMPTZ := now();
    v_window_start TIMESTAMPTZ;
    v_window_end TIMESTAMPTZ;
    v_remaining INTEGER;
BEGIN
    -- Calculate the current window
    v_window_start := v_now - (v_now % (p_window_minutes || ' minutes')::INTERVAL);
    v_window_end := v_window_start + (p_window_minutes || ' minutes')::INTERVAL;

    -- Try to find existing record for this window
    SELECT * INTO v_limit_record FROM rate_limits
    WHERE identifier = p_identifier
      AND endpoint = p_endpoint
      AND window_start = v_window_start
    FOR UPDATE;

    -- No existing record - create new one
    IF NOT FOUND THEN
        INSERT INTO rate_limits (
            identifier,
            endpoint,
            request_count,
            window_start,
            window_end
        ) VALUES (
            p_identifier,
            p_endpoint,
            1,
            v_window_start,
            v_window_end
        ) RETURNING * INTO v_limit_record;

        v_remaining := p_max_requests - 1;

        RETURN jsonb_build_object(
            'allowed', true,
            'remaining', v_remaining,
            'reset_at', v_window_end,
            'limit', p_max_requests
        );
    END IF;

    -- Check if limit exceeded
    IF v_limit_record.request_count >= p_max_requests THEN
        -- Clean up old records periodically
        DELETE FROM rate_limits WHERE window_end < v_now - INTERVAL '24 hours';

        RETURN jsonb_build_object(
            'allowed', false,
            'remaining', 0,
            'reset_at', v_limit_record.window_end,
            'limit', p_max_requests
        );
    END IF;

    -- Increment counter
    UPDATE rate_limits
    SET request_count = request_count + 1,
        updated_at = v_now
    WHERE id = v_limit_record.id;

    v_remaining := p_max_requests - v_limit_record.request_count - 1;

    -- Clean up old records periodically
    DELETE FROM rate_limits WHERE window_end < v_now - INTERVAL '24 hours';

    RETURN jsonb_build_object(
        'allowed', true,
        'remaining', v_remaining,
        'reset_at', v_limit_record.window_end,
        'limit', p_max_requests
    );
END;
$$;

-- Grant execute on check_rate_limit to authenticated users (for edge functions)
GRANT EXECUTE ON FUNCTION check_rate_limit(TEXT, TEXT, INTEGER, INTEGER) TO authenticated;

-- ---------------------------------------------------------------------------
-- RESET_RATE_LIMIT FUNCTION
-- Admin function to reset rate limit for a specific identifier
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reset_rate_limit(
    p_identifier TEXT,
    p_endpoint TEXT DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    IF p_endpoint IS NULL THEN
        -- Reset all limits for identifier
        DELETE FROM rate_limits
        WHERE identifier = p_identifier;
    ELSE
        -- Reset specific endpoint limit
        DELETE FROM rate_limits
        WHERE identifier = p_identifier AND endpoint = p_endpoint;
    END IF;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;

-- Grant execute on reset_rate_limit to authenticated admins
GRANT EXECUTE ON FUNCTION reset_rate_limit(TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- CLEANUP OLD RATE LIMITS FUNCTION
-- Scheduled cleanup to prevent table bloat
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cleanup_old_rate_limits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    -- Delete records older than 24 hours
    DELETE FROM rate_limits
    WHERE window_end < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;

-- Grant execute to service role for scheduled cleanup
GRANT EXECUTE ON FUNCTION cleanup_old_rate_limits() TO service_role;

COMMIT;

-- ===========================================================================
-- USAGE EXAMPLES
-- ===========================================================================
--
-- In an edge function:
--
-- const rateLimitResult = await supabase.rpc('check_rate_limit', {
--   p_identifier: userId,
--   p_endpoint: 'join-organization',
--   p_max_requests: 10,
--   p_window_minutes: 60
-- });
--
-- if (!rateLimitResult.data.allowed) {
--   return new Response(
--     JSON.stringify({
--       error: 'Rate limit exceeded',
--       resetAt: rateLimitResult.data.reset_at
--     }),
--     { status: 429 }
--   );
-- }
--
-- ===========================================================================
-- END MIGRATION 010
-- ===========================================================================
