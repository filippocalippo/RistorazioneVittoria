-- Security and Integrity Fixes

-- 1. Database Integrity Constraints
-- Ensure quantity is always positive
ALTER TABLE ordini_items 
ADD CONSTRAINT ordini_items_quantita_check 
CHECK (quantita > 0);

-- Ensure order totals are never negative
ALTER TABLE ordini 
ADD CONSTRAINT ordini_totale_check 
CHECK (totale >= 0);

-- 2. Role Protection Trigger
-- Prevent users from escalating their own privileges by modifying the 'ruolo' column
CREATE OR REPLACE FUNCTION public.prevent_self_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the role field is being modified
  IF NEW.ruolo IS DISTINCT FROM OLD.ruolo THEN
    -- If the user is updating their own record
    IF auth.uid() = OLD.id THEN
        RAISE EXCEPTION 'Security violation: You cannot modify your own role.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists to allow idempotent runs
DROP TRIGGER IF EXISTS check_role_escalation ON public.profiles;

CREATE TRIGGER check_role_escalation
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_self_role_escalation();
