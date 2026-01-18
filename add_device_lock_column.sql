-- ========================================
-- ADD DEVICE LOCK SYSTEM TO DEVICES TABLE
-- ========================================
-- This ensures only ONE physical device can be active per child at a time

-- Add active_device_identifier column to track which device is currently using this child profile
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS active_device_identifier TEXT;

-- Add last_active_at timestamp to track when device was last active (for cleanup)
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_devices_active_device 
ON public.devices(active_device_identifier);

-- Add comment explaining the column
COMMENT ON COLUMN public.devices.active_device_identifier IS 
'Unique identifier of the physical device currently active in child mode. Only one device can be active per child.';

COMMENT ON COLUMN public.devices.last_active_at IS 
'Timestamp when the device was last active. Used for cleanup of stale locks.';

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'devices' 
  AND table_schema = 'public'
  AND column_name IN ('active_device_identifier', 'last_active_at')
ORDER BY column_name;
