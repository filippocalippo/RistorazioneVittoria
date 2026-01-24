-- Migration: add_ingredient_size_prices
-- Description: Create table for ingredient prices per size variant
-- Date: 2025-12-03

-- Create table for ingredient prices per size
CREATE TABLE ingredient_size_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  size_id UUID NOT NULL REFERENCES sizes_master(id) ON DELETE CASCADE,
  prezzo NUMERIC NOT NULL CHECK (prezzo >= 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(ingredient_id, size_id)
);

-- Enable RLS
ALTER TABLE ingredient_size_prices ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all users to read ingredient size prices
CREATE POLICY "Allow public read" ON ingredient_size_prices
  FOR SELECT USING (true);

-- Policy: Only managers can modify ingredient size prices
CREATE POLICY "Allow manager insert" ON ingredient_size_prices
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Allow manager update" ON ingredient_size_prices
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Allow manager delete" ON ingredient_size_prices
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.ruolo = 'manager'
    )
  );

-- Create index for faster lookups
CREATE INDEX idx_ingredient_size_prices_ingredient_id ON ingredient_size_prices(ingredient_id);
CREATE INDEX idx_ingredient_size_prices_size_id ON ingredient_size_prices(size_id);

-- Add comment
COMMENT ON TABLE ingredient_size_prices IS 'Stores ingredient prices per size variant. Each ingredient can have different prices for each size.';
