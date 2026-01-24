-- ============================================
-- Fix ordini table trigger - tipo_ordine field reference
-- ============================================
-- This migration fixes any triggers or functions that incorrectly reference
-- 'tipo_ordine' instead of 'tipo' in the ordini table

-- First, let's check and drop any problematic triggers
-- Note: Run this query first to see what triggers exist:
-- SELECT trigger_name, event_manipulation, event_object_table, action_statement
-- FROM information_schema.triggers
-- WHERE event_object_table = 'ordini';

-- Common trigger that might cause this issue: notification trigger
-- Drop and recreate if it exists

-- Drop the problematic trigger if it exists
DO $$ 
BEGIN
    -- Drop trigger for order status notifications if it exists
    IF EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'notify_order_status_change'
    ) THEN
        DROP TRIGGER IF EXISTS notify_order_status_change ON public.ordini;
    END IF;
    
    -- Drop trigger for order creation notifications if it exists
    IF EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'notify_new_order'
    ) THEN
        DROP TRIGGER IF EXISTS notify_new_order ON public.ordini;
    END IF;
END $$;

-- Drop any functions that might reference tipo_ordine
DROP FUNCTION IF EXISTS public.notify_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS public.notify_new_order() CASCADE;

-- Recreate the order status change notification function with correct field name
CREATE OR REPLACE FUNCTION public.notify_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify on status changes
    IF (TG_OP = 'UPDATE' AND OLD.stato IS DISTINCT FROM NEW.stato) THEN
        -- Insert notification for kitchen staff when order is confirmed
        IF NEW.stato = 'confirmed' THEN
            INSERT INTO public.notifiche (
                destinatario_id,
                tipo,
                titolo,
                messaggio,
                dati,
                ordine_id
            )
            SELECT 
                p.id,
                'new_order',
                'Nuovo ordine #' || NEW.numero_ordine,
                'Ordine ' || NEW.tipo || ' da ' || NEW.nome_cliente,
                jsonb_build_object(
                    'ordine_id', NEW.id,
                    'numero_ordine', NEW.numero_ordine,
                    'tipo', NEW.tipo,
                    'totale', NEW.totale
                ),
                NEW.id
            FROM public.profiles p
            WHERE p.ruolo IN ('kitchen', 'manager')
            AND p.attivo = true;
        END IF;
        
        -- Notify customer when order is ready
        IF NEW.stato = 'ready' AND NEW.cliente_id IS NOT NULL THEN
            INSERT INTO public.notifiche (
                destinatario_id,
                tipo,
                titolo,
                messaggio,
                dati,
                ordine_id
            )
            VALUES (
                NEW.cliente_id,
                'order_ready',
                'Ordine pronto! #' || NEW.numero_ordine,
                'Il tuo ordine è pronto per il ' || 
                CASE 
                    WHEN NEW.tipo = 'delivery' THEN 'ritiro'
                    WHEN NEW.tipo = 'takeaway' THEN 'ritiro'
                    ELSE 'servizio'
                END,
                jsonb_build_object(
                    'ordine_id', NEW.id,
                    'numero_ordine', NEW.numero_ordine,
                    'tipo', NEW.tipo
                ),
                NEW.id
            );
        END IF;
        
        -- Notify delivery person when order is ready for delivery
        IF NEW.stato = 'ready' AND NEW.tipo = 'delivery' THEN
            INSERT INTO public.notifiche (
                destinatario_id,
                tipo,
                titolo,
                messaggio,
                dati,
                ordine_id
            )
            SELECT 
                p.id,
                'delivery_available',
                'Ordine pronto per consegna #' || NEW.numero_ordine,
                'Indirizzo: ' || COALESCE(NEW.indirizzo_consegna, 'N/A'),
                jsonb_build_object(
                    'ordine_id', NEW.id,
                    'numero_ordine', NEW.numero_ordine,
                    'indirizzo', NEW.indirizzo_consegna,
                    'citta', NEW.citta_consegna
                ),
                NEW.id
            FROM public.profiles p
            WHERE p.ruolo = 'delivery'
            AND p.attivo = true;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for order status changes
CREATE TRIGGER notify_order_status_change
    AFTER INSERT OR UPDATE ON public.ordini
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_order_status_change();

-- Add comment for documentation
COMMENT ON FUNCTION public.notify_order_status_change() IS 
'Sends notifications to relevant users when order status changes. Uses correct field name "tipo" instead of "tipo_ordine".';
