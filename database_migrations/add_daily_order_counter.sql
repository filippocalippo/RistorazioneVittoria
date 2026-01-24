-- ============================================
-- Add daily order counter and update numero_ordine generation
-- ============================================

-- This migration introduces a per-day counter used to generate human-friendly
-- order numbers that reset every day, while keeping numero_ordine globally
-- unique by embedding the date.

CREATE TABLE IF NOT EXISTS public.daily_order_counters (
  day date PRIMARY KEY,
  last_value integer NOT NULL
);

-- Generate order numbers in the format YYYYMMDD-0001, YYYYMMDD-0002, ...
-- The LAST 4 DIGITS are the human-facing counter. Existing orders keep their
-- previous numero_ordine values (e.g. ORD-YYYYMMDD-XXXX) and remain valid.

CREATE OR REPLACE FUNCTION public.generate_numero_ordine()
RETURNS text
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  today date := CURRENT_DATE;
  current_value integer;
BEGIN
  -- Concurrent-safe increment of today's counter
  LOOP
    -- Try to update today's row
    UPDATE public.daily_order_counters
    SET last_value = last_value + 1
    WHERE day = today
    RETURNING last_value INTO current_value;

    IF FOUND THEN
      EXIT;
    END IF;

    -- If no row for today, try to insert one starting at 1
    BEGIN
      INSERT INTO public.daily_order_counters(day, last_value)
      VALUES (today, 1)
      RETURNING last_value INTO current_value;
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        -- Another transaction created today's row; loop and retry UPDATE
    END;
  END LOOP;

  -- Store value as YYYYMMDD-0001; UI can display only the last 4 digits
  RETURN TO_CHAR(today, 'YYYYMMDD') || '-' || LPAD(current_value::text, 4, '0');
END;
$function$;


