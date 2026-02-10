-- SurakshaApp Database Setup Script
-- Run this SQL in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table to store additional user information
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'parent', -- 'parent' or 'child'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create devices table for child device tracking
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_name TEXT NOT NULL,
  device_model TEXT,
  os_version TEXT,
  paired_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  last_active TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true
);

-- Create alerts table for monitoring alerts
CREATE TABLE IF NOT EXISTS public.alerts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  alert_type TEXT NOT NULL, -- 'location', 'app_usage', 'screen_time', etc.
  alert_message TEXT NOT NULL,
  severity TEXT DEFAULT 'medium', -- 'low', 'medium', 'high'
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create screen_time table for tracking device usage
CREATE TABLE IF NOT EXISTS public.screen_time (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  total_minutes INTEGER DEFAULT 0,
  app_usage JSONB, -- Store app-wise usage as JSON
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create locations table for location tracking
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  address TEXT,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create subscriptions table for user subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  plan_name TEXT NOT NULL, -- 'free', 'basic', 'premium'
  status TEXT DEFAULT 'active', -- 'active', 'cancelled', 'expired'
  started_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE,
  auto_renew BOOLEAN DEFAULT true
);

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc'::text, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for profiles updated_at
CREATE TRIGGER on_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screen_time ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

-- Profiles: Users can read and update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Devices: Users can manage their own devices
CREATE POLICY "Users can view own devices" ON public.devices
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices" ON public.devices
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices" ON public.devices
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices" ON public.devices
  FOR DELETE USING (auth.uid() = user_id);

-- Alerts: Users can view alerts from their devices
CREATE POLICY "Users can view own device alerts" ON public.alerts
  FOR SELECT USING (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own device alerts" ON public.alerts
  FOR UPDATE USING (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

-- Screen time: Users can manage screen time for their devices
CREATE POLICY "Users can view own device screen time" ON public.screen_time
  FOR SELECT USING (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own device screen time" ON public.screen_time
  FOR INSERT WITH CHECK (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

-- Locations: Users can manage locations for their devices
CREATE POLICY "Users can view own device locations" ON public.locations
  FOR SELECT USING (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own device locations" ON public.locations
  FOR INSERT WITH CHECK (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

-- Subscriptions: Users can view and update their own subscriptions
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own subscriptions" ON public.subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own subscriptions" ON public.subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_alerts_device_id ON public.alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_screen_time_device_id ON public.screen_time(device_id);
CREATE INDEX IF NOT EXISTS idx_screen_time_date ON public.screen_time(date);
CREATE INDEX IF NOT EXISTS idx_locations_device_id ON public.locations(device_id);
CREATE INDEX IF NOT EXISTS idx_locations_recorded_at ON public.locations(recorded_at);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);

-- Insert some sample data for testing (optional)
-- You can uncomment these lines after creating your first user account

-- INSERT INTO public.subscriptions (user_id, plan_name, status)
-- VALUES (
--   (SELECT id FROM auth.users LIMIT 1),
--   'free',
--   'active'
-- );
