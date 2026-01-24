-- Create delivery zones table for geographic area management
-- This allows managers to define delivery zones with custom colors and names
-- Orders within zones will be visually marked with zone colors

CREATE TABLE IF NOT EXISTS delivery_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    color_hex TEXT NOT NULL CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    polygon JSONB NOT NULL, -- Array of {lat, lng} points
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_delivery_zones_active ON delivery_zones(is_active);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_order ON delivery_zones(display_order);

-- Trigger to update updated_at on modification
CREATE OR REPLACE FUNCTION update_delivery_zones_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delivery_zones_updated_at
    BEFORE UPDATE ON delivery_zones
    FOR EACH ROW
    EXECUTE FUNCTION update_delivery_zones_updated_at();

-- RLS policies (adjust based on your auth setup)
ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read zones
CREATE POLICY "Allow read access to delivery zones"
    ON delivery_zones FOR SELECT
    USING (auth.role() = 'authenticated');

-- Allow managers to create/update/delete zones
CREATE POLICY "Allow managers to manage delivery zones"
    ON delivery_zones FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.ruolo IN ('manager', 'admin')
        )
    );

-- Add helpful comments
COMMENT ON TABLE delivery_zones IS 'Delivery zones for geographic area management and order visualization';
COMMENT ON COLUMN delivery_zones.polygon IS 'Array of latitude/longitude coordinate objects forming the zone polygon';
COMMENT ON COLUMN delivery_zones.color_hex IS 'Hex color code (e.g., #FF5733) for zone visualization';
COMMENT ON COLUMN delivery_zones.display_order IS 'Order priority for overlapping zones (higher = takes precedence)';
