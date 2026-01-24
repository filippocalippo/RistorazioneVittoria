-- Fix infinite recursion in profiles policies

-- 1. Create a secure function to get the current user's role
-- This bypasses RLS on profiles table to avoid recursion
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT ruolo
    FROM public.profiles
    WHERE id = auth.uid()
  );
END;
$$;

-- 2. Drop problematic policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Managers can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users and managers can update profiles" ON public.profiles;

-- 3. Recreate policies using the secure function

-- SELECT: Users can see their own profile, OR Managers/Staff can see ALL profiles
CREATE POLICY "View profiles policy"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  id = auth.uid() OR
  get_my_role() IN ('manager', 'kitchen', 'delivery')
);

-- UPDATE: Users can update own, Managers can update all
CREATE POLICY "Update profiles policy"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  id = auth.uid() OR
  get_my_role() = 'manager'
)
WITH CHECK (
  id = auth.uid() OR
  get_my_role() = 'manager'
);
