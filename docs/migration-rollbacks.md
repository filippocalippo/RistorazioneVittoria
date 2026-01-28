# Migration Rollback Procedures

## Vittoria Ristorazione - Database Migration Rollback Guide

**Version:** 1.0
**Last Updated:** 2026-01-27
**Purpose:** Safe rollback procedures for database migrations

---

## Executive Summary

This document provides standardized rollback procedures for database migrations. Every migration should be designed with a rollback strategy before execution.

### Key Principles

1. **Test First** - Always test rollback in non-production environment
2. **Document Changes** - Every migration must have documented rollback steps
3. **Quick Recovery** - Target rollback time < 5 minutes
4. **Data Safety** - Never permanently delete data without backup

---

## 1. Pre-Migration Checklist

### 1.1 Before Running Any Migration

- [ ] **Backup taken** - Recent backup exists (within last 24 hours)
- [ ] **Rollback documented** - Rollback steps written in migration file
- [ ] **Tested in staging** - Migration and rollback tested
- [ ] **Maintenance window** - Users notified if needed
- [ ] **Team available** - On-call engineer present
- [ ] **Monitoring ready** - Dashboards and alerts active

### 1.2 Risk Assessment Matrix

| Migration Type | Risk Level | Rollback Complexity | Testing Requirement |
|----------------|------------|---------------------|---------------------|
| Schema addition (new table) | 🟢 Low | Simple - DROP TABLE | Staging only |
| Schema modification (ALTER COLUMN) | 🟡 Medium | Moderate - ALTER COLUMN reverse | Staging + data validation |
| Data migration | 🟡 Medium | Complex - data restore | Staging + full data test |
| RLS policy change | 🔴 High | Simple - recreate policy | Staging + security test |
| Index creation | 🟢 Low | Simple - DROP INDEX | Staging only |
| Constraint addition | 🟡 Medium | Simple - DROP CONSTRAINT | Staging + data check |
| Function/Trigger creation | 🟡 Medium | Simple - DROP FUNCTION | Staging + behavior test |

---

## 2. Rollback Templates

### 2.1 CREATE TABLE Rollback

**Migration:**
```sql
-- Migration: 001_create_audit_logging.sql
BEGIN;

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    user_id UUID,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_logs_org_created ON audit_logs(organization_id, created_at);

COMMIT;
```

**Rollback:**
```sql
-- Rollback for 001_create_audit_logging.sql
BEGIN;

-- Drop indexes first (faster, avoids dependency issues)
DROP INDEX IF EXISTS idx_audit_logs_org_created;
DROP INDEX IF EXISTS idx_audit_logs_user_created;
DROP INDEX IF EXISTS idx_audit_logs_table_created;

-- Drop table
DROP TABLE IF EXISTS audit_logs CASCADE;

COMMIT;
```

### 2.2 ALTER TABLE Rollback

**Migration:**
```sql
-- Migration: 008_add_not_null_constraints.sql
BEGIN;

ALTER TABLE menu_items
ALTER COLUMN organization_id SET NOT NULL;

COMMIT;
```

**Rollback:**
```sql
-- Rollback for 008_add_not_null_constraints.sql
BEGIN;

ALTER TABLE menu_items
ALTER COLUMN organization_id DROP NOT NULL;

COMMIT;
```

### 2.3 RLS Policy Rollback

**Migration:**
```sql
-- Migration: 007_fix_public_org_lookup.sql
BEGIN;

-- Drop old policy
DROP POLICY IF EXISTS "Public can read basic org info by slug" ON organizations;

-- Create new authenticated-only policy
CREATE POLICY "Authenticated can read basic org info by slug"
ON organizations FOR SELECT TO authenticated
USING (is_active = true AND deleted_at IS NULL);

COMMIT;
```

**Rollback:**
```sql
-- Rollback for 007_fix_public_org_lookup.sql
BEGIN;

-- Drop new policy
DROP POLICY IF EXISTS "Authenticated can read basic org info by slug" ON organizations;

-- Recreate old public policy
CREATE POLICY "Public can read basic org info by slug"
ON organizations FOR SELECT
USING (is_active = true AND deleted_at IS NULL);

COMMIT;
```

### 2.4 Function/Trigger Rollback

**Migration:**
```sql
-- Migration: 009_create_audit_logging.sql
BEGIN;

CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    -- Trigger logic here
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_menu_items
    AFTER INSERT OR UPDATE OR DELETE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

COMMIT;
```

