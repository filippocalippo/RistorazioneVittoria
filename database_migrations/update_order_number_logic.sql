-- ============================================
-- Update Order Number Logic to Follow Slot Date
-- ============================================

-- 1. Create a version of the generator that accepts a date
CREATE OR REPLACE FUNCTION public.generate_numero_ordine_v2(target_date date)
RETURNS text
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  current_value integer;
BEGIN
  -- Ensure we have a valid date
  IF target_date IS NULL THEN
    target_date := CURRENT_DATE;
  END IF;

  -- Concurrent-safe increment for the specific target_date
  LOOP
    -- Try to update that day's row
    UPDATE public.daily_order_counters
    SET last_value = last_value + 1
    WHERE day = target_date
    RETURNING last_value INTO current_value;

    IF FOUND THEN
      EXIT;
    END IF;

    -- If no row for that day, try to insert one starting at 1
    BEGIN
      INSERT INTO public.daily_order_counters(day, last_value)
      VALUES (target_date, 1)
      RETURNING last_value INTO current_value;
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        -- Another transaction created the row; loop and retry UPDATE
    END;
  END LOOP;

  -- Return format: YYYYMMDD-XXXX
  RETURN TO_CHAR(target_date, 'YYYYMMDD') || '-' || LPAD(current_value::text, 4, '0');
END;
$function$;

-- 2. Create the trigger function
CREATE OR REPLACE FUNCTION public.assign_order_number_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  -- Logic:
  -- 1. On INSERT: Always generate number based on slot date (or current date)
  -- 2. On UPDATE: Only regenerate if the date part of slot_prenotato_start has changed
  
  IF (TG_OP = 'INSERT') THEN
      NEW.numero_ordine := public.generate_numero_ordine_v2(COALESCE(NEW.slot_prenotato_start::date, CURRENT_DATE));
  ELSIF (TG_OP = 'UPDATE') THEN
      -- Check if date changed
      IF (NEW.slot_prenotato_start::date IS DISTINCT FROM OLD.slot_prenotato_start::date) THEN
          NEW.numero_ordine := public.generate_numero_ordine_v2(COALESCE(NEW.slot_prenotato_start::date, CURRENT_DATE));
      END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 3. Create the trigger on ordini table
-- We use a distinct name to avoid conflict, and we'll try to drop any old trigger if we knew its name.
-- Since we don't know the old trigger name, we rely on this one running. 
-- Ideally we should drop the old one to avoid double generation, but without the name it's hard.
-- However, if the old trigger uses the old function (no args), it might overwrite or be overwritten.
-- To be safe, let's try to replace the OLD function to do nothing or redirect, 
-- BUT the old function signature is different (no args).

DROP TRIGGER IF EXISTS tr_assign_order_number_v2 ON public.ordini;

CREATE TRIGGER tr_assign_order_number_v2
BEFORE INSERT OR UPDATE ON public.ordini
FOR EACH ROW
EXECUTE FUNCTION public.assign_order_number_trigger();
