-- MIGRATION 005: RLS POLICIES AND REMAINING FUNCTIONS
-- Consolidates all RLS policies for the fresh database
-- Date: 2026-01-24

BEGIN;

-- RLS POLICIES FOR SETTINGS TABLES

-- BUSINESS_RULES
DROP POLICY IF EXISTS "Anyone can view business rules" ON business_rules;
CREATE POLICY "Anyone can view business rules" ON business_rules FOR SELECT TO authenticated
USING (organization_id = get_current_organization_id());
DROP POLICY IF EXISTS "Managers can manage business rules" ON business_rules;
CREATE POLICY "Managers can manage business rules" ON business_rules FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- DELIVERY_CONFIGURATION
DROP POLICY IF EXISTS "Anyone can view delivery config" ON delivery_configuration;
CREATE POLICY "Anyone can view delivery config" ON delivery_configuration FOR SELECT TO authenticated
USING (organization_id = get_current_organization_id());
DROP POLICY IF EXISTS "Managers can manage delivery config" ON delivery_configuration;
CREATE POLICY "Managers can manage delivery config" ON delivery_configuration FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- ORDER_MANAGEMENT
DROP POLICY IF EXISTS "Staff can view order management" ON order_management;
CREATE POLICY "Staff can view order management" ON order_management FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "Managers can manage order settings" ON order_management;
CREATE POLICY "Managers can manage order settings" ON order_management FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- KITCHEN_MANAGEMENT
DROP POLICY IF EXISTS "Staff can view kitchen settings" ON kitchen_management;
CREATE POLICY "Staff can view kitchen settings" ON kitchen_management FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "Managers can manage kitchen settings" ON kitchen_management;
CREATE POLICY "Managers can manage kitchen settings" ON kitchen_management FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- DISPLAY_BRANDING
DROP POLICY IF EXISTS "Anyone can view branding" ON display_branding;
CREATE POLICY "Anyone can view branding" ON display_branding FOR SELECT TO authenticated
USING (organization_id = get_current_organization_id());
DROP POLICY IF EXISTS "Managers can manage branding" ON display_branding;
CREATE POLICY "Managers can manage branding" ON display_branding FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- DASHBOARD_SECURITY
DROP POLICY IF EXISTS "Managers can manage dashboard security" ON dashboard_security;
CREATE POLICY "Managers can manage dashboard security" ON dashboard_security FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- PROMOTIONAL_BANNERS
DROP POLICY IF EXISTS "Anyone can view active banners" ON promotional_banners;
CREATE POLICY "Anyone can view active banners" ON promotional_banners FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND (
        (attivo = true AND (data_inizio IS NULL OR data_inizio <= now()) AND (data_fine IS NULL OR data_fine >= now()))
        OR is_staff()
    )
);
DROP POLICY IF EXISTS "Managers can manage banners" ON promotional_banners;
CREATE POLICY "Managers can manage banners" ON promotional_banners FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- INGREDIENT_CONSUMPTION_RULES
DROP POLICY IF EXISTS "Staff can view consumption rules" ON ingredient_consumption_rules;
CREATE POLICY "Staff can view consumption rules" ON ingredient_consumption_rules FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "Managers can manage consumption rules" ON ingredient_consumption_rules;
CREATE POLICY "Managers can manage consumption rules" ON ingredient_consumption_rules FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- INVENTORY_LOGS
DROP POLICY IF EXISTS "Staff can view inventory logs" ON inventory_logs;
CREATE POLICY "Staff can view inventory logs" ON inventory_logs FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "Staff can insert inventory logs" ON inventory_logs;
CREATE POLICY "Staff can insert inventory logs" ON inventory_logs FOR INSERT TO authenticated
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_staff()
);

-- PAYMENT_TRANSACTIONS
DROP POLICY IF EXISTS "Users can view own payments" ON payment_transactions;
CREATE POLICY "Users can view own payments" ON payment_transactions FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND EXISTS (SELECT 1 FROM ordini o WHERE o.id = order_id AND o.cliente_id = auth.uid())
);
DROP POLICY IF EXISTS "Staff can view all payments" ON payment_transactions;
CREATE POLICY "Staff can view all payments" ON payment_transactions FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "System can create payments" ON payment_transactions;
CREATE POLICY "System can create payments" ON payment_transactions FOR INSERT TO authenticated
WITH CHECK (organization_id = get_current_organization_id());

-- STATISTICHE_GIORNALIERE
DROP POLICY IF EXISTS "Staff can view statistics" ON statistiche_giornaliere;
CREATE POLICY "Staff can view statistics" ON statistiche_giornaliere FOR SELECT TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_staff()
);
DROP POLICY IF EXISTS "Managers can manage statistics" ON statistiche_giornaliere;
CREATE POLICY "Managers can manage statistics" ON statistiche_giornaliere FOR ALL TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
)
WITH CHECK (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);

-- INVENTORY FUNCTIONS

