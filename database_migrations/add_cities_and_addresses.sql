-- Migration: Add support for allowed cities and multiple user addresses
-- This migration adds two new tables:
-- 1. allowed_cities: Cities where the pizzeria delivers
-- 2. user_addresses: Multiple addresses per user

-- ============================================
-- Table: allowed_cities
-- Stores the cities where each pizzeria delivers
-- ============================================
CREATE TABLE IF NOT EXISTS public.allowed_cities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pizzeria_id uuid NOT NULL,
  nome text NOT NULL,
  cap text NOT NULL,
  attiva boolean DEFAULT true,
  ordine integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT allowed_cities_pkey PRIMARY KEY (id),
  CONSTRAINT allowed_cities_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) 
    REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT allowed_cities_unique_city_per_pizzeria UNIQUE (pizzeria_id, nome, cap)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_allowed_cities_pizzeria_id ON public.allowed_cities(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_allowed_cities_attiva ON public.allowed_cities(attiva);

-- ============================================
-- Table: user_addresses
-- Stores multiple addresses per user
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_addresses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  pizzeria_id uuid NOT NULL,
  allowed_city_id uuid,
  etichetta text,
  indirizzo text NOT NULL,
  citta text NOT NULL,
  cap text NOT NULL,
  note text,
  is_default boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_addresses_pkey PRIMARY KEY (id),
  CONSTRAINT user_addresses_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT user_addresses_pizzeria_id_fkey FOREIGN KEY (pizzeria_id) 
    REFERENCES public.pizzerie(id) ON DELETE CASCADE,
  CONSTRAINT user_addresses_allowed_city_id_fkey FOREIGN KEY (allowed_city_id) 
    REFERENCES public.allowed_cities(id) ON DELETE SET NULL
);

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_user_addresses_user_id ON public.user_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_addresses_pizzeria_id ON public.user_addresses(pizzeria_id);
CREATE INDEX IF NOT EXISTS idx_user_addresses_is_default ON public.user_addresses(is_default);

-- ============================================
-- Function: Ensure only one default address per user
-- ============================================
CREATE OR REPLACE FUNCTION ensure_single_default_address()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default = true THEN
    -- Set all other addresses for this user to non-default
    UPDATE public.user_addresses
    SET is_default = false
    WHERE user_id = NEW.user_id 
      AND id != NEW.id
      AND is_default = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce single default address
DROP TRIGGER IF EXISTS trigger_ensure_single_default_address ON public.user_addresses;
CREATE TRIGGER trigger_ensure_single_default_address
  BEFORE INSERT OR UPDATE ON public.user_addresses
  FOR EACH ROW
  EXECUTE FUNCTION ensure_single_default_address();

-- ============================================
-- RLS (Row Level Security) Policies
-- ============================================

-- Enable RLS
ALTER TABLE public.allowed_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

-- Policies for allowed_cities
-- Managers can manage cities for their pizzeria
CREATE POLICY "Managers can view their pizzeria's cities"
  ON public.allowed_cities FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = allowed_cities.pizzeria_id
        AND profiles.ruolo IN ('manager', 'kitchen', 'delivery')
    )
  );

CREATE POLICY "Managers can insert cities for their pizzeria"
  ON public.allowed_cities FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = allowed_cities.pizzeria_id
        AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can update their pizzeria's cities"
  ON public.allowed_cities FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = allowed_cities.pizzeria_id
        AND profiles.ruolo = 'manager'
    )
  );

CREATE POLICY "Managers can delete their pizzeria's cities"
  ON public.allowed_cities FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = allowed_cities.pizzeria_id
        AND profiles.ruolo = 'manager'
    )
  );

-- Customers can view active cities for their pizzeria
CREATE POLICY "Customers can view active cities"
  ON public.allowed_cities FOR SELECT
  USING (
    attiva = true AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = allowed_cities.pizzeria_id
        AND profiles.ruolo = 'customer'
    )
  );

-- Policies for user_addresses
-- Users can view their own addresses
CREATE POLICY "Users can view their own addresses"
  ON public.user_addresses FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own addresses
CREATE POLICY "Users can insert their own addresses"
  ON public.user_addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own addresses
CREATE POLICY "Users can update their own addresses"
  ON public.user_addresses FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own addresses
CREATE POLICY "Users can delete their own addresses"
  ON public.user_addresses FOR DELETE
  USING (auth.uid() = user_id);

-- Staff can view addresses for orders in their pizzeria
CREATE POLICY "Staff can view addresses for their pizzeria"
  ON public.user_addresses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.pizzeria_id = user_addresses.pizzeria_id
        AND profiles.ruolo IN ('manager', 'kitchen', 'delivery')
    )
  );

-- ============================================
-- Comments for documentation
-- ============================================
COMMENT ON TABLE public.allowed_cities IS 'Cities where each pizzeria delivers';
COMMENT ON TABLE public.user_addresses IS 'Multiple delivery addresses per user';
COMMENT ON COLUMN public.user_addresses.etichetta IS 'Label for the address (e.g., Casa, Lavoro, etc.)';
COMMENT ON COLUMN public.user_addresses.is_default IS 'Whether this is the default delivery address';
COMMENT ON COLUMN public.user_addresses.allowed_city_id IS 'Reference to allowed city (optional, for validation)';
