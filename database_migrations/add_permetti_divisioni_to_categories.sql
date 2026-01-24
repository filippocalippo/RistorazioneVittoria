-- Migration: add_permetti_divisioni_to_categories
-- Date: 2025-11-09
-- Description: Add permetti_divisioni column to categorie_menu table to allow/disallow product splits per category

-- Add permetti_divisioni column to categorie_menu table
ALTER TABLE categorie_menu 
ADD COLUMN IF NOT EXISTS permetti_divisioni boolean DEFAULT true;

-- Add comment to explain the column
COMMENT ON COLUMN categorie_menu.permetti_divisioni IS 'Indica se la categoria permette di dividere i prodotti (split)';
