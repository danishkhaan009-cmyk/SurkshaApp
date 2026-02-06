package com.getsurakshaapp

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.os.PowerManager
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class ScreenRecordService : Service() {
    
    companion object {
        private const val TAG = "ScreenRecordService"
        private const val CHANNEL_ID = "screen_record_channel"
        private const val NOTIFICATION_ID = 2001
        private const val PREFS = "screen_record_prefs"
        private const val KEY_RECORDING_ENABLED = "recording_enabled"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_KEY = "supabase_key"
        private const val KEY_DEVICE_ID = "device_id"
        
        // Recording interval in milliseconds (5 minutes)
        private const val RECORDING_INTERVAL_MS = 30 * 1000L
        
        // MediaProjection data
        var resultCode: Int = 0
        var resultData: Intent? = null
        
        private var instance: ScreenRecordService? = null
        private var isRecordingEnabled = false
        
        /**
         * Set MediaProjection result from activity
         */
        fun setMediaProjectionResult(code: Int, data: Intent?) {
            resultCode = code
            resultData = data
            Log.d(TAG, "✅ MediaProjection result set")
        }
        
        /**
         * Initialize with credentials
         */
        fun initialize(context: Context, deviceId: String, supabaseUrl: String, supabaseKey: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString(KEY_DEVICE_ID, deviceId)
                putString(KEY_SUPABASE_URL, supabaseUrl)
                putString(KEY_SUPABASE_KEY, supabaseKey)
                apply()
            }
            Log.d(TAG, "✅ ScreenRecordService initialized for device: $deviceId")
            
            // Initialize screen state receiver with current device state
            ScreenStateReceiver.initializeState(context)
            
            // Check if recording is enabled and start syncing
            CoroutineScope(Dispatchers.IO).launch {
                syncRecordingSettings(context)
            }
        }
        
        /**
         * Enable/disable recording from parent
         */
        fun setRecordingEnabled(context: Context, enabled: Boolean) {
            isRecordingEnabled = enabled
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_RECORDING_ENABLED, enabled).apply()
            
            Log.d(TAG, "🎬 Recording ${if (enabled) "ENABLED" else "DISABLED"}")
            Log.d(TAG, "   - isChildModeActive: ${isChildModeActive(context)}")
            
            if (enabled) {
                // Only start recording on child devices
                if (isChildModeActive(context) && ScreenStateReceiver.isScreenOn && ScreenStateReceiver.isDeviceUnlocked) {
                    startRecording(context)
                } else if (!isChildModeActive(context)) {
                    Log.d(TAG, "📱 Not in child mode - recording setting saved but not started (parent device)")
                }
            } else {
                stopRecording(context)
            }
        }
        
        /**
         * Check if recording is enabled
         */
        fun isRecordingEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_RECORDING_ENABLED, false)
        }
        
        /**
         * Check if device is in child mode
         */
        fun isChildModeActive(context: Context): Boolean {
            // Check Flutter SharedPreferences for child mode status
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isChildMode = flutterPrefs.getBoolean("flutter.is_child_mode_active", false)
            
            // Also check backup key
            if (!isChildMode) {
                val backupChildMode = flutterPrefs.getBoolean("flutter.child_mode_backup", false)
                if (backupChildMode) return true
            }
            
            // Also check AppBlockService prefs as fallback
            val appBlockPrefs = context.getSharedPreferences("app_block_prefs", Context.MODE_PRIVATE)
            val appBlockChildMode = appBlockPrefs.getBoolean("child_mode", false)
            
            return isChildMode || appBlockChildMode
        }
        
        /**
         * Start recording service
         */
        fun startRecording(context: Context) {
            Log.d(TAG, "🎬 startRecording called - checking conditions...")
            Log.d(TAG, "   - isChildModeActive: ${isChildModeActive(context)}")
            Log.d(TAG, "   - isRecordingEnabled: ${isRecordingEnabled(context)}")
            Log.d(TAG, "   - resultData: ${if (resultData != null) "SET" else "NULL"}")
            Log.d(TAG, "   - isScreenOn: ${ScreenStateReceiver.isScreenOn}")
            Log.d(TAG, "   - isDeviceUnlocked: ${ScreenStateReceiver.isDeviceUnlocked}")
            
            // Only record on child devices
            if (!isChildModeActive(context)) {
                Log.d(TAG, "📱 Not in child mode - skipping recording (parent device)")
                return
            }
            
            if (!isRecordingEnabled(context)) {
                Log.d(TAG, "⏸️ Recording not enabled by parent")
                return
            }
            
            if (resultData == null) {
                Log.e(TAG, "❌ MediaProjection permission not granted - resultData is null")
                return
            }
            
            Log.d(TAG, "✅ All conditions met (child mode active) - starting foreground service...")
            
            val intent = Intent(context, ScreenRecordService::class.java).apply {
                action = "START"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            
            Log.d(TAG, "✅ Foreground service start command sent")
        }
        
        /**
         * Stop recording service
         */
        fun stopRecording(context: Context) {
            val intent = Intent(context, ScreenRecordService::class.java).apply {
                action = "STOP"
            }
            context.startService(intent)
        }
        
        /**
         * Handle screen state changes
         */
        fun onScreenStateChanged(context: Context, isScreenOn: Boolean, isUnlocked: Boolean) {
            // Only process on child devices
            if (!isChildModeActive(context)) {
                Log.d(TAG, "📱 Not in child mode - ignoring screen state change")
                return
            }
            
            if (!isRecordingEnabled(context)) return
            
            if (isScreenOn && isUnlocked) {
                Log.d(TAG, "📱 Screen ON & Unlocked - Starting recording (child mode)")
                startRecording(context)
            } else {
                Log.d(TAG, "📱 Screen OFF or Locked - Stopping recording")
                stopRecording(context)
            }
        }
        
        /**
         * Sync recording settings from Supabase
         */
        suspend fun syncRecordingSettings(context: Context) {
            Log.d(TAG, "🔄 syncRecordingSettings called...")
            try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                var deviceId = prefs.getString(KEY_DEVICE_ID, null)
                var supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
                var supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)
                
                // Fallback to other prefs
                if (deviceId.isNullOrEmpty()) {
                    val locationPrefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                    deviceId = locationPrefs.getString("device_id", null)
                }
                if (deviceId.isNullOrEmpty()) {
                    val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    deviceId = flutterPrefs.getString("flutter.child_device_id", null)
                    if (deviceId.isNullOrEmpty()) {
                        deviceId = flutterPrefs.getString("flutter.device_id_backup", null)
                    }
                }
                
                // Use hardcoded fallback if needed
                if (supabaseUrl.isNullOrEmpty()) {
                    supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
                }
                if (supabaseKey.isNullOrEmpty()) {
                    supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
                }
                
                if (deviceId.isNullOrEmpty()) {
                    Log.e(TAG, "❌ Missing device ID for sync")
                    return
                }
                
                Log.d(TAG, "🔄 Fetching settings for device: $deviceId")
                
                val endpoint = "$supabaseUrl/rest/v1/screen_recording_settings?device_id=eq.$deviceId&select=recording_enabled"
                val url = URL(endpoint)
                val connection = url.openConnection() as HttpURLConnection
                
                connection.requestMethod = "GET"
                connection.setRequestProperty("apikey", supabaseKey)
                connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                
                val responseCode = connection.responseCode
                Log.d(TAG, "🔄 Supabase response code: $responseCode")
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    Log.d(TAG, "🔄 Supabase response: $response")
                    val jsonArray = JSONArray(response)
                    
                    if (jsonArray.length() > 0) {
                        val item = jsonArray.getJSONObject(0)
                        val enabled = item.optBoolean("recording_enabled", false)
                        
                        isRecordingEnabled = enabled
                        prefs.edit().putBoolean(KEY_RECORDING_ENABLED, enabled).apply()
                        
                        Log.d(TAG, "✅ Synced recording settings: enabled=$enabled")
                        Log.d(TAG, "   - isChildModeActive: ${isChildModeActive(context)}")
                        Log.d(TAG, "   - resultData: ${if (resultData != null) "SET" else "NULL"}")
                        Log.d(TAG, "   - isScreenOn: ${ScreenStateReceiver.isScreenOn}")
                        Log.d(TAG, "   - isDeviceUnlocked: ${ScreenStateReceiver.isDeviceUnlocked}")
                        
                        // Auto-start if enabled, in child mode, and screen is on
                        if (enabled && isChildModeActive(context) && ScreenStateReceiver.isScreenOn && ScreenStateReceiver.isDeviceUnlocked) {
                            Log.d(TAG, "✅ Conditions met (child mode) - calling startRecording on Main thread...")
                            withContext(Dispatchers.Main) {
                                startRecording(context)
                            }
                        } else if (enabled && !isChildModeActive(context)) {
                            Log.d(TAG, "📱 Recording enabled but not in child mode - parent device, skipping auto-start")
                        } else if (enabled) {
                            Log.d(TAG, "⚠️ Recording enabled but conditions not met for auto-start")
                        }
                    } else {
                        Log.d(TAG, "⚠️ No settings found for device")
                    }
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to sync settings: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaProjection: MediaProjection? = null
    private var outputFile: File? = null
    private var isRecording = false
    private var screenStateReceiver: ScreenStateReceiver? = null
    private var recordingStartTime: Long = 0
    
    // Timer for periodic upload (every 5 minutes)
    private var uploadTimer: Job? = null
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        registerScreenStateReceiver()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                startForeground(NOTIFICATION_ID, createNotification("Recording screen..."))
                startRecordingInternal()
            }
            "STOP" -> {
                stopRecordingInternal()
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun registerScreenStateReceiver() {
        screenStateReceiver = ScreenStateReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenStateReceiver, filter)
    }
    
    private fun startRecordingInternal() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }
        
        // Check if screen is on and device is unlocked
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (!powerManager.isInteractive) {
            Log.d(TAG, "⏸️ Screen is off - not starting recording")
            return
        }
        
        if (resultData == null) {
            Log.e(TAG, "❌ MediaProjection permission not granted")
            return
        }
        
        try {
            val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, resultData!!)
            
            if (mediaProjection == null) {
                Log.e(TAG, "❌ Failed to get MediaProjection")
                return
            }
            
            // Get screen dimensions
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(metrics)
            
            // Align dimensions to 16 pixels (required for H.264 encoder)
            val screenWidth = (metrics.widthPixels / 16) * 16
            val screenHeight = (metrics.heightPixels / 16) * 16
            val screenDensity = metrics.densityDpi
            
            // Create output file
            outputFile = createOutputFile()
            
            // Setup new MediaRecorder with correct order
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setVideoEncodingBitRate(3 * 1024 * 1024) // 3 Mbps
                setVideoFrameRate(24)
                setVideoSize(screenWidth, screenHeight)
                setOutputFile(outputFile?.absolutePath)
                prepare()
            }
            
            // Create new virtual display
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenRecording",
                screenWidth,
                screenHeight,
                screenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder?.surface,
                null,
                null
            )
            
            mediaRecorder?.start()
            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            
            Log.d(TAG, "🎥 Screen recording started: ${outputFile?.absolutePath}")
            
            // Start periodic upload timer (every 5 minutes)
            startPeriodicUploadTimer()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start recording: ${e.message}", e)
            cleanup()
        }
    }
    
    /**
     * Start a timer that uploads recording every 5 minutes
     */
    private fun startPeriodicUploadTimer() {
        uploadTimer?.cancel()
        uploadTimer = scope.launch {
            while (isActive && isRecording) {
                delay(RECORDING_INTERVAL_MS)
                if (isRecording) {
                    Log.d(TAG, "⏰ 5 minutes elapsed - saving and restarting recording")
                    withContext(Dispatchers.Main) {
                        saveAndRestartRecording()
                    }
                }
            }
        }
    }
    
    /**
     * Save current recording and start a new one
     */
    private fun saveAndRestartRecording() {
        if (!isRecording) return
        
        val durationSeconds = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        
        try {
            // Stop current recording
            mediaRecorder?.stop()
            Log.d(TAG, "⏹️ Recording segment stopped (duration: ${durationSeconds}s)")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recorder for segment: ${e.message}")
        }
        
        val recordedFile = outputFile
        
        // Release resources but keep projection
        virtualDisplay?.release()
        virtualDisplay = null
        mediaRecorder?.release()
        mediaRecorder = null
        
        // Upload in background
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 0) {
                scope.launch {
                    uploadAndSaveRecording(file, durationSeconds)
                }
            }
        }
        
        // Start new recording segment immediately
        isRecording = false
        startNewRecordingSegment()
    }
    
    /**
     * Start a new recording segment (reuses existing MediaProjection)
     */
    private fun startNewRecordingSegment() {
        if (mediaProjection == null) {
            Log.e(TAG, "❌ MediaProjection is null, cannot start new segment")
            // Try to get a new projection
            if (resultData != null) {
                val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                mediaProjection = projectionManager.getMediaProjection(resultCode, resultData!!)
            }
            if (mediaProjection == null) return
        }
        
        try {
            // Get screen dimensions
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(metrics)
            
            val screenWidth = metrics.widthPixels
            val screenHeight = metrics.heightPixels
            val screenDensity = metrics.densityDpi
            
            // Create new output file
            outputFile = createOutputFile()
            
            // Setup new MediaRecorder with correct order
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setVideoEncodingBitRate(3 * 1024 * 1024) // 3 Mbps
                setVideoFrameRate(24)
                setVideoSize(screenWidth, screenHeight)
                setOutputFile(outputFile?.absolutePath)
                prepare()
            }
            
            // Create new virtual display
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenRecording",
                screenWidth,
                screenHeight,
                screenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder?.surface,
                null,
                null
            )
            
            mediaRecorder?.start()
            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            
            Log.d(TAG, "🎥 New recording segment started: ${outputFile?.absolutePath}")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start new recording segment: ${e.message}", e)
        }
    }
    
    private fun stopRecordingInternal() {
        if (!isRecording) {
            Log.d(TAG, "Not recording")
            return
        }
        
        // Cancel the upload timer
        uploadTimer?.cancel()
        uploadTimer = null
        
        val durationSeconds = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        
        try {
            mediaRecorder?.stop()
            Log.d(TAG, "⏹️ Recording stopped (duration: ${durationSeconds}s)")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recorder: ${e.message}")
        }
        
        val recordedFile = outputFile
        cleanup()
        
        // Upload to Google Drive and save metadata to Supabase
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 0) {
                scope.launch {
                    uploadAndSaveRecording(file, durationSeconds)
                }
            }
        }
        
        stopForeground(true)
        stopSelf()
    }
    
    private fun cleanup() {
        // Cancel upload timer
        uploadTimer?.cancel()
        uploadTimer = null
        
        isRecording = false
        virtualDisplay?.release()
        virtualDisplay = null
        mediaRecorder?.release()
        mediaRecorder = null
        mediaProjection?.stop()
        mediaProjection = null
    }
    
    private fun createOutputFile(): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val fileName = "SurakshaRecord_$timestamp.mp4"
        
        val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
        } else {
            @Suppress("DEPRECATION")
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
        }
        
        if (!dir.exists()) dir.mkdirs()
        
        return File(dir, fileName)
    }
    
    /**
     * Upload recording to Google Drive and save metadata to Supabase
     */
    private suspend fun uploadAndSaveRecording(file: File, durationSeconds: Int) {
        Log.d(TAG, "📤 uploadAndSaveRecording called")
        Log.d(TAG, "   - File: ${file.name} (${file.length()} bytes)")
        Log.d(TAG, "   - Duration: ${durationSeconds}s")
        Log.d(TAG, "   - File exists: ${file.exists()}")
        Log.d(TAG, "   - Google Drive initialized: ${GoogleDriveUploader.isInitialized()}")
        
        try {
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            var deviceId = prefs.getString(KEY_DEVICE_ID, null)
            var supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
            var supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)
            
            // Fallback to other prefs
            if (deviceId.isNullOrEmpty()) {
                val locationPrefs = getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                deviceId = locationPrefs.getString("device_id", null)
            }
            if (deviceId.isNullOrEmpty()) {
                val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                deviceId = flutterPrefs.getString("flutter.child_device_id", null)
                if (deviceId.isNullOrEmpty()) {
                    deviceId = flutterPrefs.getString("flutter.device_id_backup", null)
                }
            }
            
            // Use hardcoded fallback if needed
            if (supabaseUrl.isNullOrEmpty()) {
                supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
            }
            if (supabaseKey.isNullOrEmpty()) {
                supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
            }
            
            if (deviceId.isNullOrEmpty()) {
                Log.e(TAG, "❌ Missing device ID - cannot upload recording")
                return
            }
            
            Log.d(TAG, "📤 Uploading for device: $deviceId")
            
            // Upload to Google Drive
            Log.d(TAG, "☁️ Starting Google Drive upload...")
            val driveResult = GoogleDriveUploader.uploadFile(this, file)
            
            if (driveResult != null) {
                Log.d(TAG, "✅ Google Drive upload successful!")
                Log.d(TAG, "   - File ID: ${driveResult.fileId}")
                Log.d(TAG, "   - Link: ${driveResult.webLink}")
            } else {
                Log.w(TAG, "⚠️ Google Drive upload failed or returned null")
            }
            
            // Save metadata to Supabase
            Log.d(TAG, "💾 Saving metadata to Supabase...")
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
            val timestamp = dateFormat.format(Date())
            
            val jsonPayload = JSONObject().apply {
                put("device_id", deviceId)
                put("file_name", file.name)
                put("drive_file_id", driveResult?.fileId ?: "")
                put("drive_link", driveResult?.webLink ?: "")
                put("file_size", file.length())
                put("duration_seconds", durationSeconds)
                put("recorded_at", timestamp)
                put("uploaded_at", if (driveResult != null) timestamp else JSONObject.NULL)
                put("status", if (driveResult != null) "uploaded" else "local_only")
            }
            
            Log.d(TAG, "📝 Payload: $jsonPayload")
            
            val endpoint = "$supabaseUrl/rest/v1/screen_recordings"
            val url = URL(endpoint)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            connection.outputStream.use { os ->
                os.write(jsonPayload.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 Supabase response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_CREATED || responseCode == HttpURLConnection.HTTP_OK) {
                Log.d(TAG, "✅ Recording metadata saved to Supabase successfully")
                
                // Delete local file after successful upload to Drive
                if (driveResult != null) {
                    val deleted = file.delete()
                    Log.d(TAG, "🗑️ Local file ${if (deleted) "deleted" else "failed to delete"}")
                } else {
                    Log.d(TAG, "📦 Keeping local file (Drive upload failed)")
                }
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Failed to save metadata to Supabase: $responseCode")
                Log.e(TAG, "   Error: $errorStream")
            }
            
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error uploading recording: ${e.message}", e)
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Recording screen activity"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Suraksha Protection Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    override fun onDestroy() {
        cleanup()
        screenStateReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {}
        }
        scope.cancel()
        instance = null
        super.onDestroy()
    }
}
