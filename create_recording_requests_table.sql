-- Table to store parent-initiated recording requests
-- Parent creates a request, child device picks it up and records

CREATE TABLE IF NOT EXISTS recording_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    requested_at TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ,
    recording_id UUID REFERENCES screen_recordings(id),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE recording_requests ENABLE ROW LEVEL SECURITY;

-- Policies for recording_requests
CREATE POLICY "Allow all for recording_requests" ON recording_requests FOR ALL USING (true);

-- Index for faster queries
CREATE INDEX idx_recording_requests_device_id ON recording_requests(device_id);
CREATE INDEX idx_recording_requests_status ON recording_requests(status);
CREATE INDEX idx_recording_requests_device_status ON recording_requests(device_id, status);

-- Add recording_type column to screen_recordings if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'screen_recordings' 
                   AND column_name = 'recording_type') THEN
        ALTER TABLE screen_recordings ADD COLUMN recording_type TEXT DEFAULT 'camera';
    END IF;
END $$;
