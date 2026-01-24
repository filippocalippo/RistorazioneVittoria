-- ===========================================================================
-- MIGRATION 003: ORDERS & DELIVERY SYSTEM
-- Creates all order, delivery, and notification tables
-- ===========================================================================
-- Author: AI Assistant
-- Date: 2026-01-24
-- Purpose: Orders, delivery zones, customers, notifications
-- Compatibility: Identical columns to current schema + nullable organization_id
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. ALLOWED_CITIES (Cities where delivery is available)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.allowed_cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    cap TEXT NOT NULL,
    attiva BOOLEAN DEFAULT true,
    ordine INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(nome, cap)
);

CREATE INDEX IF NOT EXISTS idx_allowed_cities_org ON allowed_cities(organization_id);
CREATE INDEX IF NOT EXISTS idx_allowed_cities_attiva ON allowed_cities(attiva) WHERE attiva = true;

-- ---------------------------------------------------------------------------
-- 2. DELIVERY_ZONES (Zone-based delivery fees)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.delivery_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'zone' CHECK (tipo IN ('zone', 'radius')),
    
    -- Zone-based settings
    cities TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Radius-based settings
    radius_km NUMERIC,
    center_lat NUMERIC,
    center_lng NUMERIC,
    
    -- Pricing
    costo_consegna NUMERIC(10,2) DEFAULT 0,
    ordine_minimo NUMERIC(10,2) DEFAULT 0,
    consegna_gratuita_sopra NUMERIC(10,2),
    
    -- Availability
    attiva BOOLEAN DEFAULT true,
    ordine INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_zones_org ON delivery_zones(organization_id);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_attiva ON delivery_zones(attiva) WHERE attiva = true;

-- ---------------------------------------------------------------------------
-- 3. USER_ADDRESSES (Customer saved addresses)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    allowed_city_id UUID REFERENCES allowed_cities(id) ON DELETE SET NULL,
    etichetta TEXT,                                                          -- "Home", "Work", etc.
    indirizzo TEXT NOT NULL,
    citta TEXT NOT NULL,
    cap TEXT NOT NULL,
    note TEXT,
    is_default BOOLEAN DEFAULT false,
    latitude NUMERIC,
    longitude NUMERIC,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON user_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_addresses_city ON user_addresses(allowed_city_id);

-- ---------------------------------------------------------------------------
-- 4. CASHIER_CUSTOMERS (Walk-in customers for POS)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cashier_customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    telefono TEXT,
    indirizzo TEXT,
    citta TEXT,
    cap TEXT,
    note TEXT,
    
    -- Normalized fields for search
    nome_normalized TEXT,
    telefono_normalized TEXT,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cashier_customers_org ON cashier_customers(organization_id);
CREATE INDEX IF NOT EXISTS idx_cashier_customers_nome ON cashier_customers(nome_normalized text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_cashier_customers_telefono ON cashier_customers(telefono_normalized);
CREATE INDEX IF NOT EXISTS idx_cashier_customers_search ON cashier_customers(nome_normalized, telefono_normalized);

-- ---------------------------------------------------------------------------
-- 5. DAILY_ORDER_COUNTERS (Sequential order numbers per day)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.daily_order_counters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    data DATE NOT NULL,
    counter INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(organization_id, data)
);

CREATE INDEX IF NOT EXISTS idx_daily_order_counters_org_data ON daily_order_counters(organization_id, data);

