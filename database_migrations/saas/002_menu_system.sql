-- ===========================================================================
-- MIGRATION 002: MENU SYSTEM
-- Creates all menu-related tables with org-awareness
-- ===========================================================================
-- Author: AI Assistant
-- Date: 2026-01-24
-- Purpose: Menu categories, items, ingredients, sizes, and relations
-- Compatibility: Identical columns to current schema + nullable organization_id
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. CATEGORIE_MENU (Menu Categories)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.categorie_menu (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,    -- NEW: Multi-tenant
    nome TEXT NOT NULL,
    descrizione TEXT,
    icona TEXT,                                                              -- Icon name/code
    icona_url TEXT,                                                          -- Icon image URL
    colore TEXT,                                                             -- Category color
    ordine INTEGER DEFAULT 0,
    attiva BOOLEAN DEFAULT true,
    permetti_divisioni BOOLEAN DEFAULT false,                                -- Allow pizza halves
    
    -- Scheduled deactivation
    disattivazione_programmata BOOLEAN DEFAULT false,
    orario_disattivazione TIME,
    giorni_disattivazione INTEGER[],                                         -- Array of weekdays (0=Sun, 6=Sat)
    data_disattivazione_da DATE,
    data_disattivazione_a DATE,
    ultimo_controllo_disattivazione TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_categorie_menu_org ON categorie_menu(organization_id);
CREATE INDEX IF NOT EXISTS idx_categorie_menu_ordine ON categorie_menu(ordine);
CREATE INDEX IF NOT EXISTS idx_categorie_menu_attiva ON categorie_menu(attiva) WHERE attiva = true;

-- ---------------------------------------------------------------------------
-- 2. SIZES_MASTER (Product Sizes - e.g., Small, Medium, Large for pizza)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sizes_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    descrizione TEXT,
    slug TEXT UNIQUE NOT NULL,                                               -- e.g., "media", "grande"
    permetti_divisioni BOOLEAN DEFAULT false,
    ordine INTEGER DEFAULT 0,
    attivo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sizes_master_org ON sizes_master(organization_id);
CREATE INDEX IF NOT EXISTS idx_sizes_master_attivo ON sizes_master(attivo) WHERE attivo = true;

-- ---------------------------------------------------------------------------
-- 3. INGREDIENTS (Toppings and add-ons)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    descrizione TEXT,
    prezzo NUMERIC(10,2) DEFAULT 0,                                          -- Base price
    attivo BOOLEAN DEFAULT true,
    ordine INTEGER DEFAULT 0,

    -- Inventory fields
    stock_quantity NUMERIC DEFAULT 0,
    unit_of_measure TEXT DEFAULT 'unit',                                     -- unit, kg, g, l, ml
    low_stock_threshold NUMERIC DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ingredients_org ON ingredients(organization_id);
CREATE INDEX IF NOT EXISTS idx_ingredients_attivo ON ingredients(attivo) WHERE attivo = true;
CREATE INDEX IF NOT EXISTS idx_ingredients_nome ON ingredients(nome);

-- ---------------------------------------------------------------------------
-- 4. INGREDIENT_SIZE_PRICES (Price per ingredient per size)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ingredient_size_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    size_id UUID NOT NULL REFERENCES sizes_master(id) ON DELETE CASCADE,
    price NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(ingredient_id, size_id)
);

