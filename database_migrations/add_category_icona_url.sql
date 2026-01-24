-- Migration: Add icona_url column to categorie_menu table
-- This allows categories to have image-based icons stored in Supabase Storage
-- Recommended image size: 1024x1024px

ALTER TABLE public.categorie_menu
ADD COLUMN IF NOT EXISTS icona_url TEXT NULL;

COMMENT ON COLUMN public.categorie_menu.icona_url IS 'URL of the category icon image stored in Supabase Storage. Recommended size: 1024x1024px.';