CREATE OR REPLACE FUNCTION set_ingredient_stock(
    p_ingredient_id UUID,
    p_new_quantity NUMERIC,
    p_reason TEXT DEFAULT 'adjust',
    p_reference_id TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old_qty NUMERIC; v_org_id UUID;
BEGIN
    SELECT stock_quantity, organization_id INTO v_old_qty, v_org_id
    FROM ingredients WHERE id = p_ingredient_id FOR UPDATE;

    UPDATE ingredients SET stock_quantity = p_new_quantity WHERE id = p_ingredient_id;

    INSERT INTO inventory_logs (organization_id, ingredient_id, quantity_change, reason, reference_id, created_by)
    VALUES (v_org_id, p_ingredient_id, p_new_quantity - COALESCE(v_old_qty, 0), p_reason, p_reference_id, auth.uid());
END; $$;

CREATE OR REPLACE FUNCTION adjust_ingredient_stock(
    p_ingredient_id UUID,
    p_delta NUMERIC,
    p_reason TEXT DEFAULT 'adjust',
    p_reference_id TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old_qty NUMERIC; v_new_qty NUMERIC; v_org_id UUID;
BEGIN
    SELECT stock_quantity, organization_id INTO v_old_qty, v_org_id
    FROM ingredients WHERE id = p_ingredient_id FOR UPDATE;

    v_new_qty := COALESCE(v_old_qty, 0) + p_delta;
    UPDATE ingredients SET stock_quantity = v_new_qty WHERE id = p_ingredient_id;

    INSERT INTO inventory_logs (organization_id, ingredient_id, quantity_change, reason, reference_id, created_by)
    VALUES (v_org_id, p_ingredient_id, p_delta, p_reason, p_reference_id, auth.uid());
END; $$;

CREATE OR REPLACE FUNCTION update_ingredient_stock(p_ingredient_id UUID, p_delta NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM adjust_ingredient_stock(p_ingredient_id, p_delta, COALESCE(p_note, 'adjust'), NULL);
END; $$;

-- BANNER ANALYTICS FUNCTIONS

CREATE OR REPLACE FUNCTION increment_banner_view(p_banner_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN UPDATE promotional_banners SET visualizzazioni = visualizzazioni + 1 WHERE id = p_banner_id; END; $$;

CREATE OR REPLACE FUNCTION increment_banner_click(p_banner_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN UPDATE promotional_banners SET click = click + 1 WHERE id = p_banner_id; END; $$;

CREATE OR REPLACE FUNCTION get_banner_analytics(p_banner_id UUID)
RETURNS TABLE (impressions INTEGER, clicks INTEGER, ctr NUMERIC) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
    RETURN QUERY SELECT pb.visualizzazioni, pb.click, CASE WHEN pb.visualizzazioni > 0 THEN (pb.click::NUMERIC / pb.visualizzazioni * 100) ELSE 0 END FROM promotional_banners pb WHERE pb.id = p_banner_id;
END; $$;

-- BANNER CREATOR TRIGGER

CREATE OR REPLACE FUNCTION set_promotional_banner_creator()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NEW.created_by IS NULL THEN NEW.created_by := auth.uid(); END IF; RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS set_banner_creator ON promotional_banners;
CREATE TRIGGER set_banner_creator BEFORE INSERT ON promotional_banners FOR EACH ROW EXECUTE FUNCTION set_promotional_banner_creator();

-- ROLE ESCALATION PREVENTION TRIGGERS

CREATE OR REPLACE FUNCTION prevent_self_role_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF OLD.ruolo = 'customer' AND NEW.ruolo IN ('manager', 'kitchen', 'delivery') AND OLD.id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot escalate own role';
    END IF;
    RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS prevent_self_role_escalation ON profiles;
CREATE TRIGGER prevent_self_role_escalation BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_self_role_escalation();

CREATE OR REPLACE FUNCTION prevent_role_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF OLD.ruolo != NEW.ruolo AND OLD.id = auth.uid() AND NOT is_manager() THEN
        RAISE EXCEPTION 'Only managers can change roles';
    END IF;
    RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS prevent_role_change_trigger ON profiles;
CREATE TRIGGER prevent_role_change_trigger BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_role_change();

-- CRITICAL UPDATES PREVENTION

CREATE OR REPLACE FUNCTION prevent_critical_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.stato IN ('completed', 'cancelled') AND NEW.stato != OLD.stato THEN
        IF NOT is_manager() THEN
            RAISE EXCEPTION 'Cannot modify completed or cancelled orders';
        END IF;
    END IF;
    RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS prevent_critical_updates_trigger ON ordini;
CREATE TRIGGER prevent_critical_updates_trigger BEFORE UPDATE ON ordini FOR EACH ROW EXECUTE FUNCTION prevent_critical_updates();

-- UPDATED_AT TRIGGERS FOR SETTINGS TABLES

DROP TRIGGER IF EXISTS update_business_rules_updated_at ON business_rules;
CREATE TRIGGER update_business_rules_updated_at BEFORE UPDATE ON business_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_delivery_configuration_updated_at ON delivery_configuration;
CREATE TRIGGER update_delivery_configuration_updated_at BEFORE UPDATE ON delivery_configuration FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_order_management_updated_at ON order_management;
CREATE TRIGGER update_order_management_updated_at BEFORE UPDATE ON order_management FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_kitchen_management_updated_at ON kitchen_management;
CREATE TRIGGER update_kitchen_management_updated_at BEFORE UPDATE ON kitchen_management FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_display_branding_updated_at ON display_branding;
CREATE TRIGGER update_display_branding_updated_at BEFORE UPDATE ON display_branding FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_promotional_banners_updated_at ON promotional_banners;
CREATE TRIGGER update_promotional_banners_updated_at BEFORE UPDATE ON promotional_banners FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ingredient_consumption_rules_updated_at ON ingredient_consumption_rules;
CREATE TRIGGER update_ingredient_consumption_rules_updated_at BEFORE UPDATE ON ingredient_consumption_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_statistiche_giornaliere_updated_at ON statistiche_giornaliere;
CREATE TRIGGER update_statistiche_giornaliere_updated_at BEFORE UPDATE ON statistiche_giornaliere FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
