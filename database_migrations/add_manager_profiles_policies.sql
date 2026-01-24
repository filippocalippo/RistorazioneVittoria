-- Add RLS policies for managers to view and alter all profiles
-- This allows managers to see all staff and customers in the staff screen

-- Policy: Managers can view all profiles
CREATE POLICY "Managers can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  -- Allow if the current user is a manager
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND ruolo = 'manager'
  )
);

-- Policy: Managers can update all profiles
CREATE POLICY "Managers can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  -- Allow if the current user is a manager
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND ruolo = 'manager'
  )
)
WITH CHECK (
  -- Allow if the current user is a manager
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND ruolo = 'manager'
  )
);
