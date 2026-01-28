-- ===========================================================================
-- MIGRATION 008: ADD NOT NULL CONSTRAINTS TO ORGANIZATION_ID
-- Data Integrity Fix - Prevent cross-tenant data access
-- ===========================================================================
-- Author: Security Fix
-- Date: 2026-01-27
-- Purpose: Enforce tenant isolation by requiring organization_id on all tenant tables
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- SECURITY ISSUE: All 26 tenant tables have nullable organization_id columns
-- This creates potential for:
-- - Cross-tenant data access (NULL data visible to all tenants)
-- - Data integrity violations (orphaned records)
-- - RLS bypass (queries using .is.null pattern)
-- ---------------------------------------------------------------------------

-- NOTE: Current data has been verified - 0 rows with NULL organization_id
-- This makes it safe to add NOT NULL constraints without data migration

-- ---------------------------------------------------------------------------
-- MENU SYSTEM TABLES
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM categorie_menu WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: categorie_menu has NULL organization_id values';
    END IF;
    ALTER TABLE categorie_menu ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to categorie_menu.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM menu_items WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: menu_items has NULL organization_id values';
    END IF;
    ALTER TABLE menu_items ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to menu_items.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ingredients WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: ingredients has NULL organization_id values';
    END IF;
    ALTER TABLE ingredients ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to ingredients.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sizes_master WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: sizes_master has NULL organization_id values';
    END IF;
    ALTER TABLE sizes_master ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to sizes_master.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ingredient_size_prices WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: ingredient_size_prices has NULL organization_id values';
    END IF;
    ALTER TABLE ingredient_size_prices ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to ingredient_size_prices.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM menu_item_sizes WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: menu_item_sizes has NULL organization_id values';
    END IF;
    ALTER TABLE menu_item_sizes ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to menu_item_sizes.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM menu_item_included_ingredients WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: menu_item_included_ingredients has NULL organization_id values';
    END IF;
    ALTER TABLE menu_item_included_ingredients ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to menu_item_included_ingredients.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM menu_item_extra_ingredients WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: menu_item_extra_ingredients has NULL organization_id values';
    END IF;
    ALTER TABLE menu_item_extra_ingredients ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to menu_item_extra_ingredients.organization_id';
END $$;

-- ---------------------------------------------------------------------------
-- ORDERS & DELIVERY TABLES
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ordini WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: ordini has NULL organization_id values';
    END IF;
    ALTER TABLE ordini ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to ordini.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ordini_items WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: ordini_items has NULL organization_id values';
    END IF;
    ALTER TABLE ordini_items ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to ordini_items.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM allowed_cities WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: allowed_cities has NULL organization_id values';
    END IF;
    ALTER TABLE allowed_cities ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to allowed_cities.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM delivery_zones WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: delivery_zones has NULL organization_id values';
    END IF;
    ALTER TABLE delivery_zones ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to delivery_zones.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM user_addresses WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: user_addresses has NULL organization_id values';
    END IF;
    ALTER TABLE user_addresses ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to user_addresses.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cashier_customers WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: cashier_customers has NULL organization_id values';
    END IF;
    ALTER TABLE cashier_customers ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to cashier_customers.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM daily_order_counters WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: daily_order_counters has NULL organization_id values';
    END IF;
    ALTER TABLE daily_order_counters ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to daily_order_counters.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM order_reminders WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: order_reminders has NULL organization_id values';
    END IF;
    ALTER TABLE order_reminders ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to order_reminders.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM notifiche WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: notifiche has NULL organization_id values';
    END IF;
    ALTER TABLE notifiche ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to notifiche.organization_id';
END $$;

-- ---------------------------------------------------------------------------
-- SETTINGS TABLES
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM business_rules WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: business_rules has NULL organization_id values';
    END IF;
    ALTER TABLE business_rules ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to business_rules.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM delivery_configuration WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: delivery_configuration has NULL organization_id values';
    END IF;
    ALTER TABLE delivery_configuration ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to delivery_configuration.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM order_management WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: order_management has NULL organization_id values';
    END IF;
    ALTER TABLE order_management ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to order_management.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM kitchen_management WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: kitchen_management has NULL organization_id values';
    END IF;
    ALTER TABLE kitchen_management ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to kitchen_management.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM display_branding WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: display_branding has NULL organization_id values';
    END IF;
    ALTER TABLE display_branding ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to display_branding.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM dashboard_security WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: dashboard_security has NULL organization_id values';
    END IF;
    ALTER TABLE dashboard_security ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to dashboard_security.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM promotional_banners WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: promotional_banners has NULL organization_id values';
    END IF;
    ALTER TABLE promotional_banners ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to promotional_banners.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ingredient_consumption_rules WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: ingredient_consumption_rules has NULL organization_id values';
    END IF;
    ALTER TABLE ingredient_consumption_rules ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to ingredient_consumption_rules.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM inventory_logs WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: inventory_logs has NULL organization_id values';
    END IF;
    ALTER TABLE inventory_logs ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to inventory_logs.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM payment_transactions WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: payment_transactions has NULL organization_id values';
    END IF;
    ALTER TABLE payment_transactions ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to payment_transactions.organization_id';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM statistiche_giornaliere WHERE organization_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot add NOT NULL: statistiche_giornaliere has NULL organization_id values';
    END IF;
    ALTER TABLE statistiche_giornaliere ALTER COLUMN organization_id SET NOT NULL;
    RAISE NOTICE 'Added NOT NULL to statistiche_giornaliere.organization_id';
END $$;

-- ---------------------------------------------------------------------------
-- EXCEPTION: profiles.current_organization_id remains NULL
-- Users can exist before joining an organization
-- ---------------------------------------------------------------------------

COMMIT;

-- ===========================================================================
-- END MIGRATION 008
-- ===========================================================================
