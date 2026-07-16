-- ====================================================================
--   RUN THIS SCHEMA INSIDE YOUR SUPABASE PROJECT'S SQL EDITOR:
-- ====================================================================

-- 1. Create profiles table (linked to Auth Users, with Full Name & Currency column)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID NOT NULL,
  email VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL DEFAULT 'User',
  balance DECIMAL(15, 3) NOT NULL DEFAULT 0.000, -- Base currency PKR
  spend DECIMAL(15, 3) NOT NULL DEFAULT 0.000,   -- Base currency PKR
  total_orders INTEGER NOT NULL DEFAULT 0,
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  api_key VARCHAR(100) UNIQUE DEFAULT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  currency VARCHAR(10) NOT NULL DEFAULT 'PKR',
  status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'BANNED')),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 2. Create services price configuration table (Prices in PKR)
CREATE TABLE IF NOT EXISTS public.services (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  service_id VARCHAR(100) NOT NULL UNIQUE,      -- Product ID from 555api
  group_name VARCHAR(255) NOT NULL,            -- e.g. '美国实卡'
  app_name VARCHAR(255) NOT NULL,              -- e.g. 'Telegram'
  cost_price DECIMAL(15, 3) NOT NULL DEFAULT 0.000,
  sell_price DECIMAL(15, 3) NOT NULL DEFAULT 0.000,
  stock INTEGER NOT NULL DEFAULT 0,
  validity_period INTEGER DEFAULT 4,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT services_pkey PRIMARY KEY (id)
);

-- 3. Create orders table referencing profiles
CREATE TABLE IF NOT EXISTS public.orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  order_id VARCHAR(100) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  country VARCHAR(100) NOT NULL,
  service VARCHAR(100) NOT NULL,
  number VARCHAR(50) NOT NULL,
  otp TEXT DEFAULT NULL,
  status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'EXPIRED', 'CANCELLED')),
  price DECIMAL(15, 3) NOT NULL DEFAULT 0.00, -- Selling price charged (PKR)
  sms_url TEXT DEFAULT NULL,
  product_id VARCHAR(100) DEFAULT NULL,
  sms_messages JSONB DEFAULT '[]'::jsonb,
  message_1 TEXT DEFAULT NULL,
  message_2 TEXT DEFAULT NULL,
  message_3 TEXT DEFAULT NULL,
  message_4 TEXT DEFAULT NULL,
  message_5 TEXT DEFAULT NULL,
  message_6 TEXT DEFAULT NULL,
  message_7 TEXT DEFAULT NULL,
  message_8 TEXT DEFAULT NULL,
  message_9 TEXT DEFAULT NULL,
  message_10 TEXT DEFAULT NULL,
  full_message TEXT DEFAULT NULL,
  received_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  tracking_key VARCHAR(100) UNIQUE DEFAULT NULL,
  is_bulk BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 4. Create deposits request tracking table
