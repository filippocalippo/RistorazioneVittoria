-- ============================================================================
-- PROMOTIONAL BANNERS SYSTEM - Database Migration
-- ============================================================================
-- Description: Complete database schema for banner/sponsorship carousel system
-- Author: System
-- Created: 2024
-- ============================================================================

-- ============================================================================
-- TABLE: promotional_banners
-- ============================================================================
-- Purpose: Store promotional banners, sponsorships, and internal promotions
-- Features: Scheduling, analytics, device targeting, text overlays
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.promotional_banners (
  -- Primary Key
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  
  -- Basic Information
  titolo text NOT NULL,
  descrizione text,
  immagine_url text NOT NULL,
  
  -- Action Configuration
  -- Defines what happens when user taps the banner
  action_type text NOT NULL CHECK (
    action_type = ANY (ARRAY[
      'external_link',      -- Open external URL (sponsors, partners)
      'internal_route',     -- Navigate to app route
      'product',            -- Link to specific menu item
      'category',           -- Navigate to category
      'special_offer',      -- Show special promotion/offer
      'none'                -- Informational only, no action
    ])
  ),
  
  -- Action data stored as JSONB for flexibility
  -- Structure depends on action_type:
  -- 
  -- external_link: {"url": "https://example.com", "open_in_browser": true}
  -- internal_route: {"route": "/menu", "params": {"categoryId": "uuid"}}
  -- product: {"product_id": "uuid", "open_modal": true, "auto_add_to_cart": false}
  -- category: {"category_id": "uuid", "scroll_to_top": true}
  -- special_offer: {"offer_id": "uuid", "promo_code": "SUMMER24", "discount_percentage": 20, "apply_to_cart": true}
  -- none: {}
  action_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  
  -- Text Overlay Configuration (optional)
  -- Allows adding text content over the banner image
  text_overlay jsonb DEFAULT '{
    "enabled": false,
    "title": "",
    "subtitle": "",
    "cta_text": "",
    "text_color": "#FFFFFF",
    "overlay_gradient": ["rgba(0,0,0,0.5)", "rgba(0,0,0,0)"]
  }'::jsonb,
  
  -- Status & Scheduling
  attivo boolean DEFAULT true,
  data_inizio timestamp with time zone,
  data_fine timestamp with time zone,
  
  -- Priority & Display Order
  -- Higher priority banners show first
  -- Same priority uses ordine for sorting
  priorita integer DEFAULT 0,
  ordine integer DEFAULT 0,
  
  -- Device Targeting
  -- Control which devices show which banners
  mostra_solo_mobile boolean DEFAULT false,
  mostra_solo_desktop boolean DEFAULT false,
  
  -- Analytics & Metrics
  visualizzazioni integer DEFAULT 0,
  click integer DEFAULT 0,
  
  -- Sponsorship Information (optional)
  is_sponsorizzato boolean DEFAULT false,
  sponsor_nome text,
  sponsor_logo_url text,
  
  -- Metadata
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id),
  
  -- Constraints
  CONSTRAINT promotional_banners_pkey PRIMARY KEY (id),
  CONSTRAINT valid_date_range CHECK (
    data_inizio IS NULL OR 
    data_fine IS NULL OR 
    data_fine >= data_inizio
  )
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Optimize query performance for common access patterns

-- Index for active banner queries (most common)
CREATE INDEX IF NOT EXISTS idx_promotional_banners_attivo 
  ON public.promotional_banners(attivo) 
  WHERE attivo = true;

-- Index for priority and ordering
CREATE INDEX IF NOT EXISTS idx_promotional_banners_priority_order 
  ON public.promotional_banners(priorita DESC, ordine ASC);

-- Index for date range queries
CREATE INDEX IF NOT EXISTS idx_promotional_banners_date_range 
  ON public.promotional_banners(data_inizio, data_fine);

-- Index for device targeting queries
CREATE INDEX IF NOT EXISTS idx_promotional_banners_device_targeting 
  ON public.promotional_banners(mostra_solo_mobile, mostra_solo_desktop);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_promotional_banners_analytics 
  ON public.promotional_banners(visualizzazioni, click);

-- Index for creator queries
CREATE INDEX IF NOT EXISTS idx_promotional_banners_creator 
  ON public.promotional_banners(created_by);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- Secure data access based on user roles

-- Enable RLS
ALTER TABLE public.promotional_banners ENABLE ROW LEVEL SECURITY;

-- Policy 1: Public can view active banners within date range
CREATE POLICY "Banners pubblici visibili a tutti"
  ON public.promotional_banners
  FOR SELECT
  USING (
    attivo = true
    AND (data_inizio IS NULL OR data_inizio <= now())
    AND (data_fine IS NULL OR data_fine >= now())
  );

