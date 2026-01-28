# Backup Strategy

## Vittoria Ristorazione - Multi-Tenant SaaS Application

**Version:** 1.0
**Last Updated:** 2026-01-27
**Responsible:** DevOps / Database Administrator

---

## Executive Summary

This document outlines the comprehensive backup strategy for the Vittoria Ristorazione multi-tenant application. Given the SaaS nature with multiple organizations depending on this system, we maintain a layered backup approach with automated and manual options.

### Key Metrics

| Metric | Value |
|--------|-------|
| **RPO** (Recovery Point Objective) | 24 hours |
| **RTO** (Recovery Time Objective) | 4 hours |
| **Retention Period** | 30 days (daily), 90 days (weekly), 1 year (monthly) |
| **Backup Frequency** | Continuous (Supabase) + Daily (manual) |

---

## 1. Supabase Automated Backups

### 1.1 Built-in Backup Features

Supabase provides automated PostgreSQL backups as part of their managed service:

```
Frequency: Continuous (WAL) + Daily snapshots
Retention: 7 days (Pro plan)
Location: Same region as project
```

**What's Included:**
- All database tables and data
- Row Level Security (RLS) policies
- Functions and triggers
- Database schema

**What's NOT Included:**
- Storage files (images, documents)
- Edge Functions code
- Authentication configuration

### 1.2 Accessing Automated Backups

**Via Supabase Dashboard:**
1. Navigate to Project → Database → Backups
2. Select point-in-time to restore
3. Click "Restore" to create a new branch

**Via CLI:**
```bash
# List available backups
supabase db logs --project-ref qgnecuqcfzzclhwatzpv

# Restore to specific point in time (creates branch)
supabase branches restore \
  --project-ref qgnecuqcfzzclhwatzpv \
  --timestamp "2026-01-27T10:00:00Z"
```

---

## 2. Manual Backup Procedures

### 2.1 Daily Database Export

**Script:** `scripts/backup-database.sh`

```bash
#!/bin/bash
# Backup script for Supabase PostgreSQL
# Run daily via cron: 0 2 * * * /path/to/backup-database.sh

set -e

BACKUP_DIR="/backups/daily"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vittoria_db_${TIMESTAMP}.sql.gz"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Environment variables
PROJECT_REF="qgnecuqcfzzclhwatzpv"
DB_URL="postgresql://postgres:[YOUR-PASSWORD]@db.qgnecuqcfzzclhwatzpv.supabase.co:5432/postgres"

# Create backup
echo "Starting backup: $TIMESTAMP"
pg_dump "$DB_URL" \
  --format=plain \
  --no-owner \
  --no-acl \
  --exclude-table-data='auth.refresh_tokens' \
  --exclude-table-data='storage.objects' \
  | gzip > "$BACKUP_FILE"

# Verify backup
if [ -f "$BACKUP_FILE" ]; then
  SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "Backup completed: $BACKUP_FILE ($SIZE)"
else
  echo "ERROR: Backup failed!"
  exit 1
fi

# Clean old backups (keep 30 days)
find "$BACKUP_DIR" -name "vittoria_db_*.sql.gz" -mtime +30 -delete

echo "Backup cleanup completed"
```

**Windows PowerShell equivalent:**
```powershell
# backup-database.ps1
$BackupDir = "C:\backups\daily"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = "$BackupDir\vittoria_db_$Timestamp.sql.gz"

New-Item -ItemType Directory -Force -Path $BackupDir

$Env:PGPASSWORD = "your-password"
pg_dump `
  --host="db.qgnecuqcfzzclhwatzpv.supabase.co" `
  --port="5432" `
  --username="postgres" `
  --dbname="postgres" `
  --format=plain `
  --no-owner `
  --no-acl `
  | gzip > $BackupFile

Write-Host "Backup completed: $BackupFile"
```

### 2.2 Storage Backup

**Script:** `scripts/backup-storage.sh`

```bash
#!/bin/bash
# Backup all storage buckets

BACKUP_DIR="/backups/storage"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# List buckets
BUCKETS=("organization-logos" "product-images" "documents")

for bucket in "${BUCKETS[@]}"; do
  echo "Backing up bucket: $bucket"
  mkdir -p "$BACKUP_DIR/$TIMESTAMP/$bucket"

  # Download all files from bucket
  supabase storage cp -r \
    --project-ref qgnecuqcfzzclhwatzpv \
    "sb://$bucket/" \
    "$BACKUP_DIR/$TIMESTAMP/$bucket/"
done

# Create archive
tar -czf "$BACKUP_DIR/storage_$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "$TIMESTAMP"
rm -rf "$BACKUP_DIR/$TIMESTAMP"

echo "Storage backup completed"
```

### 2.3 Critical Data Export (CSV)

For quick access to critical business data:

