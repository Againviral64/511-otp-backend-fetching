-- ====================================================================
--   RUN THIS SQL IN YOUR SUPABASE PROJECT'S SQL EDITOR:
--   Adds or updates the tracking_domain setting in settings table
-- ====================================================================

INSERT INTO public.settings (key, value)
VALUES ('tracking_domain', 'access.novatixdigi.online')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