CREATE INDEX IF NOT EXISTS idx_ingredient_size_prices_org ON ingredient_size_prices(organization_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_size_prices_ingredient ON ingredient_size_prices(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_size_prices_size ON ingredient_size_prices(size_id);

-- ---------------------------------------------------------------------------
-- 5. MENU_ITEMS (Products)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    categoria_id UUID REFERENCES categorie_menu(id) ON DELETE SET NULL,
    nome TEXT NOT NULL,
    descrizione TEXT,
    prezzo NUMERIC(10,2) NOT NULL DEFAULT 0,                                 -- Base price
    immagine_url TEXT,
    ordine INTEGER DEFAULT 0,
    attivo BOOLEAN DEFAULT true,
    
    -- Flags
    disponibile BOOLEAN DEFAULT true,                                        -- In stock
    novita BOOLEAN DEFAULT false,                                            -- New item badge
    in_evidenza BOOLEAN DEFAULT false,                                       -- Featured item
    permetti_divisioni BOOLEAN DEFAULT false,                                -- Allow pizza halves
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_menu_items_org ON menu_items(organization_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_categoria ON menu_items(categoria_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_attivo ON menu_items(attivo) WHERE attivo = true;
CREATE INDEX IF NOT EXISTS idx_menu_items_ordine ON menu_items(ordine);

-- ---------------------------------------------------------------------------
-- 6. MENU_ITEM_SIZES (Junction: menu_items ↔ sizes_master)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.menu_item_sizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    size_id UUID NOT NULL REFERENCES sizes_master(id) ON DELETE CASCADE,
    prezzo NUMERIC(10,2) NOT NULL DEFAULT 0,                                 -- Price for this size
    attivo BOOLEAN DEFAULT true,
    ordine INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(menu_item_id, size_id)
);

CREATE INDEX IF NOT EXISTS idx_menu_item_sizes_org ON menu_item_sizes(organization_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_sizes_item ON menu_item_sizes(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_sizes_size ON menu_item_sizes(size_id);

-- ---------------------------------------------------------------------------
-- 7. MENU_ITEM_INCLUDED_INGREDIENTS (Default ingredients on item)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.menu_item_included_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    ordine INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(menu_item_id, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_menu_item_included_ingredients_org ON menu_item_included_ingredients(organization_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_included_ingredients_item ON menu_item_included_ingredients(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_included_ingredients_ingredient ON menu_item_included_ingredients(ingredient_id);

-- ---------------------------------------------------------------------------
-- 8. MENU_ITEM_EXTRA_INGREDIENTS (Available extras for item)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.menu_item_extra_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    ordine INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(menu_item_id, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_menu_item_extra_ingredients_org ON menu_item_extra_ingredients(organization_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_extra_ingredients_item ON menu_item_extra_ingredients(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_extra_ingredients_ingredient ON menu_item_extra_ingredients(ingredient_id);

-- ---------------------------------------------------------------------------
-- 9. TRIGGERS FOR UPDATED_AT
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS update_categorie_menu_updated_at ON categorie_menu;
CREATE TRIGGER update_categorie_menu_updated_at
    BEFORE UPDATE ON categorie_menu
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sizes_master_updated_at ON sizes_master;
CREATE TRIGGER update_sizes_master_updated_at
    BEFORE UPDATE ON sizes_master
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ingredients_updated_at ON ingredients;
CREATE TRIGGER update_ingredients_updated_at
    BEFORE UPDATE ON ingredients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_menu_items_updated_at ON menu_items;
CREATE TRIGGER update_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- 10. ENABLE RLS
-- ---------------------------------------------------------------------------

ALTER TABLE categorie_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE sizes_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_size_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_sizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_included_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_extra_ingredients ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 11. RLS POLICIES
-- ---------------------------------------------------------------------------

-- === CATEGORIE_MENU ===
DROP POLICY IF EXISTS "Anyone can view active categories" ON categorie_menu;
CREATE POLICY "Anyone can view active categories" ON categorie_menu
    FOR SELECT TO authenticated
    USING (attiva = true OR is_manager());

DROP POLICY IF EXISTS "Managers can manage categories" ON categorie_menu;
CREATE POLICY "Managers can manage categories" ON categorie_menu
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === SIZES_MASTER ===
DROP POLICY IF EXISTS "Anyone can view active sizes" ON sizes_master;
CREATE POLICY "Anyone can view active sizes" ON sizes_master
    FOR SELECT TO anon, authenticated
    USING (attivo = true OR is_manager());

DROP POLICY IF EXISTS "Managers can manage sizes" ON sizes_master;
CREATE POLICY "Managers can manage sizes" ON sizes_master
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === INGREDIENTS ===
DROP POLICY IF EXISTS "Anyone can view active ingredients" ON ingredients;
CREATE POLICY "Anyone can view active ingredients" ON ingredients
    FOR SELECT TO authenticated
    USING (attivo = true OR is_manager());

DROP POLICY IF EXISTS "Managers can manage ingredients" ON ingredients;
CREATE POLICY "Managers can manage ingredients" ON ingredients
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === INGREDIENT_SIZE_PRICES ===
DROP POLICY IF EXISTS "Anyone can view ingredient prices" ON ingredient_size_prices;
CREATE POLICY "Anyone can view ingredient prices" ON ingredient_size_prices
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Managers can manage ingredient prices" ON ingredient_size_prices;
CREATE POLICY "Managers can manage ingredient prices" ON ingredient_size_prices
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === MENU_ITEMS ===
DROP POLICY IF EXISTS "Anyone can view active menu items" ON menu_items;
CREATE POLICY "Anyone can view active menu items" ON menu_items
    FOR SELECT TO authenticated
    USING (attivo = true OR is_manager());

DROP POLICY IF EXISTS "Managers can manage menu items" ON menu_items;
CREATE POLICY "Managers can manage menu items" ON menu_items
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === MENU_ITEM_SIZES ===
DROP POLICY IF EXISTS "Anyone can view menu item sizes" ON menu_item_sizes;
CREATE POLICY "Anyone can view menu item sizes" ON menu_item_sizes
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Managers can manage menu item sizes" ON menu_item_sizes;
CREATE POLICY "Managers can manage menu item sizes" ON menu_item_sizes
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === MENU_ITEM_INCLUDED_INGREDIENTS ===
DROP POLICY IF EXISTS "Anyone can view included ingredients" ON menu_item_included_ingredients;
CREATE POLICY "Anyone can view included ingredients" ON menu_item_included_ingredients
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Managers can manage included ingredients" ON menu_item_included_ingredients;
CREATE POLICY "Managers can manage included ingredients" ON menu_item_included_ingredients
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === MENU_ITEM_EXTRA_INGREDIENTS ===
DROP POLICY IF EXISTS "Anyone can view extra ingredients" ON menu_item_extra_ingredients;
CREATE POLICY "Anyone can view extra ingredients" ON menu_item_extra_ingredients
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Managers can manage extra ingredients" ON menu_item_extra_ingredients;
CREATE POLICY "Managers can manage extra ingredients" ON menu_item_extra_ingredients
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- ---------------------------------------------------------------------------
-- 12. HELPER FUNCTION: Get ingredient price for a size
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_ingredient_price(p_ingredient_id UUID, p_size_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_price NUMERIC;
BEGIN
    -- First try to get size-specific price
    SELECT price INTO v_price
    FROM ingredient_size_prices
    WHERE ingredient_id = p_ingredient_id AND size_id = p_size_id;
    
    -- If not found, get base price
    IF v_price IS NULL THEN
        SELECT prezzo INTO v_price
        FROM ingredients
        WHERE id = p_ingredient_id;
    END IF;
    
    RETURN COALESCE(v_price, 0);
END;
$$;

-- ---------------------------------------------------------------------------
-- 13. FUNCTION: Get recommended ingredients for a menu item
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_recommended_ingredients(p_menu_item_id UUID, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
    ingredient_id UUID,
    ingredient_name TEXT,
    times_used BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Get ingredients commonly added to this item in past orders
    RETURN QUERY
    SELECT 
        i.id,
        i.nome,
        COUNT(*) AS times_used
    FROM ordini_items oi
    CROSS JOIN LATERAL jsonb_array_elements(oi.extras_added) AS ea
    JOIN ingredients i ON i.id = (ea->>'id')::UUID
    WHERE oi.menu_item_id = p_menu_item_id
    AND i.attivo = true
    GROUP BY i.id, i.nome
    ORDER BY times_used DESC
    LIMIT p_limit;
END;
$$;

-- ---------------------------------------------------------------------------
-- 14. FUNCTION: Check and deactivate scheduled categories
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_and_deactivate_categories()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE categorie_menu
    SET attiva = false,
        ultimo_controllo_disattivazione = now()
    WHERE disattivazione_programmata = true
    AND attiva = true
    AND (
        -- Time-based deactivation
        (orario_disattivazione IS NOT NULL 
         AND EXTRACT(DOW FROM now()) = ANY(giorni_disattivazione)
         AND now()::time > orario_disattivazione)
        OR
        -- Date range deactivation
        (data_disattivazione_da IS NOT NULL 
         AND data_disattivazione_a IS NOT NULL
         AND CURRENT_DATE BETWEEN data_disattivazione_da AND data_disattivazione_a)
    );
END;
$$;

-- ---------------------------------------------------------------------------
-- 15. FUNCTION: Reactivate categories
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reactivate_categories()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE categorie_menu
    SET attiva = true
    WHERE disattivazione_programmata = true
    AND attiva = false
    AND (
        (data_disattivazione_a IS NOT NULL AND CURRENT_DATE > data_disattivazione_a)
        OR
        (orario_disattivazione IS NOT NULL 
         AND NOT (EXTRACT(DOW FROM now()) = ANY(giorni_disattivazione)))
    );
END;
$$;

COMMIT;

-- ===========================================================================
-- END MIGRATION 002
-- ===========================================================================
