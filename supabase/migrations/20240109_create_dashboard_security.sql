-- Create the security table
CREATE TABLE IF NOT EXISTS public.dashboard_security (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    password_hash text NOT NULL,
    salt text NOT NULL, -- Random salt for extra security
    recovery_hashes jsonb DEFAULT '[]'::jsonb, -- Array of hashed recovery codes
    is_active boolean DEFAULT true,
    last_updated_at timestamp with time zone DEFAULT now(),
    updated_by uuid, -- Reference to the manager who updated it
    CONSTRAINT dashboard_security_pkey PRIMARY KEY (id)
);

-- Add RLS Policies
ALTER TABLE public.dashboard_security ENABLE ROW LEVEL SECURITY;

-- Policy: Only managers can VIEW the security settings
CREATE POLICY "Managers can view security settings" 
ON public.dashboard_security 
FOR SELECT 
USING (
  auth.uid() IN (
    SELECT id FROM public.profiles WHERE ruolo = 'manager'
  )
);

-- Policy: Only managers can UPDATE the security settings
CREATE POLICY "Managers can update security settings" 
ON public.dashboard_security 
FOR UPDATE 
USING (
  auth.uid() IN (
    SELECT id FROM public.profiles WHERE ruolo = 'manager'
  )
);

-- Policy: Only managers can INSERT (initial setup)
CREATE POLICY "Managers can insert security settings" 
ON public.dashboard_security 
FOR INSERT 
WITH CHECK (
  auth.uid() IN (
    SELECT id FROM public.profiles WHERE ruolo = 'manager'
  )
);
