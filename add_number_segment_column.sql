-- ====================================================================
--   RUN THIS SQL IN YOUR SUPABASE PROJECT'S SQL EDITOR:
--   Adds number_segment column to public.services table
-- ====================================================================

ALTER TABLE public.services ADD COLUMN IF NOT EXISTS number_segment VARCHAR(100) DEFAULT NULL;
