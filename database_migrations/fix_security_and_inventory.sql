-- Protect critical fields in ordini table from client-side manipulation
CREATE OR REPLACE FUNCTION prevent_critical_updates()
RETURNS TRIGGER AS $$
BEGIN
  -- Only restrict authenticated users (clients), allow service_role/postgres
  IF (auth.role() = 'authenticated') THEN
     -- Prevent modification of financial fields and status
     IF (NEW.subtotale != OLD.subtotale) OR
        (NEW.totale != OLD.totale) OR
        (NEW.costo_consegna != OLD.costo_consegna) OR
        (NEW.sconto != OLD.sconto) OR
        (NEW.pagato != OLD.pagato) OR
        (NEW.stato != OLD.stato) THEN
        
        RAISE EXCEPTION 'Unauthorized: You cannot modify protected order fields directly. Use the appropriate API endpoints.';
     END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS protect_order_integrity ON public.ordini;
CREATE TRIGGER protect_order_integrity
BEFORE UPDATE ON public.ordini
FOR EACH ROW
EXECUTE FUNCTION prevent_critical_updates();

-- Ensure authenticated users cannot INSERT directly (optional, but good practice if everything goes through Edge Function)
-- For now, we rely on the fact that the client code will be changed to use the Edge Function.
-- The trigger above prevents them from *changing* what they inserted if they try to be clever,
-- but they could still INSERT a fake paid order if we don't block INSERT.
-- blocking INSERT:
-- REVOKE INSERT ON public.ordini FROM authenticated;
-- (Commented out to prevent breaking app during transition, but recommended final step)
