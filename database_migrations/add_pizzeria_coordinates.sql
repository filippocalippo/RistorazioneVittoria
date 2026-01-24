-- Add geocoding coordinates to pizzerie table
-- This allows caching of pizzeria location coordinates

-- Add latitude and longitude to pizzerie
ALTER TABLE public.pizzerie
ADD COLUMN IF NOT EXISTS latitude numeric,
ADD COLUMN IF NOT EXISTS longitude numeric;

-- Add index for faster lookups on coordinates
CREATE INDEX IF NOT EXISTS idx_pizzerie_coordinates 
ON public.pizzerie (latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Add comment to explain the purpose
COMMENT ON COLUMN public.pizzerie.latitude IS 'Cached geocoded latitude for the pizzeria location';
COMMENT ON COLUMN public.pizzerie.longitude IS 'Cached geocoded longitude for the pizzeria location';
