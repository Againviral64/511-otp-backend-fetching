-- ====================================================================
--   RUN THIS SQL IN YOUR SUPABASE PROJECT'S SQL EDITOR:
-- ====================================================================

-- 1. Create fake_data table to control dashboard metric percentages
CREATE TABLE IF NOT EXISTS public.fake_data (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  key VARCHAR(100) NOT NULL UNIQUE,
  value DECIMAL(10, 2) NOT NULL DEFAULT 100.00,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT fake_data_pkey PRIMARY KEY (id)
);

-- 2. Seed multipliers (100.00 = 100% actual data)
INSERT INTO public.fake_data (key, value) VALUES
  ('overall_percentage', 100.00),      -- Master overall percentage factor
  ('orders_percentage', 100.00),       -- Controls Orders/Revenue/Cost/Profit Today (or range)
  ('lifetime_percentage', 100.00),     -- Controls Lifetime Orders/Revenue/Cost/Profit
  ('liability_percentage', 100.00)     -- Controls Total Users Credit Liability & User insights
ON CONFLICT (key) DO NOTHING;