**Rollback:**
```sql
-- Rollback for 009_create_audit_logging.sql
BEGIN;

-- Drop triggers first
DROP TRIGGER IF EXISTS audit_menu_items ON menu_items;
DROP TRIGGER IF EXISTS audit_organizations ON organizations;
DROP TRIGGER IF EXISTS audit_organization_members ON organization_members;
DROP TRIGGER IF EXISTS audit_ordini ON ordini;

-- Drop function
DROP FUNCTION IF EXISTS audit_trigger_func() CASCADE;
DROP FUNCTION IF EXISTS log_audit(TEXT, UUID, TEXT, JSONB, JSONB) CASCADE;

COMMIT;
```

### 2.5 Data Migration Rollback

**Migration:**
```sql
-- Migration: Example data migration
BEGIN;

-- Create backup table
CREATE TABLE organization_members_backup_20260127 AS
SELECT * FROM organization_members;

-- Update data
UPDATE organization_members
SET role = 'customer'
WHERE role = 'member' AND organization_id IS NOT NULL;

COMMIT;
```

**Rollback:**
```sql
-- Rollback for data migration
BEGIN;

-- Restore from backup (using join to handle deletions)
UPDATE organization_members om
SET role = backup.role
FROM organization_members_backup_20260127 backup
WHERE om.id = backup.id;

-- Handle any deleted rows if needed
INSERT INTO organization_members
SELECT * FROM organization_members_backup_20260127 backup
WHERE NOT EXISTS (SELECT 1 FROM organization_members om WHERE om.id = backup.id);

-- Drop backup table
DROP TABLE IF EXISTS organization_members_backup_20260127;

COMMIT;
```

---

## 3. Rollback Execution Procedure

### 3.1 Step-by-Step Rollback

When a migration fails or causes issues:

```bash
# 1. IDENTIFY THE PROBLEM
# Check error logs
supabase db logs --project-ref qgnecuqcfzzclhwatzpv

# Verify current migration state
supabase migration list --project-ref qgnecuqcfzzclhwatzpv

# 2. NOTIFY STAKEHOLDERS
# Send alert to team
# Post status to #engineering Slack

# 3. PREPARE ROLLBACK
# Open the migration file
# Copy the rollback section

# 4. CREATE BACKUP (if not recent)
supabase db dump --project-ref qgnecuqcfzzclhwatzpv > backup_before_rollback.sql

# 5. EXECUTE ROLLBACK
# Option A: Via psql
psql "$DATABASE_URL" -f rollback_XXX_migration_name.sql

# Option B: Via Supabase CLI
supabase db execute --file rollback_XXX.sql --project-ref qgnecuqcfzzclhwatzpv

# 6. VERIFY
# Check affected data
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM affected_table;"

# Run smoke tests
# Check application logs

# 7. DOCUMENT
# Log rollback incident
# Update migration status
```

### 3.2 Rollback Verification Checklist

After executing rollback:

- [ ] **Migration status** - Supabase shows migration rolled back
- [ ] **Schema verified** - Tables/columns match pre-migration state
- [ ] **Data verified** - Critical data queries return expected results
- [ ] **Application starts** - No schema errors in application logs
- [ ] **Smoke tests pass** - Basic operations work
- [ ] **Performance OK** - Query times acceptable
- [ ] **RLS working** - Test user can see only their data
- [ ] **Edge functions** - All functions deploy and run

---

## 4. Emergency Rollback Procedures

### 4.1 Complete Database Restore

**Use when:** Migration caused catastrophic damage and rollback is not possible

```bash
# 1. STOP ALL WRITES
# Pause edge functions
supabase functions pause --project-ref qgnecuqcfzzclhwatzpv

# 2. IDENTIFY RESTORE POINT
# Find last known good backup
supabase db logs --project-ref qgnecuqcfzzclhwatzpv

# 3. EXECUTE POINT-IN-TIME RECOVERY
supabase db restore \
  --project-ref qgnecuqcfzzclhwatzpv \
  --to "2026-01-27T10:00:00Z" \
  --type point-in-time

# 4. VERIFY RESTORE
psql "$RESTORE_DB_URL" -c "SELECT COUNT(*) FROM organizations;"

# 5. RESTART SERVICES
supabase functions resume --project-ref qgnecuqcfzzclhwatzpv
```

### 4.2 Selective Table Restore

**Use when:** Single table affected, can restore independently

