#!/usr/bin/env python3
"""
SaaS Migration Script for Vittoria Ristorazione
================================================
Automates the addition of organization_id support to the Flutter codebase.

Usage:
    python migrate_to_saas.py --dry-run     # Preview changes
    python migrate_to_saas.py --apply       # Apply changes
    python migrate_to_saas.py --report      # Generate report only
"""

import os
import re
import sys
import shutil
import argparse
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Tuple, Set

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Configuration
PROJECT_ROOT = Path(__file__).parent
LIB_DIR = PROJECT_ROOT / "lib"
BACKUP_DIR = PROJECT_ROOT / "migration_backup"
MODELS_DIR = LIB_DIR / "core" / "models"
SERVICES_DIR = LIB_DIR / "core" / "services"
DATABASE_SERVICE = SERVICES_DIR / "database_service.dart"

# Tables that need organization_id (from our migrations)
ORG_TABLES = {
    'organizations', 'organization_members', 'profiles', 'categorie_menu',
    'sizes_master', 'ingredients', 'ingredient_size_prices', 'menu_items',
    'menu_item_sizes', 'menu_item_included_ingredients', 'menu_item_extra_ingredients',
    'allowed_cities', 'delivery_zones', 'cashier_customers', 'daily_order_counters',
    'ordini', 'ordini_items', 'order_reminders', 'notifiche', 'business_rules',
    'delivery_configuration', 'order_management', 'kitchen_management',
    'display_branding', 'dashboard_security', 'promotional_banners',
    'ingredient_consumption_rules', 'inventory_logs', 'payment_transactions',
    'statistiche_giornaliere'
}

# Models that should get organizationId field
MODEL_FILES_TO_UPDATE = [
    'menu_item_model.dart',
    'category_model.dart',
    'ingredient_model.dart',
    'order_model.dart',
    'order_item_model.dart',
    'promotional_banner_model.dart',
    'delivery_zone_model.dart',
    'allowed_city_model.dart',
    'cashier_customer_model.dart',
    'ingredient_size_price_model.dart',
    'menu_item_size_assignment_model.dart',
    'menu_item_extra_ingredient_model.dart',
    'menu_item_included_ingredient_model.dart',
]

# Skip these models (user-scoped, not org-scoped)
SKIP_MODELS = [
    'user_model.dart',
    'user_address_model.dart',
    'cart_item_model.dart',
]


class MigrationReport:
    def __init__(self):
        self.model_updates: List[str] = []
        self.service_updates: List[str] = []
        self.errors: List[str] = []
        self.warnings: List[str] = []
        
    def add_model_update(self, file: str, change: str):
        self.model_updates.append(f"{file}: {change}")
        
    def add_service_update(self, method: str, change: str):
        self.service_updates.append(f"{method}: {change}")
        
    def add_error(self, msg: str):
        self.errors.append(msg)
        
    def add_warning(self, msg: str):
        self.warnings.append(msg)
        
    def print_summary(self):
        print("\n" + "="*60)
        print("MIGRATION REPORT")
        print("="*60)
        
        print(f"\n📦 Model Updates ({len(self.model_updates)}):")
        for u in self.model_updates[:10]:
            print(f"  ✅ {u}")
        if len(self.model_updates) > 10:
            print(f"  ... and {len(self.model_updates) - 10} more")
            
        print(f"\n🔧 Service Updates ({len(self.service_updates)}):")
        for u in self.service_updates[:10]:
            print(f"  ✅ {u}")
        if len(self.service_updates) > 10:
            print(f"  ... and {len(self.service_updates) - 10} more")
            
        if self.warnings:
            print(f"\n⚠️ Warnings ({len(self.warnings)}):")
            for w in self.warnings:
                print(f"  ⚠️ {w}")
                
        if self.errors:
            print(f"\n❌ Errors ({len(self.errors)}):")
            for e in self.errors:
                print(f"  ❌ {e}")
                
        print("\n" + "="*60)
        

