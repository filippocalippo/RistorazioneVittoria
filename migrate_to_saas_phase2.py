#!/usr/bin/env python3
"""
Multi-Tenant Migration Script - Phase 2
========================================
Updates DatabaseService, providers, and settings models with organization support.

Usage:
    python migrate_to_saas_phase2.py --dry-run     # Preview changes
    python migrate_to_saas_phase2.py --apply       # Apply changes
"""

import os
import re
import sys
import shutil
import argparse
from datetime import datetime
from pathlib import Path
from typing import List, Tuple

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT_ROOT = Path(__file__).parent
LIB_DIR = PROJECT_ROOT / "lib"
BACKUP_DIR = PROJECT_ROOT / "migration_backup_phase2"

# Tables that need organization_id filtering
ORG_TABLES = {
    'menu_items', 'categorie_menu', 'ingredients', 'sizes_master',
    'ingredient_size_prices', 'menu_item_sizes', 'menu_item_included_ingredients',
    'menu_item_extra_ingredients', 'ordini', 'ordini_items', 'notifiche',
    'cashier_customers', 'daily_order_counters', 'allowed_cities', 'delivery_zones',
    'business_rules', 'delivery_configuration', 'order_management',
    'kitchen_management', 'display_branding', 'dashboard_security',
    'promotional_banners', 'ingredient_consumption_rules', 'inventory_logs',
    'payment_transactions', 'statistiche_giornaliere', 'order_reminders'
}


