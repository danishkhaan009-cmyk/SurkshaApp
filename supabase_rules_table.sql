-- Create device_rules table for storing parental control rules
CREATE TABLE IF NOT EXISTS public.device_rules (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  parent_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Rule details
  rule_type TEXT NOT NULL, -- 'App Time Limit', 'Daily Screen Time', 'Bedtime Lock', 'App Lock'
  title TEXT NOT NULL,
  subtitle TEXT,
  
  -- App-specific data (for App Time Limit)
  app_category TEXT, -- 'Social Media', 'Messaging', 'Entertainment', 'Gaming', 'Browsers'
  app_name TEXT, -- 'Instagram', 'WhatsApp', etc.
  app_package_name TEXT, -- 'com.instagram.android', 'com.whatsapp', etc.
  
  -- Time configuration
  time_limit_minutes INTEGER, -- For App Time Limit and Daily Screen Time
  bedtime_start TIME, -- For Bedtime Lock (e.g., '22:00')
  bedtime_end TIME, -- For Bedtime Lock (e.g., '07:00')
  
  -- PIN configuration (required for all rules)
  pin_code TEXT NOT NULL, -- 4-6 digit PIN
  pin_required BOOLEAN DEFAULT true,
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Tracking
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_device_rules_device_id ON public.device_rules(device_id);
CREATE INDEX IF NOT EXISTS idx_device_rules_active ON public.device_rules(is_active) WHERE is_active = true;

-- Add trigger for updated_at
DROP TRIGGER IF EXISTS update_device_rules_updated_at ON public.device_rules;
CREATE TRIGGER update_device_rules_updated_at
  BEFORE UPDATE ON public.device_rules
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS
ALTER TABLE public.device_rules ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Parents can see all rules for their children's devices
CREATE POLICY "Parents can view their children's device rules" ON public.device_rules
  FOR SELECT USING (
    parent_id = auth.uid()
  );

-- Parents can insert rules for their children's devices
CREATE POLICY "Parents can insert device rules" ON public.device_rules
  FOR INSERT WITH CHECK (
    parent_id = auth.uid()
  );

-- Parents can update their children's device rules
CREATE POLICY "Parents can update device rules" ON public.device_rules
  FOR UPDATE USING (
    parent_id = auth.uid()
  );

-- Parents can delete their children's device rules
CREATE POLICY "Parents can delete device rules" ON public.device_rules
  FOR DELETE USING (
    parent_id = auth.uid()
  );

-- App package names mapping (for easy reference)
CREATE TABLE IF NOT EXISTS public.app_packages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  app_name TEXT NOT NULL UNIQUE,
  package_name TEXT NOT NULL,
  category TEXT NOT NULL,
  icon_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Insert common apps
INSERT INTO public.app_packages (app_name, package_name, category) VALUES
  -- Social Media
  ('Instagram', 'com.instagram.android', 'Social Media'),
  ('Facebook', 'com.facebook.katana', 'Social Media'),
  ('TikTok', 'com.zhiliaoapp.musically', 'Social Media'),
  ('Snapchat', 'com.snapchat.android', 'Social Media'),
  ('Twitter (X)', 'com.twitter.android', 'Social Media'),
  
  -- Messaging
  ('WhatsApp', 'com.whatsapp', 'Messaging'),
  ('Telegram', 'org.telegram.messenger', 'Messaging'),
  ('Messenger', 'com.facebook.orca', 'Messaging'),
  ('Discord', 'com.discord', 'Messaging'),
  
  -- Entertainment
  ('YouTube', 'com.google.android.youtube', 'Entertainment'),
  ('Netflix', 'com.netflix.mediaclient', 'Entertainment'),
  ('Spotify', 'com.spotify.music', 'Entertainment'),
  ('Amazon Prime Video', 'com.amazon.avod.thirdpartyclient', 'Entertainment'),
  
  -- Gaming
  ('PUBG Mobile', 'com.tencent.ig', 'Gaming'),
  ('Free Fire', 'com.dts.freefireth', 'Gaming'),
  ('Candy Crush', 'com.king.candycrushsaga', 'Gaming'),
  ('Clash of Clans', 'com.supercell.clashofclans', 'Gaming'),
  
  -- Browsers
  ('Chrome', 'com.android.chrome', 'Browsers'),
  ('Firefox', 'org.mozilla.firefox', 'Browsers'),
  ('Opera', 'com.opera.browser', 'Browsers'),
  ('Brave', 'com.brave.browser', 'Browsers')
ON CONFLICT (app_name) DO NOTHING;

-- Make app_packages readable by all authenticated users
ALTER TABLE public.app_packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view app packages" ON public.app_packages
  FOR SELECT USING (true);