def create_backup():
    """Create backup of files before modification"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = BACKUP_DIR / timestamp
    
    print(f"📁 Creating backup at {backup_path}...")
    
    # Backup models
    models_backup = backup_path / "models"
    models_backup.mkdir(parents=True, exist_ok=True)
    for model_file in MODELS_DIR.glob("*.dart"):
        if not model_file.name.endswith(('.freezed.dart', '.g.dart')):
            shutil.copy2(model_file, models_backup / model_file.name)
    
    # Backup database service
    services_backup = backup_path / "services"
    services_backup.mkdir(parents=True, exist_ok=True)
    if DATABASE_SERVICE.exists():
        shutil.copy2(DATABASE_SERVICE, services_backup / DATABASE_SERVICE.name)
    
    print(f"✅ Backup created: {backup_path}")
    return backup_path


def add_organization_id_to_model(file_path: Path, report: MigrationReport, dry_run: bool) -> bool:
    """Add organizationId field to a Freezed model file"""
    
    if not file_path.exists():
        report.add_warning(f"File not found: {file_path.name}")
        return False
        
    content = file_path.read_text(encoding='utf-8')
    
    # Check if already has organizationId
    if 'organizationId' in content or 'organization_id' in content:
        report.add_warning(f"{file_path.name}: Already has organizationId, skipping")
        return False
    
    # Find the class factory constructor and add the field
    # Pattern: factory ClassName({ ... }) = _ClassName;
    factory_pattern = r'(factory\s+\w+\s*\(\s*\{)([^}]*?)(\}\s*\)\s*=\s*_\w+;)'
    
    match = re.search(factory_pattern, content, re.DOTALL)
    if not match:
        report.add_warning(f"{file_path.name}: Could not find factory constructor")
        return False
    
    before = match.group(1)
    fields = match.group(2)
    after = match.group(3)
    
    # Add organizationId as first optional field (after required fields)
    # Find a good insertion point - after the last required field or at the start
    new_field = "\n    @JsonKey(name: 'organization_id') String? organizationId,"
    
    # Insert after the opening brace, before existing fields
    new_fields = new_field + fields
    new_content = content[:match.start()] + before + new_fields + after + content[match.end():]
    
    if dry_run:
        report.add_model_update(file_path.name, "Would add organizationId field")
        return True
    
    # Write the updated content
    file_path.write_text(new_content, encoding='utf-8')
    report.add_model_update(file_path.name, "Added organizationId field")
    return True


def update_database_service(report: MigrationReport, dry_run: bool) -> int:
    """Update DatabaseService methods to support organization filtering"""
    
    if not DATABASE_SERVICE.exists():
        report.add_error(f"DatabaseService not found at {DATABASE_SERVICE}")
        return 0
        
    content = DATABASE_SERVICE.read_text(encoding='utf-8')
    original_content = content
    updates_count = 0
    
    # Pattern 1: .from('table_name').select() -> add .eq('organization_id', orgId)
    # We need to be careful - only update queries for org-scoped tables
    
    for table in ORG_TABLES:
        # Pattern: .from('table').select(...)
        # We'll add a comment marker for manual review
        patterns = [
            # Simple select
            (rf"\.from\s*\(\s*['\"]({table})['\"]\s*\)\s*\.select\s*\(",
             f".from('{table}').select( /* TODO: Add .eq('organization_id', orgId) */ "),
            
            # Insert
            (rf"\.from\s*\(\s*['\"]({table})['\"]\s*\)\s*\.insert\s*\(",
             f".from('{table}').insert( /* TODO: Add organization_id to payload */ "),
             
            # Update
            (rf"\.from\s*\(\s*['\"]({table})['\"]\s*\)\s*\.update\s*\(",
             f".from('{table}').update( /* TODO: Verify org filter */ "),
        ]
        
        for pattern, replacement in patterns:
            if re.search(pattern, content):
                report.add_service_update(table, f"Marked for organization filtering")
                updates_count += 1
    
    # For now, we'll add a TODO comment at the top of the file instead of 
    # doing risky automated replacements
    if updates_count > 0 and not dry_run:
        todo_header = '''
// =============================================================================
// TODO: SAAS MIGRATION - Organization Filtering Required
// =============================================================================
// The following tables need organization_id filtering:
// - categorie_menu, menu_items, ingredients, sizes_master
// - ordini, ordini_items, notifiche, cashier_customers
// - delivery_zones, allowed_cities, promotional_banners
// - business_rules, delivery_configuration, order_management
// - kitchen_management, display_branding, dashboard_security
// - ingredient_consumption_rules, inventory_logs, payment_transactions
//
// For each query:
// 1. Add String? organizationId parameter to the method
// 2. Add .eq('organization_id', organizationId) to SELECT queries
// 3. Add 'organization_id': organizationId to INSERT payloads
//
// Example:
//   Future<List<MenuItem>> getMenuItems({String? organizationId}) async {
//     var query = _client.from('menu_items').select();
//     if (organizationId != null) {
//       query = query.eq('organization_id', organizationId);
//     }
//     return query...
//   }
// =============================================================================

'''
        # Check if TODO header already exists
        if 'SAAS MIGRATION' not in content:
            # Find the first import statement and add header before class definition
            class_match = re.search(r'^class DatabaseService', content, re.MULTILINE)
            if class_match:
                content = content[:class_match.start()] + todo_header + content[class_match.start():]
                DATABASE_SERVICE.write_text(content, encoding='utf-8')
                report.add_service_update("DatabaseService", "Added migration TODO header")
    
    return updates_count


def create_organization_provider(report: MigrationReport, dry_run: bool) -> bool:
    """Create a new organization provider file"""
    
    provider_path = LIB_DIR / "providers" / "organization_provider.dart"
    
    if provider_path.exists():
        report.add_warning("organization_provider.dart already exists")
        return False
    
    provider_content = '''import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'organization_provider.g.dart';

/// Current organization ID for multi-tenant queries
/// 
/// TODO: Implement organization selection/switching logic
/// For now, returns the first organization or null
@riverpod
class CurrentOrganization extends _$CurrentOrganization {
  @override
  Future<String?> build() async {
    final client = Supabase.instance.client;
    
    // Get user's current organization from profile
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      final response = await client
          .from('profiles')
          .select('current_organization_id')
          .eq('id', userId)
          .single();
      
      return response['current_organization_id'] as String?;
    } catch (e) {
      // If profile doesn't exist or no org set, try to get first org
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
'''
    
    if dry_run:
        report.add_model_update("organization_provider.dart", "Would create new provider")
        return True
    
    provider_path.write_text(provider_content, encoding='utf-8')
    report.add_model_update("organization_provider.dart", "Created new organization provider")
    return True


def generate_manual_tasks_report() -> str:
    """Generate a list of tasks that need manual attention"""
    
    return '''
================================================================================
MANUAL TASKS REQUIRED AFTER RUNNING THIS SCRIPT
================================================================================

1. RUN BUILD_RUNNER (Required)
   cd to project root and run:
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
   This regenerates all .freezed.dart and .g.dart files.

2. UPDATE DATABASE_SERVICE.DART (High Priority)
   Open lib/core/services/database_service.dart and:
   - Add `String? organizationId` parameter to each method
   - Add `.eq('organization_id', organizationId)` to queries
   - Add `'organization_id': organizationId` to insert payloads
   
   Example transformation:
   BEFORE:
   ```dart
   Future<List<MenuItem>> getMenuItems() async {
     final response = await _client.from('menu_items').select();
     ...
   }
   ```
   
   AFTER:
   ```dart
   Future<List<MenuItem>> getMenuItems({String? organizationId}) async {
     var query = _client.from('menu_items').select();
     if (organizationId != null) {
       query = query.eq('organization_id', organizationId);
     }
     final response = await query;
     ...
   }
   ```

3. UPDATE PROVIDERS (Medium Priority)
   Each provider that calls DatabaseService needs to:
   - Watch `currentOrganizationProvider`
   - Pass organizationId to database methods
   
   Example:
   ```dart
   @riverpod
   Future<List<MenuItem>> menuItems(MenuItemsRef ref) async {
     final orgId = await ref.watch(currentOrganizationProvider.future);
     final db = ref.watch(databaseServiceProvider);
     return db.getMenuItems(organizationId: orgId);
   }
   ```

4. CREATE DEFAULT ORGANIZATION (Required for testing)
   In Supabase SQL Editor, run:
   ```sql
   INSERT INTO organizations (name, slug, email)
   VALUES ('My Pizzeria', 'my-pizzeria', 'info@mypizzeria.com')
   RETURNING id;
   ```
   
   Then set as default for existing data:
   ```sql
   UPDATE profiles SET current_organization_id = 'your-org-id-here';
   UPDATE menu_items SET organization_id = 'your-org-id-here';
   -- Repeat for other tables...
   ```

5. TEST THE APPLICATION
   - Run the app and verify all features work
   - Check that menu items, orders, etc. load correctly
   - Test creating new items (should include organization_id)

================================================================================
'''


def main():
    parser = argparse.ArgumentParser(description='SaaS Migration Script')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying')
    parser.add_argument('--apply', action='store_true', help='Apply changes to codebase')
    parser.add_argument('--report', action='store_true', help='Generate report only')
    parser.add_argument('--skip-backup', action='store_true', help='Skip backup creation')
    
    args = parser.parse_args()
    
    if not any([args.dry_run, args.apply, args.report]):
        parser.print_help()
        print("\n⚠️  Please specify --dry-run, --apply, or --report")
        sys.exit(1)
    
    print("🚀 SaaS Migration Script for Vittoria Ristorazione")
    print("="*60)
    
    # Verify we're in the right directory
    if not LIB_DIR.exists():
        print(f"❌ Error: lib/ directory not found at {LIB_DIR}")
        print("   Make sure you run this script from the project root")
        sys.exit(1)
    
    report = MigrationReport()
    dry_run = args.dry_run or args.report
    
    # Create backup if applying changes
    if args.apply and not args.skip_backup:
        create_backup()
    
    print("\n📝 Phase 1: Updating Models...")
    for model_file in MODEL_FILES_TO_UPDATE:
        model_path = MODELS_DIR / model_file
        add_organization_id_to_model(model_path, report, dry_run)
    
    print("\n🔧 Phase 2: Analyzing DatabaseService...")
    update_database_service(report, dry_run)
    
    print("\n🆕 Phase 3: Creating Organization Provider...")
    create_organization_provider(report, dry_run)
    
    # Print report
    report.print_summary()
    
    # Print manual tasks
    print(generate_manual_tasks_report())
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - No files were modified")
        print("   Run with --apply to make changes")
    else:
        print("\n✅ Migration script completed!")
        print("   Run 'dart run build_runner build --delete-conflicting-outputs'")


if __name__ == '__main__':
    main()