-- Policy 2: Managers can view all banners (for management interface)
CREATE POLICY "Manager possono vedere tutti i banner"
  ON public.promotional_banners
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND ruolo = 'manager'
    )
  );

-- Policy 3: Managers can insert banners
CREATE POLICY "Manager possono creare banner"
  ON public.promotional_banners
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND ruolo = 'manager'
    )
  );

-- Policy 4: Managers can update banners
CREATE POLICY "Manager possono modificare banner"
  ON public.promotional_banners
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND ruolo = 'manager'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND ruolo = 'manager'
    )
  );

-- Policy 5: Managers can delete banners
CREATE POLICY "Manager possono eliminare banner"
  ON public.promotional_banners
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND ruolo = 'manager'
    )
  );

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger: Update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_promotional_banners_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_promotional_banners_updated_at
  BEFORE UPDATE ON public.promotional_banners
  FOR EACH ROW
  EXECUTE FUNCTION update_promotional_banners_updated_at();

-- Trigger: Set created_by to current user on insert
CREATE OR REPLACE FUNCTION set_promotional_banner_creator()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.created_by IS NULL THEN
    NEW.created_by = auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_promotional_banner_creator
  BEFORE INSERT ON public.promotional_banners
  FOR EACH ROW
  EXECUTE FUNCTION set_promotional_banner_creator();

-- ============================================================================
-- ANALYTICS FUNCTIONS
-- ============================================================================

