-- Add geocoding coordinates to user_addresses and ordini tables
-- This allows caching of geocoded locations to reduce API calls

-- Add latitude and longitude to user_addresses
ALTER TABLE public.user_addresses
ADD COLUMN IF NOT EXISTS latitude numeric,
ADD COLUMN IF NOT EXISTS longitude numeric;

-- Add index for faster lookups on coordinates
CREATE INDEX IF NOT EXISTS idx_user_addresses_coordinates 
ON public.user_addresses (latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Add latitude and longitude to ordini for delivery orders
ALTER TABLE public.ordini
ADD COLUMN IF NOT EXISTS latitude_consegna numeric,
ADD COLUMN IF NOT EXISTS longitude_consegna numeric;

-- Add index for faster lookups on delivery coordinates
CREATE INDEX IF NOT EXISTS idx_ordini_delivery_coordinates 
ON public.ordini (latitude_consegna, longitude_consegna) 
WHERE latitude_consegna IS NOT NULL AND longitude_consegna IS NOT NULL;

-- Add comment to explain the purpose
COMMENT ON COLUMN public.user_addresses.latitude IS 'Cached geocoded latitude for the address';
COMMENT ON COLUMN public.user_addresses.longitude IS 'Cached geocoded longitude for the address';
COMMENT ON COLUMN public.ordini.latitude_consegna IS 'Cached geocoded latitude for delivery address';
COMMENT ON COLUMN public.ordini.longitude_consegna IS 'Cached geocoded longitude for delivery address';