```sql
-- Script: scripts/export-critical-data.sql

-- 1. Organizations (tenant registry)
\copy (
  SELECT id, name, slug, email, phone, city, is_active, created_at
  FROM organizations
  WHERE deleted_at IS NULL
) TO '/backups/csv/organizations_$(date +%Y%m%d).csv' CSV HEADER;

-- 2. Organization Members (user relationships)
\copy (
  SELECT om.*, o.name as organization_name, p.email as user_email
  FROM organization_members om
  JOIN organizations o ON om.organization_id = o.id
  JOIN profiles p ON om.user_id = p.id
  WHERE om.is_active = true
) TO '/backups/csv/members_$(date +%Y%m%d).csv' CSV HEADER;

-- 3. Recent Orders (last 30 days)
\copy (
  SELECT o.id, o.numero_ordine, o.nome_cliente, o.totale,
         o.stato, o.tipo, o.created_at,
         org.name as organization_name
  FROM ordini o
  JOIN organizations org ON o.organization_id = org.id
  WHERE o.created_at >= NOW() - INTERVAL '30 days'
  ORDER BY o.created_at DESC
) TO '/backups/csv/orders_$(date +%Y%m%d).csv' CSV HEADER;
```

---

## 3. Backup Retention Policy

### 3.1 Retention Schedule

| Backup Type | Retention | Location |
|-------------|-----------|----------|
| Daily snapshots | 30 days | Local + Cloud |
| Weekly archives | 90 days | Cloud only (S3/Glacier) |
| Monthly archives | 1 year | Cold storage (Glacier) |
| Supabase automated | 7 days | Supabase (managed) |

### 3.2 Storage Strategy

```
/backups/
├── daily/           # Last 30 days - local storage
│   ├── vittoria_db_20260127.sql.gz
│   ├── vittoria_db_20260126.sql.gz
│   └── ...
├── weekly/          # Last 12 weeks - cloud storage
│   ├── vittoria_db_week_04_2026.sql.gz
│   └── ...
├── monthly/         # Last 12 months - cold storage
│   ├── vittoria_db_2026_01.sql.gz
│   └── ...
└── csv/             # Daily exports - 7 days
    ├── organizations_20260127.csv
    └── ...
```

### 3.3 Offsite Backup

**Recommended Cloud Storage:**

**AWS S3:**
```bash
# Upload to S3
aws s3 sync /backups/daily s3://vittoria-backups/daily \
  --storage-class STANDARD_IA \
  --sse AES256

# Lifecycle policy (after 30 days move to Glacier)
aws s3api put-bucket-lifecycle-configuration \
  --bucket vittoria-backups \
  --lifecycle-configuration file://lifecycle.json
```

**Google Cloud Storage:**
```bash
# Upload to GCS
gsutil -m rsync -r /backups/daily gs://vittoria-backups/daily

# Set lifecycle policy
gsutil lifecycle set lifecycle.json gs://vittoria-backups
```

---

## 4. Restore Procedures

### 4.1 Complete Database Restore

**Scenario:** Complete database failure

```bash
# 1. Stop application
# Prevent writes during restore
supabase functions pause --project-ref qgnecuqcfzzclhwatzpv

# 2. Identify backup to restore
BACKUP_FILE="/backups/daily/vittoria_db_20260127_020000.sql.gz"

# 3. Create restore branch (safest method)
supabase branches create \
  --project-ref qgnecuqcfzzclhwatzpv \
  --backup-id "$BACKUP_FILE"

# 4. Verify restored data
psql "$RESTORE_DB_URL" -c "SELECT COUNT(*) FROM organizations;"

# 5. If verified, swap with production
supabase branches switch \
  --project-ref qgnecuqcfzzclhwatzpv \
  --branch-name restore_20260127

# 6. Resume application
supabase functions resume --project-ref qgnecuqcfzzclhwatzpv
```

### 4.2 Partial Table Restore

**Scenario:** Accidental data deletion in specific table

```sql
-- 1. Create temporary table from backup
CREATE TEMP TABLE menu_items_backup AS
SELECT * FROM menu_items;

-- 2. Restore specific deleted rows
INSERT INTO menu_items
SELECT * FROM menu_items_backup
WHERE id IN ('deleted-id-1', 'deleted-id-2');

-- 3. Verify data
SELECT * FROM menu_items WHERE id = 'deleted-id-1';

-- 4. Drop temp table
DROP TABLE menu_items_backup;
```

### 4.3 Point-in-Time Recovery

**Scenario:** Recover data from specific time before error

```bash
# Using Supabase time travel
supabase db restore \
  --project-ref qgnecuqcfzzclhwatzpv \
  --to "2026-01-27T14:30:00Z" \
  --type point-in-time
```

---

## 5. Testing Schedule

### 5.1 Monthly Restore Testing

**First Tuesday of every month:**

