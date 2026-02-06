package com.getsurakshaapp

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.*
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.*
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.*

/**
 * Result of recording start attempt
 */
enum class RecordingStartResult {
    SUCCESS,
    NOT_CHILD_MODE,
    ALREADY_RECORDING,
    COOLDOWN_ACTIVE,
    APP_NOT_FOREGROUND,
    SCREEN_OFF,
    DEVICE_LOCKED,
    NO_PERMISSION
}

/**
 * Cooldown check result
 */
data class CooldownResult(
    val canRecord: Boolean,
    val remainingSeconds: Int
)

/**
 * Camera-based video recording service.
 * Records short 30-second clips using the device camera (not screen capture).
 * Parent-initiated only - no continuous background recording.
 */
class CameraRecordService : Service() {

    companion object {
        private const val TAG = "CameraRecordService"
        private const val CHANNEL_ID = "camera_record_channel"
        private const val NOTIFICATION_ID = 3001
        private const val PREFS = "camera_record_prefs"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_KEY = "supabase_key"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_LAST_RECORDING_TIME = "last_recording_time"
        private const val KEY_IS_RECORDING = "is_recording_active"
        
        // Maximum recording duration: 30 seconds
        private const val MAX_RECORDING_DURATION_MS = 30 * 1000L
        
        // Cooldown between recordings: 5 minutes
        private const val RECORDING_COOLDOWN_MS = 5 * 60 * 1000L
        
        private var instance: CameraRecordService? = null
        
        // Track if app is in foreground (set by MainActivity)
        @Volatile
        var isAppInForeground: Boolean = false
        
        // Track screen state (set by ScreenStateReceiver)
        @Volatile
        var isScreenOn: Boolean = true
        
        @Volatile
        var isDeviceUnlocked: Boolean = true
        
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
            Log.d(TAG, "✅ CameraRecordService initialized for device: $deviceId")
        }
        
        /**
         * Check if device is in child mode
         */
        fun isChildModeActive(context: Context): Boolean {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isChildMode = flutterPrefs.getBoolean("flutter.is_child_mode_active", false)
            
            if (!isChildMode) {
                val backupChildMode = flutterPrefs.getBoolean("flutter.child_mode_backup", false)
                if (backupChildMode) return true
            }
            
            val appBlockPrefs = context.getSharedPreferences("app_block_prefs", Context.MODE_PRIVATE)
            val appBlockChildMode = appBlockPrefs.getBoolean("child_mode", false)
            
            return isChildMode || appBlockChildMode
        }
        
