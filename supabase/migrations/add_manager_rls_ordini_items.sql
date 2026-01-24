-- Enable RLS on ordini_items if not already enabled
ALTER TABLE ordini_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Managers can do everything on ordini_items" ON ordini_items;

-- Create policy for managers to have full access (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Managers can do everything on ordini_items"
ON ordini_items
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.ruolo = 'manager'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.ruolo = 'manager'
  )
);