1. **Random Backup Selection** - Choose a random backup from previous month
2. **Sandbox Restore** - Restore to development environment
3. **Data Verification** - Verify critical data integrity:
   - Organization count matches
   - User memberships intact
   - Recent orders present
   - Menu items complete
4. **Application Test** - Run basic smoke tests
5. **Documentation** - Log test results

**Test Report Template:**
```markdown
# Monthly Restore Test - 2026-01

## Backup Tested
- File: vittoria_db_20260102_020000.sql.gz
- Size: 450 MB
- Age: 25 days

## Restore Results
- [ ] Restore completed successfully
- [ ] Organizations: 124 expected, 124 found
- [ ] Memberships: 1,847 expected, 1,847 found
- [ ] Orders (last 30 days): 3,421 expected, 3,421 found
- [ ] Menu items: 2,156 expected, 2,156 found

## Application Smoke Tests
- [ ] Login successful
- [ ] Organization switching works
- [ ] Order placement works
- [ ] Menu loading works

## Issues Found
- None

## Signature
Tested by: _____________  Date: _______
```

### 5.2 Quarterly DR Drill

**Full disaster recovery simulation:**
1. Simulate complete production failure
2. Execute full restore procedure
3. Target RTO: Under 4 hours
4. Document lessons learned

---

## 6. Backup Integrity Verification

### 6.1 Automated Checks

**Script:** `scripts/verify-backups.sh`

```bash
#!/bin/bash
# Verify backup integrity

BACKUP_DIR="/backups/daily"
ALERT_EMAIL="admin@vittoria.app"

for file in "$BACKUP_DIR"/*.sql.gz; do
  filename=$(basename "$file")

  # Check file exists and is readable
  if [ ! -r "$file" ]; then
    echo "ERROR: Cannot read backup: $file" | mail -s "Backup Alert" "$ALERT_EMAIL"
    continue
  fi

  # Check file size (should be > 100MB for production)
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
  if [ "$size" -lt 104857600 ]; then
    echo "WARNING: Backup too small: $filename ($size bytes)" | mail -s "Backup Alert" "$ALERT_EMAIL"
  fi

  # Test gzip integrity
  if ! gzip -t "$file" 2>/dev/null; then
    echo "ERROR: Corrupted backup: $filename" | mail -s "Backup Alert" "$ALERT_EMAIL"
  fi

  # Count tables in backup (should be ~31)
  table_count=$(zcat "$file" | grep -c "CREATE TABLE" || echo "0")
  if [ "$table_count" -lt 20 ]; then
    echo "WARNING: Low table count in backup: $filename ($table_count tables)" | mail -s "Backup Alert" "$ALERT_EMAIL"
  fi
done

echo "Backup verification completed"
```

### 6.2 Daily Health Check

**Run via cron at 3 AM daily:**
```bash
# Check Supabase backup status
supabase db logs --project-ref qgnecuqcfzzclhwatzpv \
  --limit 1 \
  | grep -q "BACKUP_SUCCESS" || echo "Backup failed" | mail -s "Backup Alert" admin@vittoria.app
```

---

## 7. Monitoring and Alerting

### 7.1 Key Metrics to Monitor

| Metric | Alert Threshold | Severity |
|--------|-----------------|----------|
| Backup failure | Any failure | 🔴 Critical |
| Backup size | < 100MB | ⚠️ Warning |
| Restore test failure | Any failure | 🔴 Critical |
| Backup age | > 26 hours | ⚠️ Warning |
| Storage space | < 20% free | 🔴 Critical |

### 7.2 Alert Channels

- **Email:** admin@vittoria.app
- **Slack:** #alerts-backup
- **Pager:** For critical failures only

### 7.3 Dashboard (Recommended)

Create a simple dashboard showing:
- Last successful backup time
- Backup size trend
- Restore test results
- Storage utilization

---

## 8. Compliance and Legal

### 8.1 Data Privacy

- **GDPR Compliance:** All backups encrypted at rest
- **Data Retention:** Follow customer data retention policies
- **Right to Erasure:** Backup deletion on customer request

### 8.2 Backup Encryption

```bash
# Encrypt backup with GPG
pg_dump "$DB_URL" | gzip | gpg --encrypt --recipient admin@vittoria.app > backup.sql.gz.gpg

# Decrypt for restore
gpg --decrypt backup.sql.gz.gpg | gunzip | psql "$DB_URL"
```

---

## 9. Contact and Escalation

| Role | Name | Contact |
|------|------|---------|
| Database Owner | TBD | dba@vittoria.app |
| DevOps Engineer | TBD | devops@vittoria.app |
| Incident Commander | TBD | oncall@vittoria.app |

---

## 10. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-01-27 | 1.0 | Initial document | Security Fix |

---

**Next Review:** 2026-04-27 (Quarterly)