        /**
         * Start a 30-second camera recording (parent-initiated)
         * Returns: RecordingStartResult indicating success or failure reason
         */
        fun startRecording(context: Context): RecordingStartResult {
            Log.d(TAG, "🎬 startRecording called")
            
            // Only record on child devices
            if (!isChildModeActive(context)) {
                Log.d(TAG, "📱 Not in child mode - skipping recording")
                return RecordingStartResult.NOT_CHILD_MODE
            }
            
            // Check if already recording (persistent state)
            if (isRecordingActive(context)) {
                Log.d(TAG, "⚠️ Already recording - skipping")
                return RecordingStartResult.ALREADY_RECORDING
            }
            
            // Check cooldown
            val cooldownResult = checkCooldown(context)
            if (!cooldownResult.canRecord) {
                Log.d(TAG, "⏰ Cooldown active - ${cooldownResult.remainingSeconds}s remaining")
                return RecordingStartResult.COOLDOWN_ACTIVE
            }
            
            // Check if app is in foreground (child must be using the app)
            if (!isAppInForeground) {
                Log.d(TAG, "📱 App not in foreground - skipping recording")
                return RecordingStartResult.APP_NOT_FOREGROUND
            }
            
            // Check screen state - only record if screen is on and device is unlocked
            if (!isScreenOn) {
                Log.d(TAG, "📱 Screen is off - skipping recording")
                return RecordingStartResult.SCREEN_OFF
            }
            
            if (!isDeviceUnlocked) {
                Log.d(TAG, "🔒 Device is locked - skipping recording")
                return RecordingStartResult.DEVICE_LOCKED
            }
            
            // Check camera permission
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "❌ Camera permission not granted")
                return RecordingStartResult.NO_PERMISSION
            }
            
            // Mark recording as active (persistent)
            setRecordingActive(context, true)
            
            Log.d(TAG, "✅ All checks passed - starting camera recording service...")
            
            val intent = Intent(context, CameraRecordService::class.java).apply {
                action = "START_RECORDING"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            
            return RecordingStartResult.SUCCESS
        }
        
        /**
         * Stop recording manually (if needed before 30 seconds)
         */
        fun stopRecording(context: Context) {
            setRecordingActive(context, false)
            val intent = Intent(context, CameraRecordService::class.java).apply {
                action = "STOP_RECORDING"
            }
            context.startService(intent)
        }
        
        /**
         * Check if recording is in progress (persistent state)
         */
        fun isRecording(): Boolean = instance?.isRecording == true
        
        /**
         * Check if recording is active (persistent storage)
         */
        fun isRecordingActive(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_IS_RECORDING, false)
        }
        
        /**
         * Set recording active state (persistent)
         */
        fun setRecordingActive(context: Context, active: Boolean) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_IS_RECORDING, active).apply()
            Log.d(TAG, "📹 Recording state set to: $active")
        }
        
        /**
         * Check cooldown status
         */
        fun checkCooldown(context: Context): CooldownResult {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val lastRecordingTime = prefs.getLong(KEY_LAST_RECORDING_TIME, 0)
            val currentTime = System.currentTimeMillis()
            val elapsed = currentTime - lastRecordingTime
            
            if (lastRecordingTime == 0L || elapsed >= RECORDING_COOLDOWN_MS) {
                return CooldownResult(canRecord = true, remainingSeconds = 0)
            }
            
            val remainingMs = RECORDING_COOLDOWN_MS - elapsed
            val remainingSeconds = (remainingMs / 1000).toInt()
            return CooldownResult(canRecord = false, remainingSeconds = remainingSeconds)
        }
        
        /**
         * Get cooldown remaining time in seconds
         */
        fun getCooldownRemaining(context: Context): Int {
            return checkCooldown(context).remainingSeconds
        }
        
        /**
         * Record the timestamp of a completed recording (for cooldown)
         */
        fun recordCompletedRecording(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putLong(KEY_LAST_RECORDING_TIME, System.currentTimeMillis()).apply()
            Log.d(TAG, "⏰ Recording timestamp saved for cooldown")
        }
        
        /**
         * Update screen state (called by ScreenStateReceiver)
         */
        fun updateScreenState(screenOn: Boolean, unlocked: Boolean) {
            isScreenOn = screenOn
            isDeviceUnlocked = unlocked
            Log.d(TAG, "📱 Screen state updated: on=$screenOn, unlocked=$unlocked")
        }
        
        /**
         * Update foreground state (called by MainActivity)
         */
        fun updateForegroundState(inForeground: Boolean) {
            isAppInForeground = inForeground
            Log.d(TAG, "📱 Foreground state updated: $inForeground")
        }
        
        /**
         * Called when device is locked - stop any active recording
         * Recording should only happen when device is unlocked in child mode
         */
        fun onDeviceLocked(context: Context) {
            Log.d(TAG, "🔒 Device locked - checking if recording should stop")
            
            // Only process on child devices
            if (!isChildModeActive(context)) {
                Log.d(TAG, "📱 Not in child mode - ignoring lock event")
                return
            }
            
            // Stop any active recording when device is locked
            if (isRecordingActive(context)) {
                Log.d(TAG, "⏹️ Stopping recording due to device lock")
                stopRecording(context)
            }
        }
        
        /**
         * Called when device is unlocked - check for pending recording requests
         * Recording should resume if parent had requested it
         */
        fun onDeviceUnlocked(context: Context) {
            Log.d(TAG, "🔓 Device unlocked - checking for pending recording requests")
            
            // Only process on child devices
            if (!isChildModeActive(context)) {
                Log.d(TAG, "📱 Not in child mode - ignoring unlock event")
                return
            }
            
            // Check for pending recording requests from parent
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    checkForPendingRecordingRequests(context)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error checking pending requests on unlock: ${e.message}")
                }
            }
        }
        
        /**
         * Clean up orphan video files that weren't properly deleted
         */
        fun cleanupOrphanFiles(context: Context) {
            try {
                val dir = File(context.getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
                if (!dir.exists()) return
                
                val files = dir.listFiles() ?: return
                val currentTime = System.currentTimeMillis()
                val maxAge = 24 * 60 * 60 * 1000L // 24 hours
                
                var deletedCount = 0
                for (file in files) {
                    val age = currentTime - file.lastModified()
                    if (age > maxAge) {
                        if (file.delete()) {
                            deletedCount++
                            Log.d(TAG, "🗑️ Deleted orphan file: ${file.name}")
                        }
                    }
                }
                
                if (deletedCount > 0) {
                    Log.d(TAG, "🧹 Cleaned up $deletedCount orphan files")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error cleaning up orphan files: ${e.message}")
            }
        }
        
        /**
         * Check if camera permission is granted
         */
        fun hasCameraPermission(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == 
                PackageManager.PERMISSION_GRANTED
        }
        
        /**
         * Check if microphone permission is granted
         */
        fun hasMicrophonePermission(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == 
                PackageManager.PERMISSION_GRANTED
        }
        
        /**
         * Check for pending recording requests from parent
         */
        suspend fun checkForPendingRecordingRequests(context: Context) {
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
                        ?: flutterPrefs.getString("flutter.device_id_backup", null)
                }
                
                if (supabaseUrl.isNullOrEmpty()) {
                    supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
                }
                if (supabaseKey.isNullOrEmpty()) {
                    supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
                }
                
                if (deviceId.isNullOrEmpty()) {
                    Log.e(TAG, "❌ Missing device ID")
                    return
                }
                
                // First, check for stop requests
                checkForStopRequests(context, deviceId, supabaseUrl, supabaseKey)
                
                // Then check for pending recording requests
                val endpoint = "$supabaseUrl/rest/v1/recording_requests?device_id=eq.$deviceId&status=eq.pending&select=*"
                val url = URL(endpoint)
                val connection = url.openConnection() as HttpURLConnection
                
                connection.requestMethod = "GET"
                connection.setRequestProperty("apikey", supabaseKey)
                connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                
                val responseCode = connection.responseCode
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonArray = JSONArray(response)
                    
                    if (jsonArray.length() > 0) {
                        Log.d(TAG, "📹 Found ${jsonArray.length()} pending recording request(s)")
                        
                        // Validate conditions before starting recording
                        if (!isAppInForeground) {
                            Log.d(TAG, "📱 App not in foreground - postponing recording request")
                            return
                        }
                        if (!isScreenOn) {
                            Log.d(TAG, "📱 Screen is off - postponing recording request")
                            return
                        }
                        if (!isDeviceUnlocked) {
                            Log.d(TAG, "🔒 Device is locked - postponing recording request")
                            return
                        }
                        
                        val cooldownResult = checkCooldown(context)
                        if (!cooldownResult.canRecord) {
                            Log.d(TAG, "⏰ Cooldown active (${cooldownResult.remainingSeconds}s) - postponing request")
                            return
                        }
                        
                        if (isRecordingActive(context)) {
                            Log.d(TAG, "📹 Already recording - skipping request")
                            return
                        }
                        
                        // Process the first pending request
                        val request = jsonArray.getJSONObject(0)
                        val requestId = request.getString("id")
                        
                        // Mark as processing
                        updateRequestStatus(context, requestId, "processing")
                        
                        // Start recording (will do final validation)
                        withContext(Dispatchers.Main) {
                            val result = startRecording(context)
                            Log.d(TAG, "📹 Recording start result: $result")
                            if (result != RecordingStartResult.SUCCESS) {
                                // Revert status if recording failed to start
                                updateRequestStatus(context, requestId, "failed")
                            }
                        }
                    }
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to check pending requests: ${e.message}")
            }
        }
        
        /**
         * Update recording request status
         */
        private suspend fun updateRequestStatus(context: Context, requestId: String, status: String) {
            try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                var supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null) 
                    ?: "https://myxdypywnifdsaorlhsy.supabase.co"
                var supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null) 
                    ?: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
                
                val endpoint = "$supabaseUrl/rest/v1/recording_requests?id=eq.$requestId"
                val url = URL(endpoint)
                val connection = url.openConnection() as HttpURLConnection
                
                connection.requestMethod = "PATCH"
                connection.setRequestProperty("apikey", supabaseKey)
                connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Prefer", "return=minimal")
                connection.doOutput = true
                
                val payload = JSONObject().apply {
                    put("status", status)
                    put("updated_at", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date()))
                }
                
                connection.outputStream.use { os ->
                    os.write(payload.toString().toByteArray(Charsets.UTF_8))
                    os.flush()
                }
                
                Log.d(TAG, "✅ Updated request $requestId status to: $status")
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to update request status: ${e.message}")
            }
        }
        
        /**
         * Check for stop recording requests from parent
         */
        private suspend fun checkForStopRequests(context: Context, deviceId: String, supabaseUrl: String, supabaseKey: String) {
            try {
                val endpoint = "$supabaseUrl/rest/v1/recording_requests?device_id=eq.$deviceId&status=eq.stop_requested&select=*&order=requested_at.desc&limit=1"
                val url = URL(endpoint)
                val connection = url.openConnection() as HttpURLConnection
                
                connection.requestMethod = "GET"
                connection.setRequestProperty("apikey", supabaseKey)
                connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                
                val responseCode = connection.responseCode
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonArray = JSONArray(response)
                    
                    if (jsonArray.length() > 0) {
                        Log.d(TAG, "⏹️ Found stop request from parent")
                        
                        val request = jsonArray.getJSONObject(0)
                        val requestId = request.getString("id")
                        
                        // Stop recording if active
                        if (isRecordingActive(context) || isRecording()) {
                            Log.d(TAG, "⏹️ Stopping recording as requested by parent")
                            withContext(Dispatchers.Main) {
                                stopRecording(context)
                            }
                        }
                        
                        // Mark stop request as processed
                        updateRequestStatus(context, requestId, "stopped")
                    }
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to check stop requests: ${e.message}")
            }
        }
    }
    
    // Camera components
    private var cameraDevice: CameraDevice? = null
    private var cameraCaptureSession: CameraCaptureSession? = null
    private var mediaRecorder: MediaRecorder? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    
    // Recording state
    private var isRecording = false
    private var outputFile: File? = null
    private var recordingStartTime: Long = 0
    private var stopRecordingJob: Job? = null
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        startBackgroundThread()
        
        // Pre-load Google Drive token
        GoogleDriveUploader.loadSavedToken(applicationContext)
        Log.d(TAG, "📱 CameraRecordService created, Drive token loaded: ${GoogleDriveUploader.isInitialized(applicationContext)}")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_RECORDING" -> {
                startForeground(NOTIFICATION_ID, createNotification("Recording video..."))
                startCameraRecording()
            }
            "STOP_RECORDING" -> {
                stopCameraRecording()
            }
        }
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }
    
    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread: ${e.message}")
        }
    }
    
    private fun startCameraRecording() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }
        
        // Check permissions
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "❌ Camera permission not granted")
            stopSelf()
            return
        }
        
        // Add a small delay before accessing camera to let Flutter surface stabilize
        // This helps prevent "Can't acquire next buffer" errors
        backgroundHandler?.postDelayed({
            startCameraRecordingInternal()
        }, 200)
    }

    private fun startCameraRecordingInternal() {
        try {
            val cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
            val cameraId = getCameraId(cameraManager)
            
            if (cameraId == null) {
                Log.e(TAG, "❌ No suitable camera found")
                stopSelf()
                return
            }
            
            // Create output file
            outputFile = createOutputFile()
            
            // Setup MediaRecorder
            setupMediaRecorder()
            
            // Open camera
            openCamera(cameraManager, cameraId)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start camera recording: ${e.message}", e)
            cleanup()
            stopSelf()
        }
    }
    
    private fun getCameraId(cameraManager: CameraManager): String? {
        // Prefer FRONT camera to see child's face (better for monitoring)
        // Front camera is less likely to be blocked than back camera
        for (cameraId in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
                Log.d(TAG, "📷 Using FRONT camera (ID: $cameraId) - will show child's face")
                return cameraId
            }
        }
        // Fallback to back camera
        for (cameraId in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                Log.d(TAG, "📷 Using BACK camera (ID: $cameraId) - front camera not available")
                return cameraId
            }
        }
        // Fallback to any camera
        Log.w(TAG, "⚠️ Using first available camera")
        return cameraManager.cameraIdList.firstOrNull()
    }
    
    private fun setupMediaRecorder() {
        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        
        val hasAudioPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == 
            PackageManager.PERMISSION_GRANTED
        
        mediaRecorder?.apply {
            // IMPORTANT: Order matters! Audio source must be set before video source
            if (hasAudioPermission) {
                setAudioSource(MediaRecorder.AudioSource.MIC)
            }
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            
            // Set encoders AFTER format
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            if (hasAudioPermission) {
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(32000)  // Low audio bitrate
                setAudioSamplingRate(22050)      // Lower sample rate
            }
            
            // Use VGA resolution (640x480) for better compatibility
            // Some devices have issues with very low resolutions
            setVideoSize(640, 480)              // VGA resolution - good compatibility
            setVideoFrameRate(15)               // 15fps - smooth enough for viewing
            setVideoEncodingBitRate(200000)     // 200 Kbps = ~750KB for 30 seconds
            setOutputFile(outputFile?.absolutePath)
            setMaxDuration((MAX_RECORDING_DURATION_MS).toInt())
            
            setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    Log.d(TAG, "⏱️ Max duration reached - stopping recording")
                    stopCameraRecording()
                }
            }
            
            setOnErrorListener { _, what, extra ->
                Log.e(TAG, "❌ MediaRecorder error: what=$what, extra=$extra")
            }
            
            prepare()
        }
        
        Log.d(TAG, "✅ MediaRecorder prepared (640x480, 15fps, 200kbps)")
    }
    
    private fun openCamera(cameraManager: CameraManager, cameraId: String) {
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "❌ Camera permission not granted")
                return
            }
            
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    Log.d(TAG, "✅ Camera opened")
                    cameraDevice = camera
                    createCaptureSession()
                }
                
                override fun onDisconnected(camera: CameraDevice) {
                    Log.d(TAG, "📷 Camera disconnected")
                    camera.close()
                    cameraDevice = null
                }
                
                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "❌ Camera error: $error")
                    camera.close()
                    cameraDevice = null
                    stopSelf()
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            Log.e(TAG, "❌ Failed to open camera: ${e.message}", e)
        }
    }
    
    private fun createCaptureSession() {
        try {
            val recorderSurface = mediaRecorder?.surface ?: run {
                Log.e(TAG, "❌ MediaRecorder surface is null")
                stopSelf()
                return
            }
            
            if (!recorderSurface.isValid) {
                Log.e(TAG, "❌ MediaRecorder surface is invalid")
                stopSelf()
                return
            }
            
            val surfaces = listOf(recorderSurface)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Use OutputConfiguration for newer APIs
                val outputConfigs = surfaces.map { android.hardware.camera2.params.OutputConfiguration(it) }
                val sessionConfig = android.hardware.camera2.params.SessionConfiguration(
                    android.hardware.camera2.params.SessionConfiguration.SESSION_REGULAR,
                    outputConfigs,
                    { command -> backgroundHandler?.post(command) ?: command.run() },
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            Log.d(TAG, "✅ Capture session configured (API 28+)")
                            cameraCaptureSession = session
                            startRecordingInternal()
                        }
                        
                        override fun onConfigureFailed(session: CameraCaptureSession) {
                            Log.e(TAG, "❌ Capture session configuration failed (API 28+)")
                            stopSelf()
                        }
                    }
                )
                cameraDevice?.createCaptureSession(sessionConfig)
            } else {
                @Suppress("DEPRECATION")
                cameraDevice?.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        Log.d(TAG, "✅ Capture session configured")
                        cameraCaptureSession = session
                        startRecordingInternal()
                    }
                    
                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "❌ Capture session configuration failed")
                        stopSelf()
                    }
                }, backgroundHandler)
            }
        } catch (e: CameraAccessException) {
            Log.e(TAG, "❌ Failed to create capture session: ${e.message}", e)
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error creating capture session: ${e.message}", e)
            stopSelf()
        }
    }
    
    private fun startRecordingInternal() {
        try {
            val recorderSurface = mediaRecorder?.surface ?: run {
                Log.e(TAG, "❌ MediaRecorder surface is null in startRecordingInternal")
                stopSelf()
                return
            }
            
            val camera = cameraDevice ?: run {
                Log.e(TAG, "❌ Camera device is null")
                stopSelf()
                return
            }
            
            val captureRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
            captureRequestBuilder.addTarget(recorderSurface)
            
            // Configure capture settings for better quality
            captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AWB_MODE, CameraMetadata.CONTROL_AWB_MODE_AUTO)
            
            // Limit frame rate to reduce buffer pressure on Flutter SurfaceView
            // This helps prevent "Can't acquire next buffer" errors
            captureRequestBuilder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, android.util.Range(15, 15))

            // Start the repeating request FIRST to warm up the camera pipeline
            cameraCaptureSession?.setRepeatingRequest(
                captureRequestBuilder.build(),
                object : CameraCaptureSession.CaptureCallback() {
                    private var frameCount = 0
                    private var recorderStarted = false
                    
                    override fun onCaptureCompleted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        result: TotalCaptureResult
                    ) {
                        frameCount++
                        // Wait for more frames before starting MediaRecorder
                        // This ensures the camera pipeline is warmed up and Flutter surface is stable
                        if (!recorderStarted && frameCount >= 10) {
                            recorderStarted = true
                            backgroundHandler?.post {
                                try {
                                    // Add small delay to let Flutter surface stabilize
                                    Thread.sleep(100)
                                    mediaRecorder?.start()
                                    isRecording = true
                                    recordingStartTime = System.currentTimeMillis()
                                    
                                    Log.d(TAG, "🎥 Camera recording started after $frameCount frames: ${outputFile?.absolutePath}")
                                    
                                    // Schedule auto-stop after 30 seconds
                                    stopRecordingJob = scope.launch {
                                        delay(MAX_RECORDING_DURATION_MS)
                                        if (isRecording) {
                                            Log.d(TAG, "⏱️ 30 seconds elapsed - auto-stopping recording")
                                            withContext(Dispatchers.Main) {
                                                stopCameraRecording()
                                            }
                                        }
                                    }
                                    
                                    // Record the timestamp for cooldown
                                    recordCompletedRecording(this@CameraRecordService)
                                    
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Failed to start MediaRecorder: ${e.message}", e)
                                    scope.launch(Dispatchers.Main) {
                                        cleanup()
                                        stopSelf()
                                    }
                                }
                            }
                        }
                    }
                    
                    override fun onCaptureFailed(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        failure: CaptureFailure
                    ) {
                        Log.e(TAG, "❌ Capture failed: ${failure.reason}")
                    }
                },
                backgroundHandler
            )
            
            Log.d(TAG, "📹 Camera pipeline started, waiting for frames before recording...")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start recording: ${e.message}", e)
            cleanup()
            stopSelf()
        }
    }
    
    private fun stopCameraRecording() {
        if (!isRecording) {
            Log.d(TAG, "Not recording")
            stopSelf()
            return
        }
        
        stopRecordingJob?.cancel()
        stopRecordingJob = null
        
        val durationSeconds = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        
        try {
            cameraCaptureSession?.stopRepeating()
            cameraCaptureSession?.abortCaptures()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping capture session: ${e.message}")
        }
        
        try {
            mediaRecorder?.stop()
            Log.d(TAG, "⏹️ Recording stopped (duration: ${durationSeconds}s)")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recorder: ${e.message}")
        }
        
        val recordedFile = outputFile
        
        // Release camera resources but keep service alive for upload
        cleanupCameraOnly()
        
        // Upload to Google Drive and save metadata using GlobalScope
        // CRITICAL: Use GlobalScope so the job survives service destruction
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 0) {
                val context = applicationContext
                GlobalScope.launch(Dispatchers.IO) {
                    try {
                        Log.d(TAG, "📤 Starting upload in GlobalScope (survives service stop)...")
                        uploadAndSaveRecording(file, durationSeconds)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Upload failed in GlobalScope: ${e.message}", e)
                    } finally {
                        Log.d(TAG, "✅ Upload complete, stopping service")
                        // Stop service only after upload completes
                        withContext(Dispatchers.Main) {
                            try {
                                stopForeground(true)
                                stopSelf()
                            } catch (e: Exception) {
                                Log.e(TAG, "Error stopping service: ${e.message}")
                            }
                        }
                    }
                }
            } else {
                Log.w(TAG, "⚠️ No valid recording file to upload")
                stopForeground(true)
                stopSelf()
            }
        } ?: run {
            Log.w(TAG, "⚠️ No recording file available")
            stopForeground(true)
            stopSelf()
        }
    }
    
    /**
     * Clean up camera resources only, keeping service alive for upload
     */
    private fun cleanupCameraOnly() {
        isRecording = false
        stopRecordingJob?.cancel()
        stopRecordingJob = null
        
        try {
            cameraCaptureSession?.close()
        } catch (e: Exception) {}
        cameraCaptureSession = null
        
        try {
            cameraDevice?.close()
        } catch (e: Exception) {}
        cameraDevice = null
        
        try {
            mediaRecorder?.release()
        } catch (e: Exception) {}
        mediaRecorder = null
        
        Log.d(TAG, "📷 Camera resources released, service kept alive for upload")
    }
    
    private fun cleanup() {
        isRecording = false
        stopRecordingJob?.cancel()
        stopRecordingJob = null
        
        try {
            cameraCaptureSession?.close()
        } catch (e: Exception) {}
        cameraCaptureSession = null
        
        try {
            cameraDevice?.close()
        } catch (e: Exception) {}
        cameraDevice = null
        
        try {
            mediaRecorder?.release()
        } catch (e: Exception) {}
        mediaRecorder = null
    }
    
    private fun createOutputFile(): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val fileName = "SurakshaVideo_$timestamp.mp4"
        
        val dir = File(getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
        if (!dir.exists()) dir.mkdirs()
        
        return File(dir, fileName)
    }
    
    private suspend fun uploadAndSaveRecording(file: File, durationSeconds: Int) {
        val fileSizeKB = file.length() / 1024
        Log.d(TAG, "📤 Processing recording: ${file.name} (${fileSizeKB}KB, ${durationSeconds}s)")
        
        // Validate file exists
        if (!file.exists()) {
            Log.e(TAG, "❌ Recording file does not exist")
            return
        }
        
        // Validate file size (minimum 10KB for a valid video)
        // If file is too small, it's likely black/empty
        if (file.length() < 10 * 1024) {
            Log.e(TAG, "❌ Recording file too small (${fileSizeKB}KB) - likely black screen or empty")
            Log.e(TAG, "   This usually means: camera was covered, no light, or permission denied")
            // Delete the invalid file
            file.delete()
            return
        }

        Log.d(TAG, "✅ Video file validated: ${fileSizeKB}KB")

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
                    ?: flutterPrefs.getString("flutter.device_id_backup", null)
            }
            
            if (supabaseUrl.isNullOrEmpty()) {
                supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
            }
            if (supabaseKey.isNullOrEmpty()) {
                supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
            }
            
            if (deviceId.isNullOrEmpty()) {
                Log.e(TAG, "❌ Missing device ID - cannot upload")
                return
            }
            
            Log.d(TAG, "📱 Device ID: $deviceId")
            
            // Upload to Google Drive with retry
            var driveResult: DriveUploadResult? = null
            var uploadAttempts = 0
            val maxAttempts = 3
            
            while (driveResult == null && uploadAttempts < maxAttempts) {
                uploadAttempts++
                Log.d(TAG, "☁️ Upload attempt $uploadAttempts/$maxAttempts...")
                
                try {
                    driveResult = GoogleDriveUploader.uploadFile(this, file)
                    
                    if (driveResult != null) {
                        Log.d(TAG, "✅ Google Drive upload SUCCESS!")
                        Log.d(TAG, "   📎 File ID: ${driveResult.fileId}")
                        Log.d(TAG, "   🔗 Web Link: ${driveResult.webLink}")
                    } else {
                        Log.w(TAG, "⚠️ Upload returned null - attempt $uploadAttempts")
                        if (uploadAttempts < maxAttempts) {
                            delay(2000L * uploadAttempts) // Exponential backoff
                        }
                    }
                } catch (uploadError: Exception) {
                    Log.e(TAG, "❌ Upload attempt $uploadAttempts failed: ${uploadError.message}")
                    if (uploadAttempts < maxAttempts) {
                        delay(2000L * uploadAttempts)
                    }
                }
            }
            
            // Save metadata to Supabase (even if Drive upload failed)
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
            val timestamp = dateFormat.format(Date())
            
            val status = when {
                driveResult != null -> "uploaded"
                else -> "upload_pending"
            }
            
            val jsonPayload = JSONObject().apply {
                put("device_id", deviceId)
                put("file_name", file.name)
                put("drive_file_id", driveResult?.fileId ?: "")
                put("drive_link", driveResult?.webLink ?: "")
                put("file_size", file.length())
                put("duration_seconds", durationSeconds)
                put("recorded_at", timestamp)
                put("uploaded_at", if (driveResult != null) timestamp else JSONObject.NULL)
                put("status", status)
                put("recording_type", "camera")
            }
            
            Log.d(TAG, "💾 Saving metadata to Supabase...")
            Log.d(TAG, "   Payload: $jsonPayload")
            
            val endpoint = "$supabaseUrl/rest/v1/screen_recordings"
            val url = URL(endpoint)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=representation")  // Get inserted row back
            connection.doOutput = true
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            
            connection.outputStream.use { os ->
                os.write(jsonPayload.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }
            
            val responseCode = connection.responseCode
            
            if (responseCode == HttpURLConnection.HTTP_CREATED || responseCode == HttpURLConnection.HTTP_OK) {
                val responseBody = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "✅ Recording metadata saved to Supabase!")
                Log.d(TAG, "   Response: $responseBody")
                
                // Record completed timestamp for cooldown
                recordCompletedRecording(applicationContext)
                
                // Delete local file after successful upload AND metadata save
                if (driveResult != null) {
                    try {
                        val deleted = file.delete()
                        Log.d(TAG, "🗑️ Local file ${if (deleted) "deleted successfully" else "deletion failed"}")
                        
                        // Verify deletion
                        if (!deleted && file.exists()) {
                            Log.w(TAG, "⚠️ File still exists, attempting forced deletion...")
                            file.deleteOnExit()
                        }
                    } catch (deleteError: Exception) {
                        Log.e(TAG, "❌ Error deleting local file: ${deleteError.message}")
                    }
                } else {
                    Log.d(TAG, "📁 Keeping local file - Drive upload failed")
                }
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Supabase save failed ($responseCode): $errorStream")
            }
            
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in uploadAndSaveRecording: ${e.message}", e)
            e.printStackTrace()
        } finally {
            // Always mark recording as inactive when done
            setRecordingActive(applicationContext, false)
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Camera Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Recording video"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Suraksha Protection")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)  // Minimal priority to avoid UI interference
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)  // Hide from lock screen
            .setShowWhen(false)
            .build()
    }
    
    override fun onDestroy() {
        cleanup()
        stopBackgroundThread()
        scope.cancel()
        instance = null
        super.onDestroy()
    }
}