-- Function: Increment banner view count
-- Usage: Called when banner is displayed to user
CREATE OR REPLACE FUNCTION increment_banner_view(banner_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.promotional_banners
  SET visualizzazioni = visualizzazioni + 1
  WHERE id = banner_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Increment banner click count
-- Usage: Called when user taps/clicks banner
CREATE OR REPLACE FUNCTION increment_banner_click(banner_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.promotional_banners
  SET click = click + 1
  WHERE id = banner_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get banner analytics with CTR calculation
-- Usage: Dashboard analytics and reporting
CREATE OR REPLACE FUNCTION get_banner_analytics(
  start_date timestamp with time zone DEFAULT NULL,
  end_date timestamp with time zone DEFAULT NULL
)
RETURNS TABLE (
  banner_id uuid,
  titolo text,
  immagine_url text,
  attivo boolean,
  data_inizio timestamp with time zone,
  data_fine timestamp with time zone,
  visualizzazioni bigint,
  click bigint,
  ctr numeric,
  is_sponsorizzato boolean,
  sponsor_nome text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pb.id,
    pb.titolo,
    pb.immagine_url,
    pb.attivo,
    pb.data_inizio,
    pb.data_fine,
    pb.visualizzazioni::bigint,
    pb.click::bigint,
    CASE 
      WHEN pb.visualizzazioni > 0 
      THEN ROUND((pb.click::numeric / pb.visualizzazioni::numeric) * 100, 2)
      ELSE 0
    END as ctr,
    pb.is_sponsorizzato,
    pb.sponsor_nome,
    pb.created_at
  FROM public.promotional_banners pb
  WHERE 
    (start_date IS NULL OR pb.created_at >= start_date)
    AND (end_date IS NULL OR pb.created_at <= end_date)
  ORDER BY pb.priorita DESC, pb.ordine ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get top performing banners
CREATE OR REPLACE FUNCTION get_top_performing_banners(
  limit_count integer DEFAULT 10,
  metric text DEFAULT 'ctr'  -- 'ctr', 'views', 'clicks'
)
RETURNS TABLE (
  banner_id uuid,
  titolo text,
  visualizzazioni integer,
  click integer,
  ctr numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pb.id,
    pb.titolo,
    pb.visualizzazioni,
    pb.click,
    CASE 
      WHEN pb.visualizzazioni > 0 
      THEN ROUND((pb.click::numeric / pb.visualizzazioni::numeric) * 100, 2)
      ELSE 0
    END as ctr
  FROM public.promotional_banners pb
  WHERE pb.attivo = true
  ORDER BY 
    CASE metric
      WHEN 'ctr' THEN 
        CASE WHEN pb.visualizzazioni > 0 
        THEN (pb.click::numeric / pb.visualizzazioni::numeric)
        ELSE 0 END
      WHEN 'views' THEN pb.visualizzazioni::numeric
      WHEN 'clicks' THEN pb.click::numeric
      ELSE 0
    END DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Reset banner analytics
-- Usage: Reset metrics for testing or new campaigns
CREATE OR REPLACE FUNCTION reset_banner_analytics(banner_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.promotional_banners
  SET 
    visualizzazioni = 0,
    click = 0
  WHERE id = banner_id
  AND EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
    AND ruolo = 'manager'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function: Get currently active banners
-- Returns banners that should be displayed right now
CREATE OR REPLACE FUNCTION get_active_banners_now()
RETURNS SETOF public.promotional_banners AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public.promotional_banners
  WHERE 
    attivo = true
    AND (data_inizio IS NULL OR data_inizio <= now())
    AND (data_fine IS NULL OR data_fine >= now())
  ORDER BY priorita DESC, ordine ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Duplicate banner
-- Creates a copy of existing banner for A/B testing or variations
CREATE OR REPLACE FUNCTION duplicate_banner(
  source_banner_id uuid,
  new_title text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  new_banner_id uuid;
BEGIN
  INSERT INTO public.promotional_banners (
    titolo,
    descrizione,
    immagine_url,
    action_type,
    action_data,
    text_overlay,
    attivo,
    priorita,
    ordine,
    mostra_solo_mobile,
    mostra_solo_desktop,
    is_sponsorizzato,
    sponsor_nome,
    sponsor_logo_url
  )
  SELECT 
    COALESCE(new_title, titolo || ' (Copia)'),
    descrizione,
    immagine_url,
    action_type,
    action_data,
    text_overlay,
    false,  -- Start as inactive
    priorita,
    ordine + 1,  -- Place after original
    mostra_solo_mobile,
    mostra_solo_desktop,
    is_sponsorizzato,
    sponsor_nome,
    sponsor_logo_url
  FROM public.promotional_banners
  WHERE id = source_banner_id
  RETURNING id INTO new_banner_id;
  
  RETURN new_banner_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INITIAL DATA (Optional)
-- ============================================================================
-- Uncomment to add sample banners for testing

/*
-- Sample: Welcome banner
INSERT INTO public.promotional_banners (
  titolo,
  descrizione,
  immagine_url,
  action_type,
  action_data,
  text_overlay,
  attivo,
  priorita,
  ordine
) VALUES (
  'Benvenuto nella nostra Pizzeria!',
  'Scopri le nostre specialità e ordina online',
  'https://example.com/welcome-banner.jpg',
  'internal_route',
  '{"route": "/menu", "params": {}}'::jsonb,
  '{
    "enabled": true,
    "title": "Benvenuto!",
    "subtitle": "Ordina online e ricevi a casa",
    "cta_text": "Scopri il Menu",
    "text_color": "#FFFFFF",
    "overlay_gradient": ["rgba(0,0,0,0.6)", "rgba(0,0,0,0)"]
  }'::jsonb,
  true,
  100,
  1
);

-- Sample: Category promotion
INSERT INTO public.promotional_banners (
  titolo,
  descrizione,
  immagine_url,
  action_type,
  action_data,
  attivo,
  priorita,
  ordine
) VALUES (
  'Nuove Pizze Speciali',
  'Prova le nostre ultime creazioni',
  'https://example.com/special-pizzas.jpg',
  'category',
  '{"category_id": "uuid-here", "scroll_to_top": true}'::jsonb,
  true,
  90,
  2
);
*/

-- ============================================================================
-- GRANTS & PERMISSIONS
-- ============================================================================

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION increment_banner_view(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_banner_click(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_banners_now() TO authenticated;

-- Grant execute permissions on management functions to authenticated users
-- (RLS policies will ensure only managers can actually use them)
GRANT EXECUTE ON FUNCTION get_banner_analytics(timestamp with time zone, timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_performing_banners(integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION reset_banner_analytics(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION duplicate_banner(uuid, text) TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.promotional_banners IS 
  'Stores promotional banners, sponsorships, and internal promotions for the customer-facing app. ' ||
  'Supports scheduling, device targeting, text overlays, and comprehensive analytics tracking.';

COMMENT ON COLUMN public.promotional_banners.action_type IS 
  'Type of action when banner is tapped: external_link, internal_route, product, category, special_offer, or none';

COMMENT ON COLUMN public.promotional_banners.action_data IS 
  'JSONB configuration for the action. Structure varies by action_type. See migration file for examples.';

COMMENT ON COLUMN public.promotional_banners.priorita IS 
  'Display priority. Higher numbers show first. Use for featured/urgent content.';

COMMENT ON COLUMN public.promotional_banners.ordine IS 
  'Display order within same priority level. Lower numbers show first.';

COMMENT ON FUNCTION increment_banner_view(uuid) IS 
  'Increment view count when banner is displayed. Call from client app.';

COMMENT ON FUNCTION increment_banner_click(uuid) IS 
  'Increment click count when banner is tapped. Call from client app.';

COMMENT ON FUNCTION get_banner_analytics(timestamp with time zone, timestamp with time zone) IS 
  'Get comprehensive analytics for all banners including CTR calculations. For manager dashboard.';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