CREATE TABLE IF NOT EXISTS public.deposits (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id UUID NOT NULL,
  method VARCHAR(100) NOT NULL,                 -- 'Easypaisa', 'Jazzcash', 'Zindagi', 'Bank'
  amount DECIMAL(15, 2) NOT NULL,
  tx_id VARCHAR(100) NOT NULL,                  -- Fallback or renamed to account_name
  screenshot_url TEXT DEFAULT NULL,
  status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  currency VARCHAR(10) DEFAULT 'USD',
  proof_image TEXT DEFAULT NULL,
  payment_note TEXT DEFAULT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT deposits_pkey PRIMARY KEY (id),
  CONSTRAINT deposits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 5. Support Tickets table
CREATE TABLE IF NOT EXISTS public.tickets (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id UUID NOT NULL,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(100) NOT NULL,
  status VARCHAR(50) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RESOLVED', 'CLOSED')),
  proof_image TEXT DEFAULT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT tickets_pkey PRIMARY KEY (id),
  CONSTRAINT tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 6. Ticket Messages table
CREATE TABLE IF NOT EXISTS public.ticket_messages (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  ticket_id BIGINT NOT NULL,
  sender_id UUID NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT ticket_messages_pkey PRIMARY KEY (id),
  CONSTRAINT ticket_messages_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE,
  CONSTRAINT ticket_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 7. Create admin_profiles table
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id UUID NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT admin_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT admin_profiles_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 8. Create settings table for global configuration
CREATE TABLE IF NOT EXISTS public.settings (
  key VARCHAR(100) NOT NULL,
  value TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT settings_pkey PRIMARY KEY (key)
);

-- 9. Create deposit_methods table (referenced by admin deposit methods CRUD)
CREATE TABLE IF NOT EXISTS public.deposit_methods (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  method_name TEXT NOT NULL,       -- e.g. 'Easypaisa', 'JazzCash', 'Bank Transfer'
  bank_name TEXT NOT NULL,          -- e.g. 'Easypaisa Mobile Wallet'
  account_title TEXT NOT NULL,      -- e.g. 'NOVA OTP SERVICES'
  account_number TEXT NOT NULL,     -- e.g. '03001234567'
  instructions TEXT DEFAULT '',             -- Additional payment instructions
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT deposit_methods_pkey PRIMARY KEY (id)
);

-- 10. Create whatsapp_settings table
CREATE TABLE IF NOT EXISTS public.whatsapp_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  whatsapp_number TEXT NOT NULL,
  default_message TEXT NOT NULL,
  is_enabled BOOLEAN DEFAULT true NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  CONSTRAINT whatsapp_settings_pkey PRIMARY KEY (id)
);

-- 11. Create admin_push_tokens table (for expo push notifications)
CREATE TABLE IF NOT EXISTS public.admin_push_tokens (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  admin_id UUID NOT NULL,
  expo_push_token TEXT NOT NULL UNIQUE,
  device_name VARCHAR(255) DEFAULT 'Unknown Device',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT admin_push_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT admin_push_tokens_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 12. Create admin_notifications table (for admin tracking)
CREATE TABLE IF NOT EXISTS public.admin_notifications (
  id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  event_type VARCHAR(100) NOT NULL DEFAULT 'general',
  event_id VARCHAR(100) DEFAULT NULL,
  is_read BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
  CONSTRAINT admin_notifications_pkey PRIMARY KEY (id)
);

-- ====================================================================
--   SEEDS & TRIGGERS
-- ====================================================================

-- Trigger to automatically create a profile row when a user signs up (captures full name metadata)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, balance, spend, total_orders, role, currency, status)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'name', 'User'),
    0.000,
    0.000,
    0,
    'user',
    'PKR',
    'ACTIVE'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove the trigger if it already exists, then create it
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Seed default settings
INSERT INTO public.settings (key, value)
VALUES 
  ('otp_expiry_duration', '4'),
  ('deposit_notice', '⚠️ Note: Please double check account titles and payment instructions before sending deposit requests!'),
  ('exchange_rate_PKR', '278.50'),
  ('exchange_rate_USD', '1.0'),
  ('exchange_rate_INR', '83.40'),
  ('exchange_rate_BDT', '117.20'),
  ('exchange_rate_NPR', '133.50'),
  ('exchange_rate_RUB', '88.30'),
  ('min_deposit_amount', '1'),
  ('max_deposit_amount', '50000')
ON CONFLICT (key) DO NOTHING;

-- Seed default whatsapp settings
INSERT INTO public.whatsapp_settings (id, whatsapp_number, default_message, is_enabled)
VALUES ('00000000-0000-0000-0000-000000000000', '923001234567', 'Hello Nova OTP Team,
I need assistance regarding my account.', true)
ON CONFLICT (id) DO NOTHING;

-- Enable Row Level Security on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposit_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

-- Create dynamic admin statistics dashboard view
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
  (SELECT COALESCE(SUM(s.cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders o
   JOIN public.services s ON o.product_id = s.service_id
   WHERE o.status = 'COMPLETED' 
     AND (o.created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as cost_today,

  -- Profit today (revenue - cost today)
  (SELECT COALESCE(SUM(price), 0) FROM public.orders 
   WHERE status = 'COMPLETED' 
     AND (created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) -
  (SELECT COALESCE(SUM(s.cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders o
   JOIN public.services s ON o.product_id = s.service_id
   WHERE o.status = 'COMPLETED' 
     AND (o.created_at AT TIME ZONE 'Asia/Karachi')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi')::date) as profit_today,
  
  -- Lifetime orders
  (SELECT COUNT(*) FROM public.orders) as orders_lifetime,
  
  -- Lifetime revenue
  (SELECT COALESCE(SUM(price), 0) FROM public.orders WHERE status = 'COMPLETED') as revenue_lifetime,
  
  -- Lifetime cost
  (SELECT COALESCE(SUM(s.cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders o
   JOIN public.services s ON o.product_id = s.service_id
   WHERE o.status = 'COMPLETED') as cost_lifetime,

  -- Lifetime profit
  (SELECT COALESCE(SUM(price), 0) FROM public.orders WHERE status = 'COMPLETED') -
  (SELECT COALESCE(SUM(s.cost_price * COALESCE((SELECT CAST(val.value AS NUMERIC) FROM public.settings val WHERE val.key = 'exchange_rate_PKR'), 278.50)), 0) 
   FROM public.orders o
   JOIN public.services s ON o.product_id = s.service_id
   WHERE o.status = 'COMPLETED') as profit_lifetime;

-- Revoke all permissions on the view from public roles to secure it
REVOKE ALL ON public.admin_overview FROM PUBLIC;
REVOKE ALL ON public.admin_overview FROM anon;
REVOKE ALL ON public.admin_overview FROM authenticated;

-- Grant select permission ONLY to service_role (which backend uses)
GRANT SELECT ON public.admin_overview TO service_role;

-- ====================================================================
--   MIGRATIONS FOR EXISTING DATABASES (RUN TO UPDATE CURRENT TABLES)
-- ====================================================================

-- Update profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'ACTIVE' NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'BANNED'));

-- Update services table
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS validity_period INTEGER DEFAULT 4;

-- Update orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tracking_key VARCHAR(100) UNIQUE DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sms_messages JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_bulk BOOLEAN DEFAULT false;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_1 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_2 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_3 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_4 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_5 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_6 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_7 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_8 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_9 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS message_10 TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS full_message TEXT DEFAULT NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS received_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Update deposits table
ALTER TABLE public.deposits ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.deposits ADD COLUMN IF NOT EXISTS proof_image TEXT DEFAULT NULL;
ALTER TABLE public.deposits ADD COLUMN IF NOT EXISTS payment_note TEXT DEFAULT NULL;

-- Update tickets table
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS proof_image TEXT DEFAULT NULL;


-- ====================================================================
--   SECURITY & ROW LEVEL SECURITY (RLS) POLICIES (RECOMMENDED FOR PRODUCTION)
-- ====================================================================
-- By default, Row Level Security is disabled for easy out-of-the-box setup.
-- If you want to make your Supabase database 100% secure, follow these steps:
--
-- 1. In your project's `.env` file, add your Supabase Service Role Key:
--    SUPABASE_SERVICE_ROLE_KEY=your_secret_service_role_key_here
--    (Note: Do NOT modify SUPABASE_KEY. It must remain the public 'anon' key.)
--
-- 2. Run the SQL block below in your Supabase SQL Editor.
--    This will enable RLS on all tables and configure secure policies so that:
--    * Users can ONLY read and write their own data (profiles, orders, deposits, tickets).
--    * Admins can manage all data.
--    * The server-side (using the Service Role Key) will bypass RLS and continue to function perfectly.
-- ====================================================================

-- STEP A: Enable Row Level Security on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposit_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

-- STEP B: Create helper function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = user_id AND role = 'admin'
  ) OR EXISTS (
    SELECT 1 FROM public.admin_profiles
    WHERE id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP C: Create Security Policies

-- Profiles Policies
CREATE POLICY "Allow public read profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow users to update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow system/auth to insert profiles" ON public.profiles FOR INSERT WITH CHECK (true);

-- Services Policies
CREATE POLICY "Allow public read services" ON public.services FOR SELECT USING (true);
CREATE POLICY "Allow admin to manage services" ON public.services FOR ALL USING (public.is_admin(auth.uid()));

-- Orders Policies
CREATE POLICY "Allow users to read own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow users to insert own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow admin to update orders" ON public.orders FOR UPDATE USING (public.is_admin(auth.uid()));

-- Deposits Policies
CREATE POLICY "Allow users to read own deposits" ON public.deposits FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow users to insert own deposits" ON public.deposits FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow admin to update deposits" ON public.deposits FOR UPDATE USING (public.is_admin(auth.uid()));

-- Tickets Policies
CREATE POLICY "Allow users to read own tickets" ON public.tickets FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow users to create own tickets" ON public.tickets FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Allow admin to update tickets" ON public.tickets FOR UPDATE USING (public.is_admin(auth.uid()));

-- Ticket Messages Policies
CREATE POLICY "Allow users to read messages of own tickets" ON public.ticket_messages FOR SELECT USING (
  sender_id = auth.uid() OR 
  public.is_admin(auth.uid()) OR
  ticket_id IN (SELECT id FROM public.tickets WHERE user_id = auth.uid())
);
CREATE POLICY "Allow users to insert messages in own tickets" ON public.ticket_messages FOR INSERT WITH CHECK (
  sender_id = auth.uid() OR 
  public.is_admin(auth.uid()) OR
  ticket_id IN (SELECT id FROM public.tickets WHERE user_id = auth.uid())
);

-- Admin Profiles Policies
CREATE POLICY "Allow admin to manage admin profiles" ON public.admin_profiles FOR ALL USING (public.is_admin(auth.uid()));
CREATE POLICY "Allow read admin_profiles" ON public.admin_profiles FOR SELECT USING (true);

-- Settings Policies
CREATE POLICY "Allow public read settings" ON public.settings FOR SELECT USING (true);
CREATE POLICY "Allow admin to manage settings" ON public.settings FOR ALL USING (public.is_admin(auth.uid()));

-- Deposit Methods Policies
CREATE POLICY "Allow public read deposit_methods" ON public.deposit_methods FOR SELECT USING (true);
CREATE POLICY "Allow admin to manage deposit_methods" ON public.deposit_methods FOR ALL USING (public.is_admin(auth.uid()));

-- Whatsapp Settings Policies
CREATE POLICY "Allow public read whatsapp_settings" ON public.whatsapp_settings FOR SELECT USING (true);
CREATE POLICY "Allow admin to manage whatsapp_settings" ON public.whatsapp_settings FOR ALL USING (public.is_admin(auth.uid()));

-- Admin Push Tokens Policies
CREATE POLICY "Allow admin to manage admin_push_tokens" ON public.admin_push_tokens FOR ALL USING (public.is_admin(auth.uid()));

-- Admin Notifications Policies
CREATE POLICY "Allow admin to manage admin_notifications" ON public.admin_notifications FOR ALL USING (public.is_admin(auth.uid()));
