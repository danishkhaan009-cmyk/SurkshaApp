-- Add PIN column to devices table
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS pin TEXT;

-- Add index for faster PIN lookups (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_devices_pin 
ON public.devices(pin) 
WHERE pin IS NOT NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'devices'
  AND column_name = 'pin';