```sql
-- 1. Rename affected table (backup)
ALTER TABLE affected_table RENAME TO affected_table_broken_20260127;

-- 2. Create new table from backup
CREATE TABLE affected_table AS
SELECT * FROM affected_table_backup
WITH NO DATA;

-- 3. Restore data
INSERT INTO affected_table
SELECT * FROM affected_table_backup;

-- 4. Recreate indexes/constraints
CREATE INDEX idx_aff_table_org_id ON affected_table(organization_id);
ALTER TABLE affected_table ADD PRIMARY KEY (id);

-- 5. Verify
SELECT COUNT(*) FROM affected_table;

-- 6. Drop broken table (after verification)
DROP TABLE affected_table_broken_20260127;
```

---

## 5. Common Rollback Scenarios

### 5.1 Scenario: NOT NULL Constraint Fails

**Problem:** Migration added NOT NULL constraint, but NULL data exists

```sql
-- Original migration (FAILED)
ALTER TABLE menu_items ALTER COLUMN organization_id SET NOT NULL;
-- ERROR: column "organization_id" contains null values
```

**Rollback:**
```sql
-- No changes were made (transaction aborted)
-- Just fix the migration:

-- 1. Update NULL values first
UPDATE menu_items
SET organization_id = (SELECT id FROM organizations LIMIT 1)
WHERE organization_id IS NULL;

-- 2. Then add constraint
ALTER TABLE menu_items ALTER COLUMN organization_id SET NOT NULL;
```

### 5.2 Scenario: Index Creation Times Out

**Problem:** Creating index on large table takes too long

```sql
-- Original migration (STUCK)
CREATE INDEX idx_large_table_column ON large_table(column);
```

**Rollback:**
```sql
-- 1. Cancel the operation in another session
SELECT pg_cancel_backend(pid);
-- Find pid from:
SELECT pid, query, state FROM pg_stat_activity WHERE query LIKE '%CREATE INDEX%';

-- 2. Check if index was partially created
SELECT indexname FROM pg_indexes WHERE tablename = 'large_table';

-- 3. Clean up partial index
DROP INDEX IF EXISTS idx_large_table_column;

-- 4. Recreate with CONCURRENTLY (non-blocking)
CREATE INDEX CONCURRENTLY idx_large_table_column ON large_table(column);
```

### 5.3 Scenario: RLS Policy Breaks Application

**Problem:** New RLS policy blocks legitimate access

```sql
-- Original migration (BREAKS APP)
CREATE POLICY "Too restrictive" ON orders FOR SELECT
USING (organization_id = get_current_organization_id() AND stato = 'confirmed');
```

**Rollback:**
```sql
-- 1. Drop the problematic policy
DROP POLICY IF EXISTS "Too restrictive" ON orders;

-- 2. Recreate previous policy
CREATE POLICY "Users can view their org orders" ON orders FOR SELECT TO authenticated
USING (organization_id = get_current_organization_id());
```

### 5.4 Scenario: Function Has Syntax Error

**Problem:** Function created but has runtime errors

```sql
-- Original migration (RUNTIME ERRORS)
CREATE OR REPLACE FUNCTION broken_func() RETURNS TRIGGER AS $$
BEGIN
    -- Some broken logic here
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Rollback:**
```sql
-- 1. Drop all triggers using the function
DROP TRIGGER IF EXISTS broken_trigger ON affected_table;

-- 2. Drop the function
DROP FUNCTION IF EXISTS broken_func() CASCADE;

-- 3. Recreate working version
CREATE OR REPLACE FUNCTION working_func() RETURNS TRIGGER AS $$
BEGIN
    -- Correct logic
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Recreate trigger
CREATE TRIGGER broken_trigger
    AFTER INSERT ON affected_table
    FOR EACH ROW EXECUTE FUNCTION working_func();
```

---

## 6. Rollback Testing

### 6.1 Pre-Production Testing

**Every migration must be tested with rollback in staging:**

```bash
# 1. Deploy migration to staging
supabase db execute --file migration.sql --project-ref staging-project-ref

# 2. Verify migration success
# Run tests, check data, verify app works

# 3. Execute rollback
supabase db execute --file rollback.sql --project-ref staging-project-ref

# 4. Verify rollback success
# Run tests again, verify pre-migration state

# 5. Document results
echo "✅ Migration and rollback tested successfully"
```

### 6.2 Automated Rollback Test (Optional)

**Script:** `scripts/test-rollback.sh`

```bash
#!/bin/bash
# Test migration rollback in staging

MIGRATION_FILE=$1
ROLLBACK_FILE=$2

if [ -z "$MIGRATION_FILE" ] || [ -z "$ROLLBACK_FILE" ]; then
  echo "Usage: $0 <migration.sql> <rollback.sql>"
  exit 1
