-- ============================================
-- Fix notifiche table - Add missing ordine_id column
-- ============================================
-- This migration adds the missing ordine_id column to the notifiche table
-- to fix the error: "column ordine_id of relation 'notifiche' does not exist"

-- Add ordine_id column to notifiche table
ALTER TABLE public.notifiche 
ADD COLUMN ordine_id uuid REFERENCES public.ordini(id);

-- Create index for better performance on queries filtering by order
CREATE INDEX idx_notifiche_ordine_id ON public.notifiche(ordine_id);

-- Add comment for documentation
COMMENT ON COLUMN public.notifiche.ordine_id IS 'Reference to the order this notification is related to (optional)';
