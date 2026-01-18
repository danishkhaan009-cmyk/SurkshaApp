-- Create call_logs table for tracking call history on child devices
-- Run this in your Supabase SQL Editor

-- Create the table
CREATE TABLE IF NOT EXISTS public.call_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  name TEXT,
  number TEXT NOT NULL,
  formatted_number TEXT,
  call_type TEXT NOT NULL, -- 'Incoming', 'Outgoing', 'Missed', 'Rejected', 'Blocked', 'Voicemail'
  call_type_icon TEXT, -- Icon name for display
  duration INTEGER DEFAULT 0, -- Duration in seconds
  timestamp TIMESTAMP WITH TIME ZONE,
  cached_number_type TEXT,
  cached_number_label TEXT,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  
  -- Unique constraint to prevent duplicate call logs
  CONSTRAINT unique_device_call UNIQUE(device_id, number, timestamp, call_type)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_call_logs_device_id ON public.call_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_call_logs_timestamp ON public.call_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_call_type ON public.call_logs(call_type);

-- Add trigger for updated_at
DROP TRIGGER IF EXISTS update_call_logs_updated_at ON public.call_logs;
CREATE TRIGGER update_call_logs_updated_at
  BEFORE UPDATE ON public.call_logs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS
ALTER TABLE public.call_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for call logs
-- Allow users to view call logs from their devices
CREATE POLICY "Users can view own device call logs" ON public.call_logs
  FOR SELECT USING (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

-- Allow inserting call logs for any device (child devices will insert)
CREATE POLICY "Devices can insert call logs" ON public.call_logs
  FOR INSERT WITH CHECK (true);

-- Allow updating call logs for devices
CREATE POLICY "Devices can update call logs" ON public.call_logs
  FOR UPDATE USING (true);

-- Allow public access (for testing - remove in production)
CREATE POLICY "Allow public read access to call logs" ON public.call_logs
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access to call logs" ON public.call_logs
  FOR INSERT WITH CHECK (true);

-- Reload the schema cache
NOTIFY pgrst, 'reload schema';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Call logs table created successfully!';
  RAISE NOTICE '📞 Call logs will now be synced from child devices to parent dashboard';
END $$;
