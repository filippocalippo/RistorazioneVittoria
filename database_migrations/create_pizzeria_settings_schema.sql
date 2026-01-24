-- Migration: Create pizzeria settings schema with separate tables per category
-- This migration creates a dedicated schema and separate tables for each settings category

-- Step 1: Create dedicated schema for settings
CREATE SCHEMA IF NOT EXISTS settings;

-- Step 2: Create order_management_settings table
CREATE TABLE IF NOT EXISTS settings.order_management (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  
  -- Order types
  ordini_consegna_attivi boolean DEFAULT true,
  ordini_asporto_attivi boolean DEFAULT true,
  ordini_tavolo_attivi boolean DEFAULT true,
  
  -- Limits and times
  ordine_minimo numeric DEFAULT 10.00 CHECK (ordine_minimo >= 0),
  tempo_preparazione_medio integer DEFAULT 30 CHECK (tempo_preparazione_medio > 0),
  max_ordini_simultanei integer DEFAULT 50 CHECK (max_ordini_simultanei > 0),
  
  -- Scheduled orders
  accetta_ordini_programmati boolean DEFAULT true,
  anticipo_massimo_ore integer DEFAULT 48 CHECK (anticipo_massimo_ore > 0),
  tempo_slot_minuti integer DEFAULT 30 CHECK (tempo_slot_minuti IN (15, 30, 60)),
  
  -- Controls
  pausa_ordini_attiva boolean DEFAULT false,
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT order_management_pkey PRIMARY KEY (id),
  CONSTRAINT order_management_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT order_management_pizzeria_id_unique UNIQUE (pizzeria_id)
);

-- Step 3: Create delivery_configuration table
CREATE TABLE IF NOT EXISTS settings.delivery_configuration (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  
  -- Delivery type
  tipo_calcolo_consegna text DEFAULT 'fisso' CHECK (tipo_calcolo_consegna IN ('fisso', 'per_km')),
  
  -- Costs
  costo_consegna_base numeric DEFAULT 3.00 CHECK (costo_consegna_base >= 0),
  costo_consegna_per_km numeric DEFAULT 0.50 CHECK (costo_consegna_per_km >= 0),
  raggio_consegna_km numeric DEFAULT 5.0 CHECK (raggio_consegna_km > 0),
  
  -- Promotions
  consegna_gratuita_sopra numeric DEFAULT 30.00 CHECK (consegna_gratuita_sopra >= 0),
  
  -- Times
  tempo_consegna_stimato_min integer DEFAULT 30 CHECK (tempo_consegna_stimato_min >= 10),
  tempo_consegna_stimato_max integer DEFAULT 60 CHECK (tempo_consegna_stimato_max >= 15),
  
  -- Custom zones (JSON array of zone objects)
  zone_consegna_personalizzate jsonb DEFAULT '[]'::jsonb,
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT delivery_configuration_pkey PRIMARY KEY (id),
  CONSTRAINT delivery_configuration_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT delivery_configuration_pizzeria_id_unique UNIQUE (pizzeria_id),
  CONSTRAINT delivery_configuration_time_check CHECK (tempo_consegna_stimato_max >= tempo_consegna_stimato_min)
);

-- Step 4: Create display_branding table
CREATE TABLE IF NOT EXISTS settings.display_branding (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  
  -- Display options
  mostra_allergeni boolean DEFAULT true,
  
  -- Brand colors
  colore_primario text DEFAULT '#FF6B35' CHECK (colore_primario ~ '^#[0-9A-Fa-f]{6}$'),
  colore_secondario text DEFAULT '#004E89' CHECK (colore_secondario ~ '^#[0-9A-Fa-f]{6}$'),
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT display_branding_pkey PRIMARY KEY (id),
  CONSTRAINT display_branding_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT display_branding_pizzeria_id_unique UNIQUE (pizzeria_id)
);

-- Step 5: Create kitchen_management table
CREATE TABLE IF NOT EXISTS settings.kitchen_management (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  
  -- Print settings
  stampa_automatica_ordini boolean DEFAULT false,
  
  -- Display settings
  mostra_note_cucina boolean DEFAULT true,
  
  -- Notifications
  alert_sonoro_nuovo_ordine boolean DEFAULT true,
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT kitchen_management_pkey PRIMARY KEY (id),
  CONSTRAINT kitchen_management_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT kitchen_management_pizzeria_id_unique UNIQUE (pizzeria_id)
);

