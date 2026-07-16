-- ====================================================================
--   RUN THIS SQL IN YOUR SUPABASE PROJECT'S SQL EDITOR:
-- ====================================================================

-- 1. Add cost_price column to public.orders table (unit cost in USD)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cost_price DECIMAL(15, 3) NOT NULL DEFAULT 0.000;

-- 2. Backfill existing orders' cost_price by matching with services table
UPDATE public.orders o
SET cost_price = COALESCE(s.cost_price, 0.020)
FROM public.services s
WHERE o.product_id = s.service_id;

-- Also set a general fallback for any orders that didn't match (e.g. product_id '243' which was missing before)
UPDATE public.orders
SET cost_price = 0.020
WHERE cost_price = 0.000 OR cost_price IS NULL;

-- 3. Recreate the admin_overview view using the new orders.cost_price column
CREATE OR REPLACE VIEW public.admin_overview AS
SELECT 
  -- Total user balance liability
  (SELECT COALESCE(SUM(balance), 0) FROM public.profiles) as total_liability,
  
  -- Orders today (Karachi Timezone reset)
  (SELECT COUNT(*) FROM public.orders 
   WHERE (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as orders_today,
  
  -- Revenue today (sum of price for completed orders today, Karachi Timezone reset)
  (SELECT COALESCE(SUM(price), 0) FROM public.orders 
   WHERE status = 'COMPLETED' 
     AND (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as revenue_today,
  
  -- Cost today (dynamically using exchange_rate_PKR with 278.50 fallback, Karachi Timezone reset)
  (SELECT COALESCE(SUM(cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders
   WHERE status = 'COMPLETED' 
     AND (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as cost_today,

  -- Profit today (revenue - cost today)
  (SELECT COALESCE(SUM(price), 0) FROM public.orders 
    WHERE status = 'COMPLETED' 
      AND (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) -
  (SELECT COALESCE(SUM(cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders
   WHERE status = 'COMPLETED' 
     AND (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as profit_today,
  
  -- Lifetime orders
  (SELECT COUNT(*) FROM public.orders) as orders_lifetime,
  
  -- Lifetime revenue
  (SELECT COALESCE(SUM(price), 0) FROM public.orders WHERE status = 'COMPLETED') as revenue_lifetime,
  
  -- Lifetime cost
  (SELECT COALESCE(SUM(cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders
   WHERE status = 'COMPLETED') as cost_lifetime,

  -- Lifetime profit
  (SELECT COALESCE(SUM(price), 0) FROM public.orders WHERE status = 'COMPLETED') -
  (SELECT COALESCE(SUM(cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders
   WHERE status = 'COMPLETED') as profit_lifetime;

-- 4. Create high-performance RPC function to get range stats (aggregates inside Postgres to bypass REST 1000 row limits)
CREATE OR REPLACE FUNCTION public.get_range_stats(start_time timestamptz, end_time timestamptz)
RETURNS TABLE (
  total_orders bigint,
  completed_orders bigint,
  total_revenue numeric,
  total_cost_usd numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_orders,
    COUNT(*) FILTER (WHERE status = 'COMPLETED')::bigint as completed_orders,
    COALESCE(SUM(price) FILTER (WHERE status = 'COMPLETED'), 0)::numeric as total_revenue,
    COALESCE(SUM(cost_price) FILTER (WHERE status = 'COMPLETED'), 0)::numeric as total_cost_usd
  FROM public.orders
  WHERE created_at >= start_time AND created_at <= end_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create high-performance RPC function to get daily chart stats grouped by Karachi date
CREATE OR REPLACE FUNCTION public.get_daily_stats(start_time timestamptz)
RETURNS TABLE (
  date_label text,
  total_orders bigint,
  total_revenue numeric,
  total_cost_usd numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (created_at AT TIME ZONE 'Asia/Karachi')::date::text as date_label,
    COUNT(*)::bigint as total_orders,
    COALESCE(SUM(price) FILTER (WHERE status = 'COMPLETED'), 0)::numeric as total_revenue,
    COALESCE(SUM(cost_price) FILTER (WHERE status = 'COMPLETED'), 0)::numeric as total_cost_usd
  FROM public.orders
  WHERE created_at >= start_time
  GROUP BY (created_at AT TIME ZONE 'Asia/Karachi')::date
  ORDER BY (created_at AT TIME ZONE 'Asia/Karachi')::date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create high-performance RPC function to get daily signups grouped by Karachi date
CREATE OR REPLACE FUNCTION public.get_daily_signups(start_time timestamptz)
RETURNS TABLE (
  date_label text,
  total_signups bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (created_at AT TIME ZONE 'Asia/Karachi')::date::text as date_label,
    COUNT(*)::bigint as total_signups
  FROM public.profiles
  WHERE created_at >= start_time
  GROUP BY (created_at AT TIME ZONE 'Asia/Karachi')::date
  ORDER BY (created_at AT TIME ZONE 'Asia/Karachi')::date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