fi

STAGING_REF="staging-project-ref"

echo "Testing migration: $MIGRATION_FILE"

# Apply migration
echo "Applying migration..."
supabase db execute --file "$MIGRATION_FILE" --project-ref "$STAGING_REF"

if [ $? -ne 0 ]; then
  echo "❌ Migration failed!"
  exit 1
fi

# Run verification
echo "Running verification..."
# Add your verification queries here

# Apply rollback
echo "Applying rollback..."
supabase db execute --file "$ROLLBACK_FILE" --project-ref "$STAGING_REF"

if [ $? -ne 0 ]; then
  echo "❌ Rollback failed!"
  exit 1
fi

echo "✅ Migration and rollback test passed!"
```

---

## 7. Incident Documentation

### 7.1 Rollback Incident Report Template

```markdown
# Migration Rollback Incident Report

**Date:** YYYY-MM-DD
**Migration:** XXX_migration_name.sql
**Author:** Your Name
**Severity:** 🟡 Medium / 🔴 High

## Summary
Brief description of what went wrong and what was rolled back.

## Timeline
- 10:00 UTC - Migration started
- 10:05 UTC - Alert triggered: high error rate
- 10:07 UTC - Investigation started
- 10:10 UTC - Root cause identified
- 10:12 UTC - Rollback initiated
- 10:15 UTC - Rollback completed
- 10:20 UTC - Service restored

## Root Cause
What caused the migration to fail?

## Impact Assessment
- Users affected: X
- Downtime duration: X minutes
- Data affected: None / Some / All

## Rollback Execution
Steps taken to rollback:

1. Backed up database state
2. Executed rollback script
3. Verified data integrity
4. Restarted services

## Post-Mortem
- What went well?
- What could be improved?
- Action items for next time:

## Resolution
Service fully restored at: HH:MM UTC
Verified by: _________
```

---

## 8. Best Practices

### 8.1 Migration Design Principles

1. **Idempotent** - Migration can be run multiple times safely
2. **Reversible** - Always write rollback steps
3. **Atomic** - Single transaction where possible
4. **Tested** - Test in staging first
5. **Monitored** - Watch metrics after deployment

### 8.2 Safe Migration Patterns

```sql
-- ✅ GOOD: Use IF EXISTS
DROP INDEX IF EXISTS idx_name;
CREATE INDEX idx_name ON table(column);

-- ❌ BAD: Assumes index exists
DROP INDEX idx_name;
CREATE INDEX idx_name ON table(column);

-- ✅ GOOD: Use CONCURRENTLY for large tables
CREATE INDEX CONCURRENTLY idx_name ON large_table(column);

-- ✅ GOOD: Add constraint with validation
ALTER TABLE table ADD CONSTRAINT chk_name CHECK (condition) NOT VALID;
ALTER TABLE table VALIDATE CONSTRAINT chk_name;

-- ✅ GOOD: Use transactions
BEGIN;
-- Multiple related statements
COMMIT;
```

### 8.3 Rollback Anti-Patterns

```sql
-- ❌ BAD: Don't use DROP CASCADE unless necessary
DROP TABLE affected_table CASCADE;

-- ✅ BETTER: Drop specific dependencies first
DROP TRIGGER trigger_name ON table;
DROP FUNCTION function_name();
DROP TABLE table;

-- ❌ BAD: Don't delete data before verifying backup
DELETE FROM users WHERE created_at < '2020-01-01';

-- ✅ BETTER: Archive first, then delete
CREATE TABLE users_archive AS SELECT * FROM users WHERE created_at < '2020-01-01';
-- Verify archive
DELETE FROM users WHERE created_at < '2020-01-01';
```

---

## 9. Contact and Escalation

| Role | Name | Contact |
|------|------|---------|
| Database Owner | TBD | dba@vittoria.app |
| On-Call Engineer | TBD | oncall@vittoria.app |
| Engineering Lead | TBD | eng-lead@vittoria.app |

**Escalation Path:**
1. On-Call Engineer (immediate)
2. Database Owner (if unavailable, 15 min)
3. Engineering Lead (critical incidents, 30 min)

---

## 10. Appendix: Recent Rollbacks Reference

| Date | Migration | Reason | Resolution |
|------|-----------|--------|------------|
| 2026-01-27 | 009_audit_logging | Trigger syntax error | Fixed trigger, re-deployed |
| - | - | - | - |

---

**Next Review:** After each rollback incident
**Document Owner:** Database Team
