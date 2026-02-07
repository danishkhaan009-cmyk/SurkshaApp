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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
        private const val KEY_AUTO_RECORDING_ENABLED = "auto_recording_enabled"
        private const val KEY_AUTO_TRIGGER = "auto_recording_trigger"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_KEY = "supabase_key"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_CURRENT_SESSION_ID = "current_session_id"
        
        // Recording interval in milliseconds (1 minute)
        private const val RECORDING_INTERVAL_MS = 1 * 60 * 1000L
        
        // MediaProjection data - stored for reuse
        var resultCode: Int = 0
        var resultData: Intent? = null
        
        private var instance: ScreenRecordService? = null
        private var isRecordingEnabled = false
        private var currentSessionId: String? = null
        
        fun getInstance(): ScreenRecordService? = instance
        
        /**
         * Set MediaProjection result from activity
         * CRITICAL: Clone the Intent data so it can be reused across sessions
         */
        fun setMediaProjectionResult(code: Int, data: Intent?) {
            resultCode = code
            resultData = data?.clone() as? Intent
            Log.d(TAG, "MediaProjection result set (code=$code, data=${if (resultData != null) "SET" else "NULL"})")
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
            Log.d(TAG, "ScreenRecordService initialized for device: $deviceId")
            ScreenStateReceiver.initializeState(context)
        }
        
        /**
         * Enable/disable recording from parent (manual control)
         */
        fun setRecordingEnabled(context: Context, enabled: Boolean, startedBy: String = "parent") {
            isRecordingEnabled = enabled
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_RECORDING_ENABLED, enabled).apply()
            
            Log.d(TAG, "Manual Recording ${if (enabled) "ENABLED" else "DISABLED"} by $startedBy")
            
            if (enabled) {
                if (isChildModeActive(context)) {
                    // Initialize screen state if not already done
                    ScreenStateReceiver.initializeState(context)
                    
                    // Check actual device state
                    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isInteractive = powerManager.isInteractive
                    
                    Log.d(TAG, "Device state check: static(screen=${ScreenStateReceiver.isScreenOn} unlock=${ScreenStateReceiver.isDeviceUnlocked}) actual(interactive=$isInteractive)")
                    
                    if (isInteractive || (ScreenStateReceiver.isScreenOn && ScreenStateReceiver.isDeviceUnlocked)) {
                        startRecording(context, "parent", "parent_manual")
                    } else {
                        Log.d(TAG, "Device screen off or locked - will record when unlocked")
                    }
                } else {
                    Log.d(TAG, "Not in child mode - setting saved")
                }
            } else {
                stopRecording(context)
            }
        }
        
        /**
         * Enable/disable automatic recording on device unlock or usage
         */
        fun setAutoRecordingEnabled(context: Context, enabled: Boolean, trigger: String = "unlock") {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean(KEY_AUTO_RECORDING_ENABLED, enabled)
                putString(KEY_AUTO_TRIGGER, trigger)
                apply()
            }
            
            Log.d(TAG, "Auto-recording ${if (enabled) "ENABLED" else "DISABLED"} trigger=$trigger")
            
            if (enabled && isChildModeActive(context)) {
                // Initialize screen state if not already done
                ScreenStateReceiver.initializeState(context)
                
                // Check actual device state
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isInteractive = powerManager.isInteractive
                
                if (isInteractive || (ScreenStateReceiver.isScreenOn && ScreenStateReceiver.isDeviceUnlocked)) {
                    val startedBy = if (trigger == "usage" || trigger == "both") "auto_usage" else "auto_unlock"
                    startRecording(context, startedBy, "auto_enabled")
                }
            }
        }
        
        fun isAutoRecordingEnabled(context: Context): Boolean {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_AUTO_RECORDING_ENABLED, false)
        }
        
        fun isRecordingEnabled(context: Context): Boolean {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_RECORDING_ENABLED, false)
        }
        
        fun isChildModeActive(context: Context): Boolean {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (flutterPrefs.getBoolean("flutter.is_child_mode_active", false)) return true
            if (flutterPrefs.getBoolean("flutter.child_mode_backup", false)) return true
            return context.getSharedPreferences("app_block_prefs", Context.MODE_PRIVATE)
                .getBoolean("child_mode", false)
        }
        
        /**
         * Start recording - main entry point
         */
        fun startRecording(context: Context, startedBy: String = "parent", triggerEvent: String = "parent_manual") {
            // Ensure screen state is current
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val actualInteractive = powerManager.isInteractive
            
            Log.d(TAG, "startRecording: by=$startedBy trigger=$triggerEvent")
            Log.d(TAG, "  child=${isChildModeActive(context)} screen=${ScreenStateReceiver.isScreenOn} unlock=${ScreenStateReceiver.isDeviceUnlocked} projection=${resultData != null} interactive=$actualInteractive")
            
            if (!isChildModeActive(context)) {
                Log.d(TAG, "Not in child mode - skip")
                return
            }
            
            // Skip if already recording
            if (instance?.isRecording == true) {
                Log.d(TAG, "Already recording - skip duplicate")
                return
            }
            
            // Verify trigger type is enabled
            val shouldStart = when {
                startedBy == "parent" -> true
                startedBy.startsWith("auto_") && isAutoRecordingEnabled(context) -> true
                else -> false
            }
            if (!shouldStart) {
                Log.d(TAG, "Recording not enabled for trigger: $startedBy")
                return
            }
            
            if (resultData == null) {
                Log.e(TAG, "No MediaProjection permission - user must grant it first")
                return
            }
            
            try {
                val intent = Intent(context, ScreenRecordService::class.java).apply {
                    action = "START"
                    putExtra("started_by", startedBy)
                    putExtra("trigger_event", triggerEvent)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                Log.d(TAG, "Service start command sent")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service: ${e.message}", e)
            }
        }
        
        fun stopRecording(context: Context) {
            Log.d(TAG, "stopRecording called")
            try {
                val intent = Intent(context, ScreenRecordService::class.java).apply { action = "STOP" }
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping: ${e.message}")
                instance?.stopRecordingInternal()
            }
        }
        
        /**
         * Handle screen state changes
         */
        fun onScreenStateChanged(context: Context, isScreenOn: Boolean, isUnlocked: Boolean) {
            if (!isChildModeActive(context)) return
            
            val isManualEnabled = isRecordingEnabled(context)
            val isAutoEnabled = isAutoRecordingEnabled(context)
            if (!isManualEnabled && !isAutoEnabled) return
            
            if (isScreenOn && isUnlocked) {
                // Device unlocked - start or resume recording
                Log.d(TAG, "Screen ON & Unlocked - checking recording modes")
                
                if (instance?.isPaused == true) {
                    // Resume paused recording
                    Log.d(TAG, "Resuming paused recording")
                    val intent = Intent(context, ScreenRecordService::class.java).apply { action = "RESUME" }
                    try { context.startService(intent) } catch (e: Exception) {}
                    return
                }
                
                when {
                    isManualEnabled -> startRecording(context, "parent", "screen_unlocked")
                    isAutoEnabled -> {
                        val trigger = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .getString(KEY_AUTO_TRIGGER, "unlock")
                        if (trigger == "unlock" || trigger == "both") {
                            startRecording(context, "auto_unlock", "device_unlock")
                        }
                    }
                }
            } else if (!isScreenOn) {
                // Screen off - pause recording (don't stop)
                Log.d(TAG, "Screen OFF - pausing recording")
                instance?.pauseRecording()
            }
        }
        
        fun onAppUsageDetected(context: Context) {
            if (!isChildModeActive(context)) return
            if (!isAutoRecordingEnabled(context)) return
            
            val trigger = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_AUTO_TRIGGER, "unlock")
            if (trigger == "usage" || trigger == "both") {
                startRecording(context, "auto_usage", "app_launch")
            }
        }
        
        /**
         * Sync recording settings from Supabase
         */
        suspend fun syncRecordingSettings(context: Context) {
            try {
                val deviceId = getDeviceId(context) ?: return
                val supabaseUrl = getSupabaseUrl(context)
                val supabaseKey = getSupabaseKey(context)
                
                val endpoint = "$supabaseUrl/rest/v1/screen_recording_settings?device_id=eq.$deviceId&select=recording_enabled"
                val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("apikey", supabaseKey)
                    setRequestProperty("Authorization", "Bearer $supabaseKey")
                    setRequestProperty("Content-Type", "application/json")
                    connectTimeout = 10000; readTimeout = 10000
                }
                
                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonArray = JSONArray(response)
                    if (jsonArray.length() > 0) {
                        val enabled = jsonArray.getJSONObject(0).optBoolean("recording_enabled", false)
                        isRecordingEnabled = enabled
                        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .edit().putBoolean(KEY_RECORDING_ENABLED, enabled).apply()
                        
                        if (enabled && isChildModeActive(context)) {
                            // Check actual device state
                            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (powerManager.isInteractive || (ScreenStateReceiver.isScreenOn && ScreenStateReceiver.isDeviceUnlocked)) {
                                withContext(Dispatchers.Main) { startRecording(context, "parent", "settings_sync") }
                            }
                        }
                    }
                }
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to sync settings: ${e.message}")
            }
        }
        
        // Credential helpers
        private fun getDeviceId(context: Context): String? {
            var id = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_DEVICE_ID, null)
            if (id.isNullOrEmpty()) id = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE).getString("device_id", null)
            if (id.isNullOrEmpty()) {
                val fp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                id = fp.getString("flutter.child_device_id", null) ?: fp.getString("flutter.device_id_backup", null)
            }
            return id
        }
        
        private fun getSupabaseUrl(context: Context): String {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_SUPABASE_URL, null) ?: "https://myxdypywnifdsaorlhsy.supabase.co"
        }
        
        private fun getSupabaseKey(context: Context): String {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_SUPABASE_KEY, null) ?: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
        }
        
        suspend fun createRecordingSession(context: Context, startedBy: String, triggerEvent: String): String? {
            return withContext(Dispatchers.IO) {
                try {
                    val deviceId = getDeviceId(context) ?: return@withContext null
                    val supabaseUrl = getSupabaseUrl(context)
                    val supabaseKey = getSupabaseKey(context)
                    
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                    
                    val jsonPayload = JSONObject().apply {
                        put("device_id", deviceId)
                        put("session_type", "screen")
                        put("status", "active")
                        put("started_by", startedBy)
                        put("trigger_event", triggerEvent)
                        put("started_at", dateFormat.format(Date()))
                    }
                    
                    val connection = (URL("$supabaseUrl/rest/v1/recording_sessions").openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("apikey", supabaseKey)
                        setRequestProperty("Authorization", "Bearer $supabaseKey")
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Prefer", "return=representation")
                        doOutput = true; connectTimeout = 10000; readTimeout = 10000
                    }
                    connection.outputStream.use { it.write(jsonPayload.toString().toByteArray(Charsets.UTF_8)); it.flush() }
                    
                    val responseCode = connection.responseCode
                    if (responseCode == HttpURLConnection.HTTP_CREATED || responseCode == HttpURLConnection.HTTP_OK) {
                        val response = connection.inputStream.bufferedReader().use { it.readText() }
                        val jsonArray = JSONArray(response)
                        if (jsonArray.length() > 0) {
                            val sessionId = jsonArray.getJSONObject(0).getString("id")
                            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                                .edit().putString(KEY_CURRENT_SESSION_ID, sessionId).apply()
                            currentSessionId = sessionId
                            Log.d(TAG, "Session created: $sessionId")
                            return@withContext sessionId
                        }
                    } else {
                        val err = connection.errorStream?.bufferedReader()?.use { it.readText() }
                        Log.e(TAG, "Session creation failed: $responseCode - $err")
                    }
                    connection.disconnect()
                } catch (e: Exception) {
                    Log.e(TAG, "Session creation error: ${e.message}", e)
                }
                null
            }
        }
        
        suspend fun updateRecordingSession(context: Context, sessionId: String, status: String = "active",
                                          totalDuration: Int = 0, segmentsCount: Int = 0) {
            withContext(Dispatchers.IO) {
                try {
                    val supabaseUrl = getSupabaseUrl(context)
                    val supabaseKey = getSupabaseKey(context)
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                    
                    val jsonPayload = JSONObject().apply {
                        put("status", status)
                        put("total_duration_seconds", totalDuration)
                        put("segments_count", segmentsCount)
                        put("last_upload_at", dateFormat.format(Date()))
                        if (status == "stopped") put("stopped_at", dateFormat.format(Date()))
                    }
                    
                    val connection = (URL("$supabaseUrl/rest/v1/recording_sessions?id=eq.$sessionId").openConnection() as HttpURLConnection).apply {
                        requestMethod = "PATCH"
                        setRequestProperty("apikey", supabaseKey)
                        setRequestProperty("Authorization", "Bearer $supabaseKey")
                        setRequestProperty("Content-Type", "application/json")
                        doOutput = true; connectTimeout = 10000; readTimeout = 10000
                    }
                    connection.outputStream.use { it.write(jsonPayload.toString().toByteArray(Charsets.UTF_8)); it.flush() }
                    
                    if (connection.responseCode == HttpURLConnection.HTTP_OK || connection.responseCode == HttpURLConnection.HTTP_NO_CONTENT) {
                        Log.d(TAG, "Session updated: $sessionId ($status)")
                    }
                    connection.disconnect()
                } catch (e: Exception) {
                    Log.e(TAG, "Session update error: ${e.message}", e)
                }
            }
        }
    }
    
    // ====================================================================
    // INSTANCE FIELDS
    // ====================================================================
    
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaProjection: MediaProjection? = null
    private var mediaProjectionCallback: MediaProjection.Callback? = null
    private var outputFile: File? = null
    var isRecording = false
        private set
    var isPaused = false
        private set
    private var screenStateReceiver: ScreenStateReceiver? = null
    private var recordingStartTime: Long = 0
    private var segmentsUploaded: Int = 0
    private var totalRecordingDuration: Int = 0
    private var recordingStartedBy: String = "parent"
    private var recordingTriggerEvent: String = "parent_manual"
    private var wakeLock: PowerManager.WakeLock? = null
    
    private var uploadTimer: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // ====================================================================
    // SERVICE LIFECYCLE
    // ====================================================================
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        registerScreenStateReceiver()
        acquireWakeLock()
        Log.d(TAG, "Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                recordingStartedBy = intent.getStringExtra("started_by") ?: "parent"
                recordingTriggerEvent = intent.getStringExtra("trigger_event") ?: "parent_manual"
                
                // MUST call startForeground immediately
                startForeground(NOTIFICATION_ID, createNotification("Preparing recording...", recordingStartedBy))
                
                // Create session in background but start recording without waiting
                scope.launch {
                    try { createRecordingSession(applicationContext, recordingStartedBy, recordingTriggerEvent) }
                    catch (e: Exception) { Log.e(TAG, "Session creation failed: ${e.message}") }
                    
                    withContext(Dispatchers.Main) { startRecordingInternal() }
                }
            }
            "STOP" -> stopRecordingInternal()
            "PAUSE" -> pauseRecording()
            "RESUME" -> resumeRecording()
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed (app killed)")
        
        if (isRecording || isRecordingEnabled(applicationContext) || isAutoRecordingEnabled(applicationContext)) {
            Log.d(TAG, "Scheduling service restart...")
            
            getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean("was_recording", isRecording).apply()
            
            val restartIntent = Intent(applicationContext, ScreenRecordService::class.java).apply {
                action = "START"
                putExtra("started_by", recordingStartedBy)
                putExtra("trigger_event", "service_restart")
            }
            
            val pendingIntent = PendingIntent.getService(
                applicationContext, NOTIFICATION_ID, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 3000,
                pendingIntent
            )
        }
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        
        // Try to save current segment
        if (isRecording) {
            try {
                mediaRecorder?.stop()
                outputFile?.let { file ->
                    if (file.exists() && file.length() > 10 * 1024) {
                        val dur = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
                        scope.launch { uploadAndSaveRecording(file, dur) }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error saving final segment: ${e.message}")
            }
        }
        
        releaseWakeLock()
        cleanupResources()
        screenStateReceiver?.let { try { unregisterReceiver(it) } catch (e: Exception) {} }
        scope.cancel()
        instance = null
        super.onDestroy()
    }
    
    // ====================================================================
    // RECORDING CORE - FIX FOR BLACK SCREEN
    // ====================================================================
    
    private fun startRecordingInternal() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }
        
        // Re-initialize screen state to ensure accuracy
        ScreenStateReceiver.initializeState(applicationContext)
        
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        val isInteractive = powerManager.isInteractive
        val isLocked = keyguardManager.isKeyguardLocked
        
        Log.d(TAG, "startRecordingInternal: interactive=$isInteractive locked=$isLocked static(screen=${ScreenStateReceiver.isScreenOn} unlock=${ScreenStateReceiver.isDeviceUnlocked})")
        
        // Check if device is actually active and unlocked
        if (!isInteractive || isLocked) {
            Log.d(TAG, "Device not ready for recording (interactive=$isInteractive locked=$isLocked) - pausing")
            isPaused = true
            updateNotification("Waiting for device unlock...")
            return
        }
        
        Log.d(TAG, "Device is ACTIVE and UNLOCKED - proceeding with recording")
        
        if (resultData == null) {
            Log.e(TAG, "No MediaProjection permission")
            stopSelf()
            return
        }
        
        try {
            // CRITICAL: Clone the intent each time to avoid "already consumed" error on Android 11+
            val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val clonedData = resultData!!.clone() as Intent
            mediaProjection = projectionManager.getMediaProjection(resultCode, clonedData)
            
            if (mediaProjection == null) {
                Log.e(TAG, "Failed to get MediaProjection")
                stopSelf()
                return
            }
            
            // Register callback for projection lifecycle
            mediaProjectionCallback = object : MediaProjection.Callback() {
                override fun onStop() {
                    Log.d(TAG, "MediaProjection stopped externally")
                    mainHandler.post {
                        isRecording = false
                        cleanupResources()
                    }
                }
            }
            mediaProjection?.registerCallback(mediaProjectionCallback!!, mainHandler)
            
            // Get screen dimensions - use REDUCED resolution (720p) to prevent black screen
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(metrics)
            
            val targetShortSide = 720
            val scale = minOf(1.0f, targetShortSide.toFloat() / minOf(metrics.widthPixels, metrics.heightPixels).toFloat())
            val screenWidth = ((metrics.widthPixels * scale).toInt() / 16) * 16
            val screenHeight = ((metrics.heightPixels * scale).toInt() / 16) * 16
            val screenDensity = metrics.densityDpi
            
            Log.d(TAG, "Recording at ${screenWidth}x${screenHeight} (scale=${String.format("%.2f", scale)})")
            
            outputFile = createOutputFile()
            
            // Setup MediaRecorder
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
                setVideoEncodingBitRate(2 * 1024 * 1024)  // 2 Mbps
                setVideoFrameRate(15)                       // 15 fps - saves battery
                setVideoSize(screenWidth, screenHeight)
                setOutputFile(outputFile?.absolutePath)
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaRecorder error: what=$what extra=$extra")
                    mainHandler.post { handleRecordingError() }
                }
                
                prepare()
            }
            
            // Get surface BEFORE creating virtual display
            val recorderSurface = mediaRecorder?.surface
            if (recorderSurface == null) {
                Log.e(TAG, "MediaRecorder surface is null")
                cleanupResources()
                stopSelf()
                return
            }
            
            // KEY FIX: Use ONLY AUTO_MIRROR flag
            // VIRTUAL_DISPLAY_FLAG_PRESENTATION causes black screen on many devices!
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "SurakshaScreenCapture",
                screenWidth,
                screenHeight,
                screenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                recorderSurface,
                object : VirtualDisplay.Callback() {
                    override fun onPaused() { Log.d(TAG, "VirtualDisplay paused") }
                    override fun onResumed() { Log.d(TAG, "VirtualDisplay resumed") }
                    override fun onStopped() { Log.d(TAG, "VirtualDisplay stopped") }
                },
                mainHandler
            )
            
            if (virtualDisplay == null) {
                Log.e(TAG, "Failed to create VirtualDisplay")
                cleanupResources()
                stopSelf()
                return
            }
            
            // KEY FIX: Wait 300ms for VirtualDisplay to fully initialize before starting recorder
            // Starting immediately causes black frames
            mainHandler.postDelayed({
                try {
                    mediaRecorder?.start()
                    isRecording = true
                    isPaused = false
                    recordingStartTime = System.currentTimeMillis()
                    
                    // Update notification
                    val nm = getSystemService(NotificationManager::class.java)
                    nm.notify(NOTIFICATION_ID, createNotification("Recording screen...", recordingStartedBy))
                    
                    Log.d(TAG, "Screen recording STARTED: ${outputFile?.name}")
                    startPeriodicUploadTimer()
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start MediaRecorder: ${e.message}", e)
                    handleRecordingError()
                }
            }, 300)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}", e)
            handleRecordingError()
        }
    }
    
    /**
     * Pause recording when screen turns off
     * Saves current segment and releases display resources
     */
    fun pauseRecording() {
        if (!isRecording) return
        
        Log.d(TAG, "Pausing recording (screen off)")
        isPaused = true
        
        val durationSeconds = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        totalRecordingDuration += durationSeconds
        
        try {
            mediaRecorder?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping for pause: ${e.message}")
        }
        
        val recordedFile = outputFile
        
        // Release display/recorder but KEEP mediaProjection reference info (resultCode/resultData)
        virtualDisplay?.release()
        virtualDisplay = null
        mediaRecorder?.release()
        mediaRecorder = null
        // Stop projection - we'll get a new one on resume
        try {
            val cb = mediaProjectionCallback
            if (cb != null) mediaProjection?.unregisterCallback(cb)
            mediaProjection?.stop()
        } catch (e: Exception) {}
        mediaProjection = null
        
        isRecording = false
        
        // Upload segment
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 10 * 1024) {
                scope.launch {
                    uploadAndSaveRecording(file, durationSeconds)
                    segmentsUploaded++
                    currentSessionId?.let { sid ->
                        updateRecordingSession(applicationContext, sid, "paused", totalRecordingDuration, segmentsUploaded)
                    }
                }
            } else {
                file.delete()
            }
        }
        
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, createNotification("Recording paused (screen off)", recordingStartedBy))
    }
    
    /**
     * Resume recording when device unlocks
     */
    private fun resumeRecording() {
        if (isRecording) return
        if (!isPaused) return
        
        Log.d(TAG, "Resuming recording (device unlocked)")
        isPaused = false
        startRecordingInternal()
    }
    
    private fun stopRecordingInternal() {
        Log.d(TAG, "stopRecordingInternal (recording=$isRecording paused=$isPaused)")
        
        uploadTimer?.cancel()
        uploadTimer = null
        
        if (!isRecording && !isPaused) {
            stopForeground(true)
            stopSelf()
            return
        }
        
        var recordedFile: File? = null
        val durationSeconds = if (isRecording) {
            ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        } else 0
        totalRecordingDuration += durationSeconds
        
        if (isRecording) {
            try {
                mediaRecorder?.stop()
                recordedFile = outputFile
                Log.d(TAG, "Recording stopped (${durationSeconds}s)")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping: ${e.message}")
            }
        }
        
        cleanupResources()
        isRecording = false
        isPaused = false
        
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 10 * 1024) {
                scope.launch {
                    uploadAndSaveRecording(file, durationSeconds)
                    segmentsUploaded++
                    currentSessionId?.let { sid ->
                        updateRecordingSession(applicationContext, sid, "stopped", totalRecordingDuration, segmentsUploaded)
                    }
                    currentSessionId = null
                    applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit().remove(KEY_CURRENT_SESSION_ID).apply()
                }
            } else {
                file.delete()
            }
        }
        
        stopForeground(true)
        stopSelf()
    }
    
    // ====================================================================
    // PERIODIC UPLOAD (5-min segments)
    // ====================================================================
    
    private fun startPeriodicUploadTimer() {
        uploadTimer?.cancel()
        uploadTimer = scope.launch {
            while (isActive && isRecording) {
                delay(RECORDING_INTERVAL_MS)
                if (isRecording) {
                    Log.d(TAG, "5 min elapsed - rotating segment")
                    withContext(Dispatchers.Main) { saveAndRestartRecording() }
                }
            }
        }
    }
    
    private fun saveAndRestartRecording() {
        if (!isRecording) return
        
        val durationSeconds = ((System.currentTimeMillis() - recordingStartTime) / 1000).toInt()
        totalRecordingDuration += durationSeconds
        
        try { mediaRecorder?.stop() }
        catch (e: Exception) { Log.e(TAG, "Error stopping segment: ${e.message}") }
        
        val recordedFile = outputFile
        
        virtualDisplay?.release()
        virtualDisplay = null
        mediaRecorder?.release()
        mediaRecorder = null
        // Stop old projection - will get fresh one
        try {
            val cb2 = mediaProjectionCallback
            if (cb2 != null) mediaProjection?.unregisterCallback(cb2)
            mediaProjection?.stop()
        } catch (e: Exception) {}
        mediaProjection = null
        isRecording = false
        
        recordedFile?.let { file ->
            if (file.exists() && file.length() > 10 * 1024) {
                scope.launch {
                    uploadAndSaveRecording(file, durationSeconds)
                    segmentsUploaded++
                    currentSessionId?.let { sid ->
                        updateRecordingSession(applicationContext, sid, "active", totalRecordingDuration, segmentsUploaded)
                    }
                }
            } else {
                file.delete()
            }
        }
        
        // Check if screen is still on before starting new segment
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (powerManager.isInteractive) {
            // Small delay between segments
            mainHandler.postDelayed({
                startRecordingInternal()
            }, 500)
        } else {
            isPaused = true
        }
    }
    
    // ====================================================================
    // ERROR HANDLING
    // ====================================================================
    
    private fun handleRecordingError() {
        cleanupResources()
        isRecording = false
        
        mainHandler.postDelayed({
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (pm.isInteractive && resultData != null) {
                Log.d(TAG, "Retrying recording after error")
                startRecordingInternal()
            } else {
                isPaused = true
            }
        }, 2000)
    }
    
    // ====================================================================
    // RESOURCE MANAGEMENT
    // ====================================================================
    
    private fun cleanupResources() {
        uploadTimer?.cancel()
        uploadTimer = null
        try { virtualDisplay?.release() } catch (e: Exception) {}
        virtualDisplay = null
        try { mediaRecorder?.release() } catch (e: Exception) {}
        mediaRecorder = null
        try {
            val cb3 = mediaProjectionCallback
            if (cb3 != null) mediaProjection?.unregisterCallback(cb3)
            mediaProjection?.stop()
        } catch (e: Exception) {}
        mediaProjection = null
        mediaProjectionCallback = null
    }
    
    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SurakshaApp::ScreenRecord")
        wakeLock?.acquire(6 * 60 * 60 * 1000L) // 6 hours max
        Log.d(TAG, "WakeLock acquired")
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }
    
    private fun registerScreenStateReceiver() {
        screenStateReceiver = ScreenStateReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenStateReceiver, filter)
    }
    
    private fun createOutputFile(): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
        } else {
            @Suppress("DEPRECATION")
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
        }
        if (!dir.exists()) dir.mkdirs()
        return File(dir, "SurakshaRecord_$timestamp.mp4")
    }
    
    // ====================================================================
    // UPLOAD & SAVE
    // ====================================================================
    
    /**
     * Retry uploading local-only recordings that failed due to token issues.
     * Scans the recordings directory for .mp4 files and tries to upload them.
     * Called when a fresh token becomes available.
     */
    suspend fun retryPendingUploads() {
        try {
            if (!GoogleDriveUploader.isInitialized(applicationContext)) {
                Log.d(TAG, "⏭️ Skip retry: Drive not initialized")
                return
            }
            
            val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
            } else {
                @Suppress("DEPRECATION")
                File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "SurakshaRecordings")
            }
            
            if (!dir.exists()) return
            
            val pendingFiles = dir.listFiles { f -> f.extension == "mp4" && f.length() > 0 }
            if (pendingFiles.isNullOrEmpty()) {
                Log.d(TAG, "📂 No pending uploads found")
                return
            }
            
            Log.d(TAG, "🔄 Found ${pendingFiles.size} pending uploads, retrying...")
            
            for (file in pendingFiles) {
                try {
                    Log.d(TAG, "📤 Retrying upload: ${file.name}")
                    val result = GoogleDriveUploader.uploadFile(applicationContext, file)
                    if (result != null) {
                        Log.d(TAG, "✅ Retry upload success: ${result.fileId}")
                        
                        // Update Supabase record status
                        val deviceId = getDeviceId(applicationContext)
                        val supabaseUrl = getSupabaseUrl(applicationContext)
                        val supabaseKey = getSupabaseKey(applicationContext)
                        
                        if (deviceId != null) {
                            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                            val now = dateFormat.format(Date())
                            
                            val updatePayload = JSONObject().apply {
                                put("drive_file_id", result.fileId)
                                put("drive_link", result.webLink ?: "")
                                put("uploaded_at", now)
                                put("status", "uploaded")
                            }
                            
                            val endpoint = "$supabaseUrl/rest/v1/screen_recordings?device_id=eq.$deviceId&file_name=eq.${file.name}&status=eq.local_only"
                            val conn = URL(endpoint).openConnection() as HttpURLConnection
                            conn.requestMethod = "PATCH"
                            conn.setRequestProperty("apikey", supabaseKey)
                            conn.setRequestProperty("Authorization", "Bearer $supabaseKey")
                            conn.setRequestProperty("Content-Type", "application/json")
                            conn.setRequestProperty("Prefer", "return=minimal")
                            conn.doOutput = true
                            conn.connectTimeout = 10000; conn.readTimeout = 10000
                            conn.outputStream.use { os ->
                                os.write(updatePayload.toString().toByteArray(Charsets.UTF_8))
                                os.flush()
                            }
                            val code = conn.responseCode
                            conn.disconnect()
                            Log.d(TAG, "   Supabase update: $code")
                        }
                        
                        // Delete local file after successful upload
                        file.delete()
                        Log.d(TAG, "🗑️ Deleted local file: ${file.name}")
                    } else {
                        Log.w(TAG, "⚠️ Retry upload failed for: ${file.name}")
                        // Stop retrying remaining files if upload fails (token probably still bad)
                        break
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Retry upload error for ${file.name}: ${e.message}")
                    break
                }
                
                // Small delay between retries to avoid overwhelming the API
                kotlinx.coroutines.delay(2000)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ retryPendingUploads error: ${e.message}", e)
        }
    }
    
    private suspend fun uploadAndSaveRecording(file: File, durationSeconds: Int) {
        Log.d(TAG, "Uploading: ${file.name} (${file.length()} bytes, ${durationSeconds}s)")
        
        try {
            val deviceId = getDeviceId(applicationContext) ?: return
            val supabaseUrl = getSupabaseUrl(applicationContext)
            val supabaseKey = getSupabaseKey(applicationContext)
            
            // Upload to Google Drive with retry logic (3 attempts)
            var driveResult: DriveUploadResult? = null
            var uploadAttempts = 0
            val maxAttempts = 3
            
            if (GoogleDriveUploader.isInitialized()) {
                while (driveResult == null && uploadAttempts < maxAttempts) {
                    uploadAttempts++
                    Log.d(TAG, "☁️ Upload attempt $uploadAttempts/$maxAttempts...")
                    try {
                        driveResult = GoogleDriveUploader.uploadFile(applicationContext, file)
                        if (driveResult != null) {
                            Log.d(TAG, "Drive upload OK: ${driveResult.fileId}")
                        } else {
                            Log.w(TAG, "⚠️ Upload returned null - attempt $uploadAttempts")
                            if (uploadAttempts < maxAttempts) {
                                kotlinx.coroutines.delay(3000L * uploadAttempts) // Backoff: 3s, 6s
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Upload attempt $uploadAttempts failed: ${e.message}")
                        if (uploadAttempts < maxAttempts) {
                            kotlinx.coroutines.delay(3000L * uploadAttempts)
                        }
                    }
                }
            } else {
                Log.w(TAG, "⚠️ GoogleDriveUploader not initialized, trying to load token...")
                GoogleDriveUploader.loadSavedToken(applicationContext)
                if (GoogleDriveUploader.isInitialized()) {
                    try {
                        driveResult = GoogleDriveUploader.uploadFile(applicationContext, file)
                        if (driveResult != null) Log.d(TAG, "Drive upload OK after token load: ${driveResult.fileId}")
                    } catch (e: Exception) {
                        Log.e(TAG, "Drive upload failed after token load: ${e.message}")
                    }
                } else {
                    Log.e(TAG, "❌ No Drive token available - recording will be local_only")
                }
            }
            
            // Save metadata to Supabase
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
            
            val connection = (URL("$supabaseUrl/rest/v1/screen_recordings").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("apikey", supabaseKey)
                setRequestProperty("Authorization", "Bearer $supabaseKey")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Prefer", "return=minimal")
                doOutput = true; connectTimeout = 10000; readTimeout = 10000
            }
            connection.outputStream.use { it.write(jsonPayload.toString().toByteArray(Charsets.UTF_8)); it.flush() }
            
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_CREATED || responseCode == HttpURLConnection.HTTP_OK) {
                Log.d(TAG, "Metadata saved to Supabase")
                if (driveResult != null) {
                    file.delete()
                    Log.d(TAG, "Local file deleted after upload")
                }
            } else {
                val err = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "Supabase save failed: $responseCode - $err")
            }
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Upload error: ${e.message}", e)
        }
    }
    
    // ====================================================================
    // NOTIFICATIONS
    // ====================================================================
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Screen Recording", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Parental monitoring"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String, startedBy: String = "parent"): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Suraksha Protection Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun updateNotification(text: String) {
        val notification = createNotification(text, recordingStartedBy)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
