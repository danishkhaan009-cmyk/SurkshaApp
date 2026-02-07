-- Create recording sessions table to track active recording status
CREATE TABLE IF NOT EXISTS recording_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    session_type TEXT NOT NULL CHECK (session_type IN ('screen', 'camera', 'auto')),
    status TEXT NOT NULL CHECK (status IN ('active', 'paused', 'stopped', 'error')) DEFAULT 'active',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stopped_at TIMESTAMPTZ,
    started_by TEXT NOT NULL CHECK (started_by IN ('parent', 'auto_unlock', 'auto_usage')),
    parent_user_id UUID REFERENCES auth.users(id),
    trigger_event TEXT, -- 'device_unlock', 'app_launch', 'screen_on', 'parent_manual'
    total_duration_seconds INTEGER DEFAULT 0,
    segments_count INTEGER DEFAULT 0,
    last_upload_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for quick device lookups
CREATE INDEX IF NOT EXISTS idx_recording_sessions_device_id ON recording_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_recording_sessions_status ON recording_sessions(status);
CREATE INDEX IF NOT EXISTS idx_recording_sessions_started_at ON recording_sessions(started_at DESC);

-- Enable Row Level Security
ALTER TABLE recording_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Parents can view their children's recordings
CREATE POLICY "Parents can view children recording sessions"
ON recording_sessions FOR SELECT
USING (
    device_id IN (
        SELECT id::TEXT FROM devices WHERE user_id = auth.uid()
    )
);

-- Policy: System can insert recording sessions (for child devices)
CREATE POLICY "System can insert recording sessions"
ON recording_sessions FOR INSERT
WITH CHECK (true);

-- Policy: System can update recording sessions
CREATE POLICY "System can update recording sessions"
ON recording_sessions FOR UPDATE
USING (true);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_recording_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS recording_sessions_updated_at ON recording_sessions;
CREATE TRIGGER recording_sessions_updated_at
    BEFORE UPDATE ON recording_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_recording_sessions_updated_at();

-- Add auto_recording_enabled column to device table if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'auto_recording_enabled'
    ) THEN
        ALTER TABLE devices ADD COLUMN auto_recording_enabled BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add auto_recording_trigger column to device table if not exists  
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'auto_recording_trigger'
    ) THEN
        ALTER TABLE devices ADD COLUMN auto_recording_trigger TEXT DEFAULT 'unlock' 
        CHECK (auto_recording_trigger IN ('unlock', 'usage', 'both', 'none'));
    END IF;
END $$;

-- Function to automatically stop stale recording sessions (older than 6 hours)
CREATE OR REPLACE FUNCTION auto_stop_stale_recording_sessions()
RETURNS void AS $$
BEGIN
    UPDATE recording_sessions
    SET status = 'stopped',
        stopped_at = NOW(),
        error_message = 'Auto-stopped due to inactivity'
    WHERE status = 'active'
    AND started_at < NOW() - INTERVAL '6 hours';
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to clean up stale sessions (run this in Supabase dashboard if pg_cron is available)
-- SELECT cron.schedule('clean-stale-recordings', '0 * * * *', 'SELECT auto_stop_stale_recording_sessions()');

COMMENT ON TABLE recording_sessions IS 'Tracks active and historical recording sessions with auto-start triggers';
COMMENT ON COLUMN recording_sessions.session_type IS 'Type of recording: screen (continuous screen recording), camera (parent-initiated camera recording), auto (automatic recording)';
COMMENT ON COLUMN recording_sessions.started_by IS 'Who/what initiated the recording: parent (manual), auto_unlock (device unlock trigger), auto_usage (app usage trigger)';
COMMENT ON COLUMN recording_sessions.trigger_event IS 'Specific event that triggered auto-recording';
