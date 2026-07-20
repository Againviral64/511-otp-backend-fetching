-- ====================================================================
--   RUN THIS IN YOUR SUPABASE PROJECT'S SQL EDITOR (THIS DROPS ALL ORDERS TRIGGERS):
-- ====================================================================

-- Dynamic PL/pgSQL block to find and drop EVERY trigger on public.orders automatically
DO $$ 
DECLARE 
    trg RECORD;
BEGIN 
    FOR trg IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'orders' 
    LOOP 
        EXECUTE 'DROP TRIGGER IF EXISTS "' || trg.trigger_name || '" ON public.orders CASCADE;'; 
    END LOOP; 
END $$;

-- Enable RLS and set open permissions for public.orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow users to read own orders" ON public.orders;
DROP POLICY IF EXISTS "Allow users to insert own orders" ON public.orders;
DROP POLICY IF EXISTS "Allow admin to update orders" ON public.orders;
DROP POLICY IF EXISTS "Allow public/users to read orders" ON public.orders;
DROP POLICY IF EXISTS "Allow users/system to insert orders" ON public.orders;
DROP POLICY IF EXISTS "Allow system/admin to update orders" ON public.orders;

CREATE POLICY "Allow public/users to read orders" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Allow users/system to insert orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow system/admin to update orders" ON public.orders FOR UPDATE USING (true);
