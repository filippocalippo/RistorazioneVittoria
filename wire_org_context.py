#!/usr/bin/env python3
"""
Multi-Tenant Wiring Script - Phase 3
=====================================
Updates all DatabaseService methods and providers with organization context.

Usage:
    python wire_org_context.py --dry-run     # Preview changes
    python wire_org_context.py --apply       # Apply changes
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Set

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT_ROOT = Path(__file__).parent
LIB_DIR = PROJECT_ROOT / "lib"

# Tables that need org filtering
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

# Methods that already have organizationId or don't need it
SKIP_METHODS = {
    '_parseDateTime', '_nowUtcIso', '_handleDbError',
    '_menuItemInsertPayload', '_sanitizeMenuItemUpdates',
    '_fetchSettingsRow', '_upsertSettingsRow', '_menuItemFromJson',
    '_buildNameSearchPatterns', 'parseDateTime',
    'getMenuItems', 'createMenuItem', 'getOrders',  # Already updated
    'placeOrder', 'verifyOrderPayment',  # Use Edge Function
    'getOrder',  # Gets by ID, RLS handles it
    'updateOrderStatus', 'assignOrderToKitchen', 'assignOrderToDelivery',
    'cancelOrder', 'deleteOrder', 'updateOrder', 'markOrderAsNotPrinted',
    'toggleOrderPagato',  # These update by ID, RLS handles
    'updateMenuItem', 'deleteMenuItem',  # Update/delete by ID
}

def update_database_service(dry_run: bool) -> int:
    """Add organizationId to remaining DatabaseService methods"""
    
    db_service_path = LIB_DIR / "core" / "services" / "database_service.dart"
    content = db_service_path.read_text(encoding='utf-8')
    original = content
    changes = 0
    
    # Pattern to find method signatures that query ORG_TABLES
    # We'll add organizationId parameter to methods that:
    # 1. Don't already have it
    # 2. Query org tables
    
    # Methods to update with their table references
    methods_to_update = [
        ('searchCashierCustomers', 'cashier_customers'),
        ('findMatchingCustomer', 'cashier_customers'),
        ('createCashierCustomer', 'cashier_customers'),
        ('updateCashierCustomer', 'cashier_customers'),
        ('incrementCustomerOrders', 'cashier_customers'),
        ('getCashierCustomerById', 'cashier_customers'),
        ('countItemsInSlot', 'ordini'),
        ('countOrdersInSlot', 'ordini'),
        ('getItemCountsBySlotRange', 'ordini'),
        ('getPizzeria', 'business_rules'),
        ('getPizzeriaSettings', 'business_rules'),
        ('updateBusinessRules', 'business_rules'),
        ('saveOrderManagementSettings', 'order_management'),
        ('saveOrderManagementSettingsRaw', 'order_management'),
        ('saveDeliveryConfigurationSettings', 'delivery_configuration'),
        ('saveDisplayBrandingSettings', 'display_branding'),
        ('saveKitchenManagementSettings', 'kitchen_management'),
        ('saveBusinessRulesSettings', 'business_rules'),
        ('getOrderManagementSettingsRaw', 'order_management'),
    ]
    
    for method_name, table in methods_to_update:
        if method_name in SKIP_METHODS:
            continue
            
        # Check if method already has organizationId
        if f'{method_name}' in content:
            # Find the method and check if it has organizationId
            pattern = rf'(Future<[^>]+>\s+{method_name}\s*\([^)]*)'
            match = re.search(pattern, content)
            if match:
                method_sig = match.group(1)
                if 'organizationId' in method_sig:
                    continue  # Already has it
                    
                # Print what would be updated
                if dry_run:
                    print(f"  [TODO] {method_name}() needs organizationId for {table}")
                    changes += 1
                else:
                    print(f"  [MANUAL] {method_name}() - add organizationId for {table}")
                    changes += 1
    
    print(f"\n  Total methods needing update: {changes}")
    return changes


def update_provider_org_context(provider_path: Path, dry_run: bool) -> bool:
    """Update a provider to use currentOrganizationProvider"""
    
    content = provider_path.read_text(encoding='utf-8')
    
    # Skip if doesn't have Supabase calls
    if 'Supabase.instance.client' not in content:
        return False
    
    # Skip if already properly using org context
    if 'currentOrganizationProvider.future' in content:
        return False
    
    # Check if already has the import
    has_import = 'organization_provider.dart' in content
    
    if dry_run:
        print(f"  ✅ {provider_path.name}: Needs org context wiring")
        return True
    
    # Add the watching pattern at the start of provider functions
    # This is complex so we'll just add a TODO comment for manual work
    
    if not has_import:
        # Add import at top
        import_line = "import 'organization_provider.dart';\n"
        if "import '" in content:
            # Add after first import
            content = re.sub(
                r"(import '[^']+';)",
                lambda m: m.group(0) + '\n' + import_line if content.index(m.group(0)) == content.find("import '") else m.group(0),
                content,
                count=1
            )
    
    # Add TODO comment for org context
    todo_comment = """