def create_backup():
    """Create backup of files before modification"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = BACKUP_DIR / timestamp
    backup_path.mkdir(parents=True, exist_ok=True)
    
    print(f"📁 Creating backup at {backup_path}...")
    
    # Backup key files
    files_to_backup = [
        LIB_DIR / "core" / "services" / "database_service.dart",
        LIB_DIR / "providers" / "organization_provider.dart",
    ]
    
    # Add all provider files
    providers_dir = LIB_DIR / "providers"
    for f in providers_dir.glob("*.dart"):
        if not f.name.endswith('.g.dart'):
            files_to_backup.append(f)
    
    for f in files_to_backup:
        if f.exists():
            dest = backup_path / f.relative_to(LIB_DIR)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dest)
    
    print(f"✅ Backup created")
    return backup_path


def update_organization_provider(dry_run: bool) -> bool:
    """Enhance organization_provider.dart with more features"""
    
    provider_path = LIB_DIR / "providers" / "organization_provider.dart"
    
    new_content = '''import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'organization_provider.g.dart';

/// Current organization ID for multi-tenant queries
/// 
/// This is THE source of truth for org context across the app.
/// All data-fetching providers should watch this.
@riverpod
class CurrentOrganization extends _$CurrentOrganization {
  @override
  Future<String?> build() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      // Get user's current organization from profile
      final response = await client
          .from('profiles')
          .select('current_organization_id')
          .eq('id', userId)
          .maybeSingle();
      
      final orgId = response?['current_organization_id'] as String?;
      if (orgId != null) return orgId;
      
      // Fallback: get first organization user belongs to
      final orgs = await client
          .from('organization_members')
          .select('organization_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1);
      
      if (orgs.isNotEmpty) {
        final firstOrgId = orgs.first['organization_id'] as String;
        // Set as current
        await client
            .from('profiles')
            .update({'current_organization_id': firstOrgId})
            .eq('id', userId);
        return firstOrgId;
      }
      
      // Fallback: get any active organization (for single-tenant compatibility)
      final anyOrg = await client
          .from('organizations')
          .select('id')
          .eq('is_active', true)
          .limit(1);
      
      if (anyOrg.isNotEmpty) {
        return anyOrg.first['id'] as String;
      }
      
      return null;
    } catch (e) {
      // Fallback for compatibility
      try {
        final orgs = await client
            .from('organizations')
            .select('id')
            .eq('is_active', true)
            .limit(1);
        if (orgs.isNotEmpty) {
          return orgs.first['id'] as String;
        }
      } catch (_) {}
      return null;
    }
  }
  
  /// Switch to a different organization
  Future<void> switchOrganization(String organizationId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    
    await client
        .from('profiles')
        .update({'current_organization_id': organizationId})
        .eq('id', userId);
    
    ref.invalidateSelf();
  }
  
  /// Refresh organization context
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// List of organizations the current user belongs to
@riverpod
Future<List<Map<String, dynamic>>> userOrganizations(UserOrganizationsRef ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  
  final response = await client
      .from('organization_members')
      .select('organization:organizations(*)')
      .eq('user_id', userId)
      .eq('is_active', true);
  
  return response
      .map((e) => e['organization'] as Map<String, dynamic>)
      .toList();
}

/// Check if user is member of specific organization
@riverpod
Future<bool> isOrganizationMember(IsOrganizationMemberRef ref, String organizationId) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;
  
  final response = await client
      .from('organization_members')
      .select('id')
      .eq('user_id', userId)
      .eq('organization_id', organizationId)
      .eq('is_active', true)
      .maybeSingle();
  
  return response != null;
}

/// Get user's role in current organization
@riverpod
Future<String?> organizationRole(OrganizationRoleRef ref) async {
  final orgId = await ref.watch(currentOrganizationProvider.future);
  if (orgId == null) return null;
  
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  
  final response = await client
      .from('organization_members')
      .select('role')
      .eq('user_id', userId)
      .eq('organization_id', orgId)
      .maybeSingle();
  
  return response?['role'] as String?;
}
'''
    
    if dry_run:
        print("  ✅ organization_provider.dart: Would update with enhanced features")
        return True
    
    provider_path.write_text(new_content, encoding='utf-8')
    print("  ✅ organization_provider.dart: Enhanced with multi-org support")
    return True


def get_provider_files() -> List[Path]:
    """Get all provider files that need updating"""
    providers_dir = LIB_DIR / "providers"
    files = []
    
    for f in providers_dir.glob("*.dart"):
        if f.name.endswith('.g.dart'):
            continue
        if f.name == 'organization_provider.dart':
            continue
        files.append(f)
    
    return sorted(files)


def update_provider_file(file_path: Path, dry_run: bool) -> Tuple[bool, int]:
    """Update a provider file to use organization context"""
    
    content = file_path.read_text(encoding='utf-8')
    original = content
    changes = 0
    
    # Check if file has direct Supabase calls
    if 'Supabase.instance.client' not in content:
        return False, 0
    
    # Check if already updated
    if 'currentOrganizationProvider' in content:
        return False, 0
    
    # Add import if needed
    org_import = "import 'organization_provider.dart';"
    if org_import not in content and 'organization_provider.dart' not in content:
        # Find first import line
        import_match = re.search(r'^import ', content, re.MULTILINE)
        if import_match:
            content = content[:import_match.start()] + org_import + '\n' + content[import_match.start():]
            changes += 1
    
    # Add organization context to @riverpod functions
    # Pattern: Find functions that use Supabase.instance.client and add org context
    
    # For now, just add a TODO comment at the top of functions using Supabase
    # This is safer than trying to auto-modify complex logic
    
    if changes > 0 or 'Supabase.instance.client' in content:
        if dry_run:
            print(f"  ✅ {file_path.name}: Would add org import")
            return True, 1
        
        file_path.write_text(content, encoding='utf-8')
        print(f"  ✅ {file_path.name}: Added org import")
        return True, changes
    
    return False, 0


def update_settings_models(dry_run: bool) -> int:
    """Add organizationId to settings models"""
    
    settings_dir = LIB_DIR / "core" / "models" / "settings"
    updates = 0
    
    settings_files = [
        'business_rules_settings.dart',
        'delivery_configuration_settings.dart',
        'display_branding_settings.dart',
        'kitchen_management_settings.dart',
        'order_management_settings.dart',
    ]
    
    for filename in settings_files:
        file_path = settings_dir / filename
        if not file_path.exists():
            continue
            
        content = file_path.read_text(encoding='utf-8')
        
        # Check if already has organizationId
        if 'organizationId' in content or 'organization_id' in content:
            continue
        
        # Find factory constructor and add organizationId
        # Pattern: factory ClassName({ ... }) = _ClassName;
        factory_pattern = r"(factory\s+\w+\s*\(\s*\{)([^}]*?)(\}\s*\)\s*=\s*_\w+;)"
        
        match = re.search(factory_pattern, content, re.DOTALL)
        if not match:
            print(f"  ⚠️ {filename}: Could not find factory constructor")
            continue
        
        before = match.group(1)
        fields = match.group(2)
        after = match.group(3)
        
        new_field = "\n    @JsonKey(name: 'organization_id') String? organizationId,"
        new_content = content[:match.start()] + before + new_field + fields + after + content[match.end():]
        
        if dry_run:
            print(f"  ✅ {filename}: Would add organizationId field")
        else:
            file_path.write_text(new_content, encoding='utf-8')
            print(f"  ✅ {filename}: Added organizationId field")
        
        updates += 1
    
    return updates


def create_org_aware_database_service_helper():
    """Create a helper file for org-aware database operations"""
    
    helper_content = '''/// Organization-aware database helpers
/// 
/// Use these extensions to easily add organization filtering to queries.

import 'package:supabase_flutter/supabase_flutter.dart';

extension OrganizationAwareQuery on PostgrestFilterBuilder {
  /// Add organization filter if orgId is provided
  PostgrestFilterBuilder orgFilter(String? organizationId) {
    if (organizationId != null) {
      return eq('organization_id', organizationId);
    }
    return this;
  }
}

extension OrganizationAwareInsert on Map<String, dynamic> {
  /// Add organization_id to insert payload
  Map<String, dynamic> withOrgId(String? organizationId) {
    if (organizationId != null) {
      this['organization_id'] = organizationId;
    }
    return this;
  }
}
'''
    
    helper_path = LIB_DIR / "core" / "utils" / "org_aware_helpers.dart"
    return helper_content, helper_path


def main():
    parser = argparse.ArgumentParser(description='Multi-Tenant Migration Phase 2')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes')
    parser.add_argument('--apply', action='store_true', help='Apply changes')
    parser.add_argument('--skip-backup', action='store_true', help='Skip backup')
    
    args = parser.parse_args()
    
    if not any([args.dry_run, args.apply]):
        parser.print_help()
        print("\n⚠️  Please specify --dry-run or --apply")
        sys.exit(1)
    
    print("🚀 Multi-Tenant Migration - Phase 2")
    print("="*60)
    
    if not LIB_DIR.exists():
        print(f"❌ Error: lib/ directory not found")
        sys.exit(1)
    
    dry_run = args.dry_run
    
    if args.apply and not args.skip_backup:
        create_backup()
    
    print("\n📝 Step 1: Updating organization_provider.dart...")
    update_organization_provider(dry_run)
    
    print("\n📝 Step 2: Updating settings models...")
    settings_updates = update_settings_models(dry_run)
    print(f"   Updated {settings_updates} settings models")
    
    print("\n📝 Step 3: Adding org import to providers...")
    provider_files = get_provider_files()
    provider_updates = 0
    for f in provider_files:
        updated, _ = update_provider_file(f, dry_run)
        if updated:
            provider_updates += 1
    print(f"   Updated {provider_updates} provider files")
    
    print("\n📝 Step 4: Creating org-aware helper utilities...")
    helper_content, helper_path = create_org_aware_database_service_helper()
    if dry_run:
        print(f"  ✅ Would create: {helper_path.name}")
    else:
        helper_path.parent.mkdir(parents=True, exist_ok=True)
        helper_path.write_text(helper_content, encoding='utf-8')
        print(f"  ✅ Created: {helper_path.name}")
    
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"  Organization provider: Enhanced")
    print(f"  Settings models: {settings_updates} updated")
    print(f"  Provider files: {provider_updates} updated")
    print(f"  Helper utilities: Created")
    
    if dry_run:
        print("\n⚠️  DRY RUN - No files were modified")
        print("   Run with --apply to make changes")
    else:
        print("\n✅ Phase 2 complete!")
        print("\n📋 Next steps:")
        print("   1. Run: dart run build_runner build --delete-conflicting-outputs")
        print("   2. Update DatabaseService methods to accept organizationId")
        print("   3. Create a test organization in database")
        print("   4. Test the app")


if __name__ == '__main__':
    main()
