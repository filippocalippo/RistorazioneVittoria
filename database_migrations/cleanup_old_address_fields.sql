-- Migration: Remove old address fields from profiles table
-- This migration removes the now-unused address fields after migrating to user_addresses table

-- IMPORTANT: Run this AFTER migrating existing addresses to user_addresses table
-- and AFTER updating your application code to use the new tables

-- Remove the old address columns from profiles table
ALTER TABLE public.profiles 
  DROP COLUMN IF EXISTS indirizzo,
  DROP COLUMN IF EXISTS citta,
  DROP COLUMN IF EXISTS cap;

-- Also remove unused single-city fields from pizzerie table if needed
-- (Keep them commented out if you still want pizzeria's main address for display)
-- ALTER TABLE public.pizzerie 
--   DROP COLUMN IF EXISTS indirizzo,
--   DROP COLUMN IF EXISTS citta,
--   DROP COLUMN IF EXISTS cap,
--   DROP COLUMN IF EXISTS provincia;