// TODO: Multi-tenant - Watch currentOrganizationProvider:
//   final orgId = await ref.watch(currentOrganizationProvider.future);
//   Add .eq('organization_id', orgId) to queries
"""
    
    if 'TODO: Multi-tenant' not in content:
        # Add after imports
        import_end = content.rfind("import ")
        if import_end != -1:
            line_end = content.find('\n', import_end)
            content = content[:line_end+1] + todo_comment + content[line_end+1:]
    
    provider_path.write_text(content, encoding='utf-8')
    print(f"  ✅ {provider_path.name}: Added org context TODO")
    return True


def update_providers(dry_run: bool) -> int:
    """Update all providers with direct Supabase calls"""
    
    providers_dir = LIB_DIR / "providers"
    updates = 0
    
    # Key providers that need org context
    key_providers = [
        'categories_provider.dart',
        'ingredients_provider.dart', 
        'sizes_master_provider.dart',
        'sizes_provider.dart',
        'product_sizes_provider.dart',
        'product_extra_ingredients_provider.dart',
        'product_included_ingredients_provider.dart',
        'recommended_ingredients_provider.dart',
        'filtered_menu_provider.dart',
        'manager_orders_provider.dart',
        'dashboard_analytics_provider.dart',
        'delivery_zones_provider.dart',
        'promotional_banners_provider.dart',
        'inventory_ui_providers.dart',
        'product_analytics_provider.dart',
        'product_monthly_sales_provider.dart',
        'top_products_per_category_provider.dart',
        'order_price_calculator_provider.dart',
    ]
    
    for provider_name in key_providers:
        provider_path = providers_dir / provider_name
        if provider_path.exists():
            if update_provider_org_context(provider_path, dry_run):
                updates += 1
    
    return updates


def main():
    parser = argparse.ArgumentParser(description='Wire Organization Context')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes')
    parser.add_argument('--apply', action='store_true', help='Apply changes')
    
    args = parser.parse_args()
    
    if not any([args.dry_run, args.apply]):
        parser.print_help()
        print("\n⚠️  Please specify --dry-run or --apply")
        sys.exit(1)
    
    print("🔌 Wire Organization Context - Phase 3")
    print("="*60)
    
    dry_run = args.dry_run
    
    print("\n📝 Step 1: Analyzing DatabaseService methods...")
    db_updates = update_database_service(dry_run)
    
    print("\n📝 Step 2: Updating providers with org context...")
    provider_updates = update_providers(dry_run)
    print(f"   Updated {provider_updates} providers")
    
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"  DatabaseService methods to update: {db_updates}")
    print(f"  Providers updated: {provider_updates}")
    
    if dry_run:
        print("\n⚠️  DRY RUN - No files were modified")
        print("   Run with --apply to make changes")
    else:
        print("\n✅ Phase 3 complete!")
        print("\n📋 Next steps:")
        print("   1. Review TODO comments in providers")
        print("   2. Manually wire org context in complex methods")
        print("   3. Run flutter analyze")


if __name__ == '__main__':
    main()