-- Step 6: Create business_rules table
CREATE TABLE IF NOT EXISTS settings.business_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  
  -- Active status
  attiva boolean DEFAULT true,
  
  -- Temporary closure
  chiusura_temporanea boolean DEFAULT false,
  data_chiusura_da timestamp with time zone,
  data_chiusura_a timestamp with time zone,
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT business_rules_pkey PRIMARY KEY (id),
  CONSTRAINT business_rules_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT business_rules_pizzeria_id_unique UNIQUE (pizzeria_id),
  CONSTRAINT business_rules_closure_dates_check CHECK (
    (chiusura_temporanea = false) OR 
    (data_chiusura_da IS NOT NULL AND data_chiusura_a IS NOT NULL AND data_chiusura_a >= data_chiusura_da)
  )
);

-- Step 7: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_order_management_pizzeria ON settings.order_management(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_delivery_configuration_pizzeria ON settings.delivery_configuration(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_display_branding_pizzeria ON settings.display_branding(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_management_pizzeria ON settings.kitchen_management(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_business_rules_pizzeria ON settings.business_rules(pizzeria_id);

-- Step 8: Create triggers for updated_at
CREATE OR REPLACE FUNCTION settings.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_order_management_updated_at
  BEFORE UPDATE ON settings.order_management
  FOR EACH ROW
  EXECUTE FUNCTION settings.update_updated_at_column();

CREATE TRIGGER trigger_delivery_configuration_updated_at
  BEFORE UPDATE ON settings.delivery_configuration
  FOR EACH ROW
  EXECUTE FUNCTION settings.update_updated_at_column();

CREATE TRIGGER trigger_display_branding_updated_at
  BEFORE UPDATE ON settings.display_branding
  FOR EACH ROW
  EXECUTE FUNCTION settings.update_updated_at_column();

CREATE TRIGGER trigger_kitchen_management_updated_at
  BEFORE UPDATE ON settings.kitchen_management
  FOR EACH ROW
  EXECUTE FUNCTION settings.update_updated_at_column();

CREATE TRIGGER trigger_business_rules_updated_at
  BEFORE UPDATE ON settings.business_rules
  FOR EACH ROW
  EXECUTE FUNCTION settings.update_updated_at_column();

-- Step 9: Migrate existing data from pizzerie table

-- Migrate order management settings
INSERT INTO settings.order_management (
  pizzeria_id,
  ordine_minimo,
  tempo_preparazione_medio
)
SELECT 
  id,
  ordine_minimo,
  tempo_preparazione_medio
FROM public.pizzerie
ON CONFLICT (pizzeria_id) DO UPDATE SET
  ordine_minimo = EXCLUDED.ordine_minimo,
  tempo_preparazione_medio = EXCLUDED.tempo_preparazione_medio;

-- Migrate delivery configuration settings
INSERT INTO settings.delivery_configuration (
  pizzeria_id,
  costo_consegna_base,
  raggio_consegna_km
)
SELECT 
  id,
  costo_consegna_base,
  raggio_consegna_km
FROM public.pizzerie
ON CONFLICT (pizzeria_id) DO UPDATE SET
  costo_consegna_base = EXCLUDED.costo_consegna_base,
  raggio_consegna_km = EXCLUDED.raggio_consegna_km;

-- Create default display branding settings
INSERT INTO settings.display_branding (pizzeria_id)
SELECT id FROM public.pizzerie
ON CONFLICT (pizzeria_id) DO NOTHING;

-- Create default kitchen management settings
INSERT INTO settings.kitchen_management (pizzeria_id)
SELECT id FROM public.pizzerie
ON CONFLICT (pizzeria_id) DO NOTHING;

-- Migrate business rules settings
INSERT INTO settings.business_rules (
  pizzeria_id,
  attiva
)
SELECT 
  id,
  attiva
FROM public.pizzerie
ON CONFLICT (pizzeria_id) DO UPDATE SET
  attiva = EXCLUDED.attiva;

-- Step 10: Enable Row Level Security (RLS)
ALTER TABLE settings.order_management ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings.delivery_configuration ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings.display_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings.kitchen_management ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings.business_rules ENABLE ROW LEVEL SECURITY;

-- Step 11: Create RLS policies for order_management
CREATE POLICY "Managers can view their pizzeria order settings"
  ON settings.order_management FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = order_management.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can update their pizzeria order settings"
  ON settings.order_management FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = order_management.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can insert their pizzeria order settings"
  ON settings.order_management FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = order_management.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Customers can view order settings"
  ON settings.order_management FOR SELECT TO authenticated
  USING (true);

-- Step 12: Create RLS policies for delivery_configuration
CREATE POLICY "Managers can view their pizzeria delivery settings"
  ON settings.delivery_configuration FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = delivery_configuration.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can update their pizzeria delivery settings"
  ON settings.delivery_configuration FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = delivery_configuration.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can insert their pizzeria delivery settings"
  ON settings.delivery_configuration FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = delivery_configuration.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Customers can view delivery settings"
  ON settings.delivery_configuration FOR SELECT TO authenticated
  USING (true);

-- Step 13: Create RLS policies for display_branding
CREATE POLICY "Managers can view their pizzeria branding settings"
  ON settings.display_branding FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = display_branding.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can update their pizzeria branding settings"
  ON settings.display_branding FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = display_branding.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can insert their pizzeria branding settings"
  ON settings.display_branding FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = display_branding.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Customers can view branding settings"
  ON settings.display_branding FOR SELECT TO authenticated
  USING (true);

-- Step 14: Create RLS policies for kitchen_management
CREATE POLICY "Managers and kitchen can view kitchen settings"
  ON settings.kitchen_management FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = kitchen_management.pizzeria_id
      AND profiles.ruolo IN ('manager', 'kitchen')
    )
  );

CREATE POLICY "Managers can update kitchen settings"
  ON settings.kitchen_management FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = kitchen_management.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can insert kitchen settings"
  ON settings.kitchen_management FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = kitchen_management.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

-- Step 15: Create RLS policies for business_rules
CREATE POLICY "Managers can view their pizzeria business rules"
  ON settings.business_rules FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = business_rules.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can update their pizzeria business rules"
  ON settings.business_rules FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = business_rules.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can insert their pizzeria business rules"
  ON settings.business_rules FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.pizzeria_id = business_rules.pizzeria_id
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Customers can view business rules"
  ON settings.business_rules FOR SELECT TO authenticated
  USING (true);

-- Step 16: Create helper view for complete settings
CREATE OR REPLACE VIEW settings.pizzeria_complete_settings AS
SELECT 
  p.id as pizzeria_id,
  p.nome,
  p.slug,
  
  -- Order Management
  om.ordini_consegna_attivi,
  om.ordini_asporto_attivi,
  om.ordini_tavolo_attivi,
  om.ordine_minimo,
  om.tempo_preparazione_medio,
  om.max_ordini_simultanei,
  om.accetta_ordini_programmati,
  om.anticipo_massimo_ore,
  om.tempo_slot_minuti,
  om.pausa_ordini_attiva,
  
  -- Delivery Configuration
  dc.tipo_calcolo_consegna,
  dc.costo_consegna_base,
  dc.costo_consegna_per_km,
  dc.raggio_consegna_km,
  dc.consegna_gratuita_sopra,
  dc.tempo_consegna_stimato_min,
  dc.tempo_consegna_stimato_max,
  dc.zone_consegna_personalizzate,
  
  -- Display & Branding
  db.mostra_allergeni,
  db.colore_primario,
  db.colore_secondario,
  
  -- Kitchen Management
  km.stampa_automatica_ordini,
  km.mostra_note_cucina,
  km.alert_sonoro_nuovo_ordine,
  
  -- Business Rules
  br.attiva,
  br.chiusura_temporanea,
  br.data_chiusura_da,
  br.data_chiusura_a
  
FROM public.pizzerie p
LEFT JOIN settings.order_management om ON p.id = om.pizzeria_id
LEFT JOIN settings.delivery_configuration dc ON p.id = dc.pizzeria_id
LEFT JOIN settings.display_branding db ON p.id = db.pizzeria_id
LEFT JOIN settings.kitchen_management km ON p.id = km.pizzeria_id
LEFT JOIN settings.business_rules br ON p.id = br.pizzeria_id;

-- Grant access to the view
GRANT SELECT ON settings.pizzeria_complete_settings TO authenticated;

-- Step 17: Add comments for documentation
COMMENT ON SCHEMA settings IS 'Dedicated schema for pizzeria settings tables';
COMMENT ON TABLE settings.order_management IS 'Order management settings including types, limits, and scheduling';
COMMENT ON TABLE settings.delivery_configuration IS 'Delivery configuration including pricing type (fixed/per-km), costs, and zones';
COMMENT ON TABLE settings.display_branding IS 'Display and branding settings including colors and visibility options';
COMMENT ON TABLE settings.kitchen_management IS 'Kitchen-specific settings for printing, display, and notifications';
COMMENT ON TABLE settings.business_rules IS 'Business rules including active status and temporary closures';
COMMENT ON VIEW settings.pizzeria_complete_settings IS 'Complete view of all settings for a pizzeria';

-- Migration complete!
-- The old columns in pizzerie table can be kept for backward compatibility
-- or removed in a future migration after confirming all code uses the new settings tables.
