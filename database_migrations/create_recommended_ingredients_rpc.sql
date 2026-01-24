-- Migration: Create RPC function for recommended ingredients
-- Description: Creates a PostgreSQL function that efficiently retrieves the most added 
--              ingredients for a specific product and globally, limited to the last 2 months.
-- Author: Auto-generated
-- Date: 2024-12-10

-- Drop existing function if exists (for re-application)
DROP FUNCTION IF EXISTS get_recommended_ingredients(TEXT, INT, INT);
DROP FUNCTION IF EXISTS get_recommended_ingredients(UUID, INT, INT);

-- Create the optimized function for recommended ingredients
CREATE OR REPLACE FUNCTION get_recommended_ingredients(
  p_menu_item_id UUID DEFAULT NULL,
  p_product_limit INT DEFAULT 6,
  p_global_limit INT DEFAULT 20
)
RETURNS TABLE (
  ingredient_id TEXT,
  ingredient_name TEXT,
  add_count BIGINT,
  source TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cutoff_date TIMESTAMPTZ := NOW() - INTERVAL '2 months';
BEGIN
  -- Return product-specific top ingredients first, then global
  RETURN QUERY
  WITH order_items_filtered AS (
    -- Pre-filter order items from last 2 months with non-cancelled orders
    SELECT 
      oi.varianti,
      oi.quantita,
      oi.menu_item_id
    FROM ordini_items oi
    INNER JOIN ordini o ON o.id = oi.ordine_id
    WHERE o.stato != 'cancelled'
      AND COALESCE(o.slot_prenotato_start, o.created_at) >= v_cutoff_date
  ),
  added_ingredients AS (
    -- Unnest and extract added ingredients
    SELECT 
      oif.menu_item_id,
      (ing_json->>'id')::TEXT AS ing_id,
      (ing_json->>'name')::TEXT AS ing_name,
      oif.quantita
    FROM order_items_filtered oif,
         jsonb_array_elements(
           COALESCE((oif.varianti->'addedIngredients')::jsonb, '[]'::jsonb)
         ) AS ing_json
    WHERE oif.varianti IS NOT NULL
      AND oif.varianti ? 'addedIngredients'
  ),
  product_specific AS (
    -- Top ingredients for the specific product
    SELECT 
      ai.ing_id,
      ai.ing_name,
      SUM(ai.quantita)::BIGINT AS total_count,
      'product'::TEXT AS src
    FROM added_ingredients ai
    WHERE p_menu_item_id IS NOT NULL 
      AND ai.menu_item_id = p_menu_item_id
    GROUP BY ai.ing_id, ai.ing_name
    ORDER BY total_count DESC
    LIMIT p_product_limit
  ),
  global_top AS (
    -- Top ingredients globally (excluding those already in product-specific)
    SELECT 
      ai.ing_id,
      ai.ing_name,
      SUM(ai.quantita)::BIGINT AS total_count,
      'global'::TEXT AS src
    FROM added_ingredients ai
    WHERE NOT EXISTS (
      SELECT 1 FROM product_specific ps WHERE ps.ing_id = ai.ing_id
    )
    GROUP BY ai.ing_id, ai.ing_name
    ORDER BY total_count DESC
    LIMIT p_global_limit
  )
  -- Combine product-specific first, then global
  SELECT ps.ing_id, ps.ing_name, ps.total_count, ps.src FROM product_specific ps
  UNION ALL
  SELECT gt.ing_id, gt.ing_name, gt.total_count, gt.src FROM global_top gt;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_recommended_ingredients(UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recommended_ingredients(UUID, INT, INT) TO anon;

-- Add comment for documentation
COMMENT ON FUNCTION get_recommended_ingredients IS 
  'Returns recommended ingredients for product customization. 
   First returns top N product-specific ingredients, then top M global ingredients (no duplicates).
   Limited to last 2 months of order data for performance.';
