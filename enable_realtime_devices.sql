-- Enable Realtime on the devices table for real-time status updates
-- Run this in the Supabase SQL Editor

-- 1. Enable Realtime for the devices table
ALTER PUBLICATION supabase_realtime ADD TABLE devices;

-- 2. Ensure the columns exist (they should already exist from previous migrations)
DO $$
BEGIN
  -- Add active_device_identifier if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'devices' AND column_name = 'active_device_identifier'
  ) THEN
    ALTER TABLE devices ADD COLUMN active_device_identifier TEXT;
  END IF;

  -- Add last_active_at if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'devices' AND column_name = 'last_active_at'
  ) THEN
    ALTER TABLE devices ADD COLUMN last_active_at TIMESTAMPTZ;
  END IF;
END $$;

-- 3. Create index on last_active_at for efficient queries
CREATE INDEX IF NOT EXISTS idx_devices_last_active_at ON devices(last_active_at);

-- 4. Create index on user_id for efficient filtering
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- 5. RLS policy to allow devices to update their own status
-- (The child device needs to update is_active, last_active_at, active_device_identifier)
DO $$
BEGIN
  -- Drop existing policy if it exists, then recreate
  DROP POLICY IF EXISTS "devices_update_status" ON devices;
  
  CREATE POLICY "devices_update_status" ON devices
    FOR UPDATE
    USING (true)
    WITH CHECK (true);
END $$;

-- 6. Verify setup
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'devices' 
AND column_name IN ('active_device_identifier', 'last_active_at', 'is_active')
ORDER BY column_name;