-- ---------------------------------------------------------------------------
-- 6. ORDINI (Orders - main order table)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ordini (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Customer info
    cliente_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    cashier_customer_id UUID REFERENCES cashier_customers(id) ON DELETE SET NULL,
    
    -- Order identification
    numero_ordine TEXT,                                                      -- e.g., "20260124-001"
    
    -- Type and status
    tipo TEXT NOT NULL CHECK (tipo IN ('delivery', 'takeaway', 'locale', 'counter')),
    stato TEXT NOT NULL DEFAULT 'pending' CHECK (stato IN ('pending', 'confirmed', 'preparing', 'ready', 'delivering', 'delivered', 'completed', 'cancelled')),
    
    -- Delivery info
    indirizzo_consegna TEXT,
    citta_consegna TEXT,
    cap_consegna TEXT,
    note_consegna TEXT,
    latitude_consegna NUMERIC,
    longitude_consegna NUMERIC,
    
    -- Scheduling
    data_richiesta DATE,
    orario_richiesto TIME,
    orario_consegna_stimato TIMESTAMPTZ,
    
    -- Pricing
    subtotale NUMERIC(10,2) NOT NULL DEFAULT 0,
    costo_consegna NUMERIC(10,2) DEFAULT 0,
    sconto NUMERIC(10,2) DEFAULT 0,
    totale NUMERIC(10,2) NOT NULL DEFAULT 0,
    
    -- Payment
    metodo_pagamento TEXT CHECK (metodo_pagamento IN ('cash', 'card', 'online', 'pos')),
    pagato BOOLEAN DEFAULT false,
    
    -- Assignment
    assegnato_cucina_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    assegnato_delivery_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Print tracking
    printed BOOLEAN DEFAULT false,
    printed_at TIMESTAMPTZ,
    is_cancelled_printed BOOLEAN DEFAULT false,
    
    -- Metadata
    note TEXT,
    source TEXT DEFAULT 'app' CHECK (source IN ('app', 'web', 'pos', 'phone')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_ordini_org ON ordini(organization_id);
CREATE INDEX IF NOT EXISTS idx_ordini_cliente ON ordini(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ordini_cashier_customer ON ordini(cashier_customer_id);
CREATE INDEX IF NOT EXISTS idx_ordini_stato ON ordini(stato);
CREATE INDEX IF NOT EXISTS idx_ordini_tipo ON ordini(tipo);
CREATE INDEX IF NOT EXISTS idx_ordini_data_richiesta ON ordini(data_richiesta);
CREATE INDEX IF NOT EXISTS idx_ordini_created_at ON ordini(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ordini_numero ON ordini(numero_ordine);
CREATE INDEX IF NOT EXISTS idx_ordini_assegnato_cucina ON ordini(assegnato_cucina_id);
CREATE INDEX IF NOT EXISTS idx_ordini_assegnato_delivery ON ordini(assegnato_delivery_id);
CREATE INDEX IF NOT EXISTS idx_ordini_printed ON ordini(printed) WHERE printed = false;

-- ---------------------------------------------------------------------------
-- 7. ORDINI_ITEMS (Order line items)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ordini_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    ordine_id UUID NOT NULL REFERENCES ordini(id) ON DELETE CASCADE,
    menu_item_id UUID REFERENCES menu_items(id) ON DELETE SET NULL,
    
    -- Snapshot at order time (in case menu changes)
    nome_prodotto TEXT NOT NULL,
    prezzo_unitario NUMERIC(10,2) NOT NULL,
    
    -- Size selection
    size_id UUID REFERENCES sizes_master(id) ON DELETE SET NULL,
    size_nome TEXT,
    
    -- Quantity
    quantita INTEGER NOT NULL DEFAULT 1,
    
    -- Customizations (JSONB for flexibility)
    ingredients_removed JSONB DEFAULT '[]'::jsonb,                           -- [{id, nome}]
    extras_added JSONB DEFAULT '[]'::jsonb,                                  -- [{id, nome, prezzo, quantita}]
    
    -- Pizza halves (for divisioni)
    mezzo_sinistro_id UUID REFERENCES menu_items(id) ON DELETE SET NULL,
    mezzo_sinistro_nome TEXT,
    mezzo_destro_id UUID REFERENCES menu_items(id) ON DELETE SET NULL,
    mezzo_destro_nome TEXT,
    
    -- Line totals
    prezzo_extras NUMERIC(10,2) DEFAULT 0,
    prezzo_totale NUMERIC(10,2) NOT NULL,
    
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ordini_items_org ON ordini_items(organization_id);
CREATE INDEX IF NOT EXISTS idx_ordini_items_ordine ON ordini_items(ordine_id);
CREATE INDEX IF NOT EXISTS idx_ordini_items_menu_item ON ordini_items(menu_item_id);

-- ---------------------------------------------------------------------------
-- 8. ORDER_REMINDERS (Scheduled order notifications)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.order_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    ordine_id UUID NOT NULL REFERENCES ordini(id) ON DELETE CASCADE,
    reminder_time TIMESTAMPTZ NOT NULL,
    sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_reminders_org ON order_reminders(organization_id);
CREATE INDEX IF NOT EXISTS idx_order_reminders_ordine ON order_reminders(ordine_id);
CREATE INDEX IF NOT EXISTS idx_order_reminders_pending ON order_reminders(reminder_time, sent) WHERE sent = false;

-- ---------------------------------------------------------------------------
-- 9. NOTIFICHE (Push notifications log)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notifiche (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    ordine_id UUID REFERENCES ordini(id) ON DELETE SET NULL,
    
    titolo TEXT NOT NULL,
    messaggio TEXT NOT NULL,
    tipo TEXT DEFAULT 'order' CHECK (tipo IN ('order', 'promo', 'system', 'reminder')),
    
    -- Delivery status
    letto BOOLEAN DEFAULT false,
    letto_at TIMESTAMPTZ,
    push_sent BOOLEAN DEFAULT false,
    push_sent_at TIMESTAMPTZ,
    
    -- Metadata
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifiche_org ON notifiche(organization_id);
CREATE INDEX IF NOT EXISTS idx_notifiche_user ON notifiche(user_id);
CREATE INDEX IF NOT EXISTS idx_notifiche_ordine ON notifiche(ordine_id);
CREATE INDEX IF NOT EXISTS idx_notifiche_unread ON notifiche(user_id, letto) WHERE letto = false;
CREATE INDEX IF NOT EXISTS idx_notifiche_created ON notifiche(created_at DESC);

-- ---------------------------------------------------------------------------
-- 10. TRIGGERS
-- ---------------------------------------------------------------------------

-- Updated_at triggers
DROP TRIGGER IF EXISTS update_allowed_cities_updated_at ON allowed_cities;
CREATE TRIGGER update_allowed_cities_updated_at
    BEFORE UPDATE ON allowed_cities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_delivery_zones_updated_at ON delivery_zones;
CREATE TRIGGER update_delivery_zones_updated_at
    BEFORE UPDATE ON delivery_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_addresses_updated_at ON user_addresses;
CREATE TRIGGER update_user_addresses_updated_at
    BEFORE UPDATE ON user_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cashier_customers_updated_at ON cashier_customers;
CREATE TRIGGER update_cashier_customers_updated_at
    BEFORE UPDATE ON cashier_customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ordini_updated_at ON ordini;
CREATE TRIGGER update_ordini_updated_at
    BEFORE UPDATE ON ordini
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- 11. PHONE NORMALIZATION TRIGGER FOR CASHIER_CUSTOMERS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION normalize_phone(phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF phone IS NULL THEN RETURN NULL; END IF;
    -- Remove all non-digit characters
    RETURN regexp_replace(phone, '[^0-9]', '', 'g');
END;
$$;

CREATE OR REPLACE FUNCTION update_cashier_customer_normalized()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.nome_normalized := lower(trim(NEW.nome));
    NEW.telefono_normalized := normalize_phone(NEW.telefono);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS normalize_cashier_customer ON cashier_customers;
CREATE TRIGGER normalize_cashier_customer
    BEFORE INSERT OR UPDATE ON cashier_customers
    FOR EACH ROW EXECUTE FUNCTION update_cashier_customer_normalized();

-- ---------------------------------------------------------------------------
-- 12. SINGLE DEFAULT ADDRESS TRIGGER
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ensure_single_default_address()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.is_default = true THEN
        UPDATE user_addresses
        SET is_default = false
        WHERE user_id = NEW.user_id
        AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_single_default ON user_addresses;
CREATE TRIGGER ensure_single_default
    BEFORE INSERT OR UPDATE ON user_addresses
    FOR EACH ROW EXECUTE FUNCTION ensure_single_default_address();

-- ---------------------------------------------------------------------------
-- 13. ORDER NUMBER GENERATION
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION generate_numero_ordine_v2(p_org_id UUID DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_date DATE;
    v_counter INTEGER;
    v_numero TEXT;
BEGIN
    v_date := CURRENT_DATE;
    
    -- Get and increment counter atomically
    INSERT INTO daily_order_counters (organization_id, data, counter)
    VALUES (p_org_id, v_date, 1)
    ON CONFLICT (organization_id, data) 
    DO UPDATE SET counter = daily_order_counters.counter + 1
    RETURNING counter INTO v_counter;
    
    -- Format: YYYYMMDD-XXX
    v_numero := to_char(v_date, 'YYYYMMDD') || '-' || lpad(v_counter::TEXT, 3, '0');
    
    RETURN v_numero;
END;
$$;

CREATE OR REPLACE FUNCTION assign_order_number_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.numero_ordine IS NULL THEN
        NEW.numero_ordine := generate_numero_ordine_v2(NEW.organization_id);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS assign_order_number ON ordini;
CREATE TRIGGER assign_order_number
    BEFORE INSERT ON ordini
    FOR EACH ROW EXECUTE FUNCTION assign_order_number_trigger();

-- ---------------------------------------------------------------------------
-- 14. ORDER STATUS CHANGE NOTIFICATION
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_title TEXT;
    v_message TEXT;
BEGIN
    -- Only trigger on status change
    IF OLD.stato = NEW.stato THEN
        RETURN NEW;
    END IF;
    
    -- Only notify customer (not staff)
    IF NEW.cliente_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Build notification message based on new status
    CASE NEW.stato
        WHEN 'confirmed' THEN
            v_title := 'Ordine Confermato';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è stato confermato!';
        WHEN 'preparing' THEN
            v_title := 'In Preparazione';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è in preparazione.';
        WHEN 'ready' THEN
            v_title := 'Ordine Pronto';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è pronto!';
        WHEN 'delivering' THEN
            v_title := 'In Consegna';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è in consegna!';
        WHEN 'delivered' THEN
            v_title := 'Consegnato';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è stato consegnato!';
        WHEN 'completed' THEN
            v_title := 'Completato';
            v_message := 'Grazie per il tuo ordine #' || NEW.numero_ordine || '!';
        WHEN 'cancelled' THEN
            v_title := 'Ordine Annullato';
            v_message := 'Il tuo ordine #' || NEW.numero_ordine || ' è stato annullato.';
        ELSE
            RETURN NEW;
    END CASE;
    
    -- Create notification
    INSERT INTO notifiche (organization_id, user_id, ordine_id, titolo, messaggio, tipo)
    VALUES (NEW.organization_id, NEW.cliente_id, NEW.id, v_title, v_message, 'order');
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS order_status_notification ON ordini;
CREATE TRIGGER order_status_notification
    AFTER UPDATE ON ordini
    FOR EACH ROW EXECUTE FUNCTION notify_order_status_change();

-- ---------------------------------------------------------------------------
-- 15. CANCEL OWN ORDER FUNCTION
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cancel_own_order(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT * INTO v_order FROM ordini WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;
    
    -- Check ownership
    IF v_order.cliente_id != auth.uid() THEN
        RAISE EXCEPTION 'Not your order';
    END IF;
    
    -- Can only cancel pending orders
    IF v_order.stato != 'pending' THEN
        RAISE EXCEPTION 'Order cannot be cancelled in current state';
    END IF;
    
    UPDATE ordini SET stato = 'cancelled' WHERE id = p_order_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 16. GET TOP PRODUCTS BY CATEGORY
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_top_products_by_category(
    p_org_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    category_id UUID,
    category_name TEXT,
    product_id UUID,
    product_name TEXT,
    order_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH ranked AS (
        SELECT 
            c.id AS cat_id,
            c.nome AS cat_name,
            m.id AS prod_id,
            m.nome AS prod_name,
            COUNT(*) AS cnt,
            ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY COUNT(*) DESC) AS rn
        FROM ordini_items oi
        JOIN menu_items m ON oi.menu_item_id = m.id
        JOIN categorie_menu c ON m.categoria_id = c.id
        JOIN ordini o ON oi.ordine_id = o.id
        WHERE (p_org_id IS NULL OR o.organization_id = p_org_id)
        AND o.stato NOT IN ('cancelled')
        GROUP BY c.id, c.nome, m.id, m.nome
    )
    SELECT cat_id, cat_name, prod_id, prod_name, cnt
    FROM ranked
    WHERE rn <= p_limit
    ORDER BY cat_name, cnt DESC;
END;
$$;

-- ---------------------------------------------------------------------------
-- 17. ENABLE RLS
-- ---------------------------------------------------------------------------

ALTER TABLE allowed_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE cashier_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_order_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE ordini ENABLE ROW LEVEL SECURITY;
ALTER TABLE ordini_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifiche ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 18. RLS POLICIES
-- ---------------------------------------------------------------------------

-- === ALLOWED_CITIES ===
DROP POLICY IF EXISTS "Anyone can view active cities" ON allowed_cities;
CREATE POLICY "Anyone can view active cities" ON allowed_cities
    FOR SELECT TO authenticated
    USING (attiva = true OR is_staff());

DROP POLICY IF EXISTS "Managers can manage cities" ON allowed_cities;
CREATE POLICY "Managers can manage cities" ON allowed_cities
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === DELIVERY_ZONES ===
DROP POLICY IF EXISTS "Anyone can view active zones" ON delivery_zones;
CREATE POLICY "Anyone can view active zones" ON delivery_zones
    FOR SELECT TO authenticated
    USING (attiva = true OR is_staff());

DROP POLICY IF EXISTS "Managers can manage zones" ON delivery_zones;
CREATE POLICY "Managers can manage zones" ON delivery_zones
    FOR ALL TO authenticated
    USING (is_manager())
    WITH CHECK (is_manager());

-- === USER_ADDRESSES ===
DROP POLICY IF EXISTS "Users can manage own addresses" ON user_addresses;
CREATE POLICY "Users can manage own addresses" ON user_addresses
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Staff can view all addresses" ON user_addresses;
CREATE POLICY "Staff can view all addresses" ON user_addresses
    FOR SELECT TO authenticated
    USING (is_staff());

-- === CASHIER_CUSTOMERS ===
DROP POLICY IF EXISTS "Staff can manage cashier customers" ON cashier_customers;
CREATE POLICY "Staff can manage cashier customers" ON cashier_customers
    FOR ALL TO authenticated
    USING (is_staff())
    WITH CHECK (is_staff());

-- === DAILY_ORDER_COUNTERS ===
DROP POLICY IF EXISTS "Staff can view counters" ON daily_order_counters;
CREATE POLICY "Staff can view counters" ON daily_order_counters
    FOR SELECT TO authenticated
    USING (is_staff());

-- === ORDINI ===
DROP POLICY IF EXISTS "Users can view own orders" ON ordini;
CREATE POLICY "Users can view own orders" ON ordini
    FOR SELECT TO authenticated
    USING (cliente_id = auth.uid());

DROP POLICY IF EXISTS "Staff can view all orders" ON ordini;
CREATE POLICY "Staff can view all orders" ON ordini
    FOR SELECT TO authenticated
    USING (is_staff());

DROP POLICY IF EXISTS "Users can create orders" ON ordini;
CREATE POLICY "Users can create orders" ON ordini
    FOR INSERT TO authenticated
    WITH CHECK (cliente_id = auth.uid() OR is_staff());

DROP POLICY IF EXISTS "Staff can update orders" ON ordini;
CREATE POLICY "Staff can update orders" ON ordini
    FOR UPDATE TO authenticated
    USING (is_staff())
    WITH CHECK (is_staff());

DROP POLICY IF EXISTS "Managers can delete orders" ON ordini;
CREATE POLICY "Managers can delete orders" ON ordini
    FOR DELETE TO authenticated
    USING (is_manager());

-- === ORDINI_ITEMS ===
DROP POLICY IF EXISTS "Users can view own order items" ON ordini_items;
CREATE POLICY "Users can view own order items" ON ordini_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM ordini o WHERE o.id = ordine_id AND (o.cliente_id = auth.uid() OR is_staff()))
    );

DROP POLICY IF EXISTS "Staff can manage order items" ON ordini_items;
CREATE POLICY "Staff can manage order items" ON ordini_items
    FOR ALL TO authenticated
    USING (is_staff())
    WITH CHECK (is_staff());

DROP POLICY IF EXISTS "Users can create own order items" ON ordini_items;
CREATE POLICY "Users can create own order items" ON ordini_items
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM ordini o WHERE o.id = ordine_id AND o.cliente_id = auth.uid())
    );

-- === ORDER_REMINDERS ===
DROP POLICY IF EXISTS "Staff can manage reminders" ON order_reminders;
CREATE POLICY "Staff can manage reminders" ON order_reminders
    FOR ALL TO authenticated
    USING (is_staff())
    WITH CHECK (is_staff());

-- === NOTIFICHE ===
DROP POLICY IF EXISTS "Users can view own notifications" ON notifiche;
CREATE POLICY "Users can view own notifications" ON notifiche
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own notifications" ON notifiche;
CREATE POLICY "Users can update own notifications" ON notifiche
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "System can insert notifications" ON notifiche;
CREATE POLICY "System can insert notifications" ON notifiche
    FOR INSERT TO authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can view all notifications" ON notifiche;
CREATE POLICY "Staff can view all notifications" ON notifiche
    FOR SELECT TO authenticated
    USING (is_staff());

COMMIT;

-- ===========================================================================
-- END MIGRATION 003
-- ===========================================================================
