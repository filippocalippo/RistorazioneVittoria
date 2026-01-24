-- MIGRATION 004: SETTINGS & INVENTORY
-- Creates configuration and inventory tables with org-awareness
-- Date: 2026-01-24

BEGIN;

-- BUSINESS_RULES
CREATE TABLE IF NOT EXISTS public.business_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    attiva BOOLEAN DEFAULT true,
    chiusura_temporanea BOOLEAN DEFAULT false,
    data_chiusura_da TIMESTAMPTZ,
    data_chiusura_a TIMESTAMPTZ,
    indirizzo TEXT, citta TEXT, cap TEXT, provincia TEXT,
    telefono TEXT, email TEXT,
    immagine_copertina_url TEXT,
    latitude NUMERIC, longitude NUMERIC,
    orari JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_business_rules_org ON business_rules(organization_id);

-- DELIVERY_CONFIGURATION
CREATE TABLE IF NOT EXISTS public.delivery_configuration (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    tipo_calcolo_consegna TEXT DEFAULT 'fisso' CHECK (tipo_calcolo_consegna IN ('fisso', 'radiale', 'zone')),
    costo_consegna_base NUMERIC(10,2) DEFAULT 3.0,
    costo_consegna_per_km NUMERIC(10,2) DEFAULT 0.5,
    raggio_consegna_km NUMERIC DEFAULT 5.0,
    consegna_gratuita_sopra NUMERIC(10,2) DEFAULT 30.0,
    tempo_consegna_stimato_min INTEGER DEFAULT 30,
    tempo_consegna_stimato_max INTEGER DEFAULT 60,
    zone_consegna_personalizzate JSONB DEFAULT '[]'::jsonb,
    costo_consegna_radiale JSONB DEFAULT '[]'::jsonb,
    prezzo_fuori_raggio NUMERIC(10,2) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_configuration_org ON delivery_configuration(organization_id);

-- ORDER_MANAGEMENT
CREATE TABLE IF NOT EXISTS public.order_management (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    ordini_consegna_attivi BOOLEAN DEFAULT true,
    ordini_asporto_attivi BOOLEAN DEFAULT true,
    ordini_tavolo_attivi BOOLEAN DEFAULT true,
    ordine_minimo NUMERIC(10,2) DEFAULT 10.0,
    tempo_preparazione_medio INTEGER DEFAULT 30,
    tempo_slot_minuti INTEGER DEFAULT 30,
    capacity_takeaway_per_slot INTEGER DEFAULT 50,
    capacity_delivery_per_slot INTEGER DEFAULT 50,
    pausa_ordini_attiva BOOLEAN DEFAULT false,
    accetta_pagamenti_contanti BOOLEAN DEFAULT true,
    accetta_pagamenti_carta BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_order_management_org ON order_management(organization_id);

-- KITCHEN_MANAGEMENT
CREATE TABLE IF NOT EXISTS public.kitchen_management (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    stampa_automatica_ordini BOOLEAN DEFAULT false,
    mostra_note_cucina BOOLEAN DEFAULT true,
    alert_sonoro_nuovo_ordine BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_kitchen_management_org ON kitchen_management(organization_id);

-- DISPLAY_BRANDING
CREATE TABLE IF NOT EXISTS public.display_branding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    mostra_allergeni BOOLEAN DEFAULT true,
    colore_primario TEXT DEFAULT '#FF6B35',
    colore_secondario TEXT DEFAULT '#004E89',
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_display_branding_org ON display_branding(organization_id);

-- DASHBOARD_SECURITY
CREATE TABLE IF NOT EXISTS public.dashboard_security (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL, salt TEXT NOT NULL,
    recovery_hashes JSONB DEFAULT '[]'::jsonb, is_active BOOLEAN DEFAULT true,
    last_updated_at TIMESTAMPTZ DEFAULT now(), updated_by UUID REFERENCES auth.users(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dashboard_security_org ON dashboard_security(organization_id);

-- PROMOTIONAL_BANNERS
CREATE TABLE IF NOT EXISTS public.promotional_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    titolo TEXT NOT NULL,
    descrizione TEXT,
    immagine_url TEXT NOT NULL,
    action_type TEXT NOT NULL DEFAULT 'none',
    action_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    text_overlay JSONB,
    attivo BOOLEAN DEFAULT false,
    data_inizio TIMESTAMPTZ,
    data_fine TIMESTAMPTZ,
    priorita INTEGER DEFAULT 0,
    ordine INTEGER DEFAULT 0,
    mostra_solo_mobile BOOLEAN DEFAULT false,
    mostra_solo_desktop BOOLEAN DEFAULT false,
    visualizzazioni INTEGER DEFAULT 0,
    click INTEGER DEFAULT 0,
    is_sponsorizzato BOOLEAN DEFAULT false,
    sponsor_nome TEXT,
    sponsor_logo_url TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_promotional_banners_org ON promotional_banners(organization_id);
CREATE INDEX IF NOT EXISTS idx_promotional_banners_attivo ON promotional_banners(attivo) WHERE attivo = true;

-- INGREDIENT_CONSUMPTION_RULES
CREATE TABLE IF NOT EXISTS public.ingredient_consumption_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    product_id UUID REFERENCES menu_items(id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
    size_id UUID REFERENCES sizes_master(id) ON DELETE SET NULL,
    quantity NUMERIC NOT NULL DEFAULT 1, unit_of_measure TEXT DEFAULT 'unit',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(product_id, ingredient_id, size_id)
);
CREATE INDEX IF NOT EXISTS idx_ingredient_consumption_rules_org ON ingredient_consumption_rules(organization_id);

-- INVENTORY_LOGS
CREATE TABLE IF NOT EXISTS public.inventory_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    quantity_change NUMERIC NOT NULL,
    reason TEXT NOT NULL,
    reference_id TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inventory_logs_org ON inventory_logs(organization_id);
CREATE INDEX IF NOT EXISTS idx_inventory_logs_ingredient ON inventory_logs(ingredient_id);

-- PAYMENT_TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    order_id UUID REFERENCES ordini(id) ON DELETE SET NULL,
    payment_intent_id TEXT, amount NUMERIC(10,2), currency TEXT DEFAULT 'EUR',
    status TEXT, provider TEXT DEFAULT 'stripe',
    metadata JSONB DEFAULT '{}'::jsonb, provider_response JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_org ON payment_transactions(organization_id);

-- STATISTICHE_GIORNALIERE
CREATE TABLE IF NOT EXISTS public.statistiche_giornaliere (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    data DATE NOT NULL, ordini_totali INTEGER DEFAULT 0, ordini_consegna INTEGER DEFAULT 0,
    ordini_asporto INTEGER DEFAULT 0, ordini_cancellati INTEGER DEFAULT 0,
    fatturato_totale NUMERIC(10,2) DEFAULT 0, fatturato_consegna NUMERIC(10,2) DEFAULT 0,
    fatturato_asporto NUMERIC(10,2) DEFAULT 0, ordine_medio NUMERIC(10,2) DEFAULT 0,
    tempo_medio_preparazione INTEGER, tempo_medio_consegna INTEGER,
    prodotti_top JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(organization_id, data)
);

-- Enable RLS on all tables
ALTER TABLE business_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_configuration ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_management ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_management ENABLE ROW LEVEL SECURITY;
ALTER TABLE display_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_security ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotional_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_consumption_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE statistiche_giornaliere ENABLE ROW LEVEL SECURITY;

COMMIT;
