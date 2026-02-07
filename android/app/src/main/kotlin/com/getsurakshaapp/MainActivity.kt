package com.getsurakshaapp

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.os.Bundle
import java.util.*
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.util.Log
import android.text.TextUtils
import android.app.AppOpsManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import android.net.VpnService
import android.media.projection.MediaProjectionManager
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import android.app.Activity

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "parental_control/permissions"
    private var methodChannel: MethodChannel? = null
    
    companion object {
        private const val REQUEST_MEDIA_PROJECTION = 1001
        private const val REQUEST_GOOGLE_SIGN_IN = 1002
        private const val REQUEST_CAMERA_PERMISSION = 1003
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize screen state on app startup
        ScreenStateReceiver.initializeState(applicationContext)
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📱 App resumed")
        
        // Notify ScreenRecordService about app usage (for auto-recording)
        ScreenRecordService.onAppUsageDetected(applicationContext)
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "📱 App paused")
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getForegroundApp" -> {
                    val pkg = getForegroundAppPackage()
                    if (pkg != null) result.success(pkg) else result.success("")
                }
                "getForegroundAppEvent" -> {
                    val pkg = getForegroundAppUsingEvents()
                    if (pkg != null) result.success(pkg) else result.success("")
                }
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "requestAccessibility" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "requestUsageAccess" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
                }
                "requestNotificationAccess" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "requestOverlay" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityEnabled())
                }
                "isUsageAccessGranted" -> {
                    result.success(isUsageAccessGranted())
                }
                "isDeviceAdminEnabled" -> {
                    result.success(isDeviceAdminEnabled())
                }
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationAccessGranted())
                }
                "isOverlayGranted" -> {
                    result.success(isOverlayPermissionGranted())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "setLockedApps" -> {
                    val apps = call.argument<List<String>>("apps") ?: emptyList()
                    AppBlockService.setLockedApps(apps.toSet())
                    result.success(true)
                }
                "setAppLockPin" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    val pkg = call.argument<String>("package")
                    AppBlockService.setAppLockPin(pin, pkg)
                    result.success(true)
                }
                "setChildMode" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    AppBlockService.setChildMode(active)
                    result.success(true)
                }
                "initUrlBlockService" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val supabaseUrl = call.argument<String>("supabaseUrl")
                    val supabaseKey = call.argument<String>("supabaseKey")
                    if (deviceId != null && supabaseUrl != null && supabaseKey != null) {
                        UrlBlockService.initialize(applicationContext, supabaseUrl, supabaseKey, deviceId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "deviceId, supabaseUrl, and supabaseKey required", null)
                    }
                }
                "syncBlockedUrls" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        UrlBlockService.syncBlockedUrls(applicationContext)
                    }
                    result.success(true)
                }
                "getLockedApps" -> {
                    result.success(AppBlockService.getLockedApps().toList())
                }
                "startMonitoringService" -> {
                    MonitoringService.start(applicationContext)
                    result.success(true)
                }
                "stopMonitoringService" -> {
                    MonitoringService.stop(applicationContext)
                    result.success(true)
                }
                // Location Service Methods for persistent background tracking
                "startLocationService" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val supabaseUrl = call.argument<String>("supabaseUrl")
                    val supabaseKey = call.argument<String>("supabaseKey")
                    if (deviceId != null && supabaseUrl != null && supabaseKey != null) {
                        LocationService.start(applicationContext, deviceId, supabaseUrl, supabaseKey)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "deviceId, supabaseUrl, and supabaseKey are required", null)
                    }
                }
                "stopLocationService" -> {
                    LocationService.stop(applicationContext)
                    result.success(true)
                }
                "isLocationServiceRunning" -> {
                    result.success(LocationService.isRunning(applicationContext))
                }
                "getLocationServiceDeviceId" -> {
                    result.success(LocationService.getDeviceId(applicationContext))
                }
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "requestBackgroundLocationPermission" -> {
                    openBackgroundLocationSettings()
                    result.success(true)
                }
                "scheduleLocationWorker" -> {
                    LocationWorker.schedulePeriodicWork(applicationContext)
                    result.success(true)
                }
                "cancelLocationWorker" -> {
                    LocationWorker.cancelPeriodicWork(applicationContext)
                    result.success(true)
                }
                "isLocationWorkerScheduled" -> {
                    // Use coroutine to call suspend function
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val isScheduled = LocationWorker.isWorkScheduled(applicationContext)
                            runOnUiThread {
                                result.success(isScheduled)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.success(false)
                            }
                        }
                    }
                }
                "syncDeviceId" -> {
                    // Sync device ID from Flutter to native SharedPreferences for LocationWorker
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        val prefs = getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putString("device_id", deviceId).apply()
                        Log.d(TAG, "✅ Device ID synced to native: $deviceId")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "deviceId is required", null)
                    }
                }
                "startVpnBlockService" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, 100)
                        result.success(false) // VPN permission not granted
                    } else {
                        startService(Intent(this, VpnBlockService::class.java))
                        result.success(true)
                    }
                }
                "stopVpnBlockService" -> {
                    stopService(Intent(this, VpnBlockService::class.java))
                    result.success(true)
                }
                
                // ===== CAMERA RECORDING METHODS (Removed - only screen recording now) =====
                // Camera recording has been removed. All recording is via ScreenRecordService (MediaProjection).
                
                "cleanupOrphanRecordings" -> {
                    // No-op: camera recording removed
                    result.success(true)
                }
                
                // ===== AUTO-RECORDING METHODS =====
                
                "setAutoRecordingEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val trigger = call.argument<String>("trigger") ?: "unlock"
                    ScreenRecordService.setAutoRecordingEnabled(applicationContext, enabled, trigger)
                    result.success(true)
                }
                
                "isAutoRecordingEnabled" -> {
                    result.success(ScreenRecordService.isAutoRecordingEnabled(applicationContext))
                }
                
                "requestScreenRecordingPermission" -> {
                    // Request MediaProjection permission for actual screen recording
                    val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
                    result.success(true)
                }
                
                "hasScreenRecordingPermission" -> {
                    // Check if we have MediaProjection data stored
                    result.success(ScreenRecordService.resultData != null)
                }
                
                "setManualRecordingEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    ScreenRecordService.setRecordingEnabled(applicationContext, enabled, "parent")
                    result.success(true)
                }
                
                "isManualRecordingEnabled" -> {
                    result.success(ScreenRecordService.isRecordingEnabled(applicationContext))
                }
                
                // ===== LEGACY SCREEN RECORDING METHODS (Deprecated - kept for backwards compatibility) =====
                
                "initScreenRecordService" -> {
                    // Initialize screen recording service (MediaProjection-based)
                    val deviceId = call.argument<String>("deviceId")
                    val supabaseUrl = call.argument<String>("supabaseUrl")
                    val supabaseKey = call.argument<String>("supabaseKey")
                    if (deviceId != null && supabaseUrl != null && supabaseKey != null) {
                        ScreenRecordService.initialize(applicationContext, deviceId, supabaseUrl, supabaseKey)
                        Log.d(TAG, "✅ ScreenRecordService initialized")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "deviceId, supabaseUrl, and supabaseKey required", null)
                    }
                }
                
                "requestScreenRecordPermission" -> {
                    // Request MediaProjection permission for screen recording
                    val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
                    result.success(true)
                }
                
                "setScreenRecordingEnabled" -> {
                    // Enable/disable continuous screen recording on child device
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    Log.d(TAG, "🖥️ setScreenRecordingEnabled: $enabled")
                    
                    // Control actual ScreenRecordService
                    ScreenRecordService.setRecordingEnabled(applicationContext, enabled, "parent")
                    
                    // Also update in Supabase
                    CoroutineScope(Dispatchers.IO).launch {
                        updateRecordingSettingsInSupabase(enabled)
                    }
                    result.success(true)
                }
                
                "isScreenRecordingEnabled" -> {
                    // Check if actual screen recording is enabled
                    result.success(ScreenRecordService.isRecordingEnabled(applicationContext))
                }
                
                "isScreenRecordingActive" -> {
                    // Check if screen recording is currently in progress
                    val isActive = ScreenRecordService.resultData != null && 
                        (ScreenRecordService.isRecordingEnabled(applicationContext) || 
                         ScreenRecordService.isAutoRecordingEnabled(applicationContext))
                    result.success(mapOf(
                        "isRecording" to (ScreenRecordService.resultData != null),
                        "isEnabled" to ScreenRecordService.isRecordingEnabled(applicationContext),
                        "isAutoEnabled" to ScreenRecordService.isAutoRecordingEnabled(applicationContext),
                        "hasPermission" to (ScreenRecordService.resultData != null)
                    ))
                }
                
                "startScreenRecording" -> {
                    // Start actual screen recording (MediaProjection)
                    Log.d(TAG, "🖥️ startScreenRecording called")
                    if (ScreenRecordService.resultData == null) {
                        result.error("NO_PERMISSION", "Screen recording permission not granted. Need to grant MediaProjection permission first.", null)
                    } else {
                        ScreenRecordService.setRecordingEnabled(applicationContext, true, "parent")
                        result.success(true)
                    }
                }
                
                "stopScreenRecording" -> {
                    // Stop actual screen recording
                    Log.d(TAG, "🖥️ stopScreenRecording called")
                    ScreenRecordService.setRecordingEnabled(applicationContext, false, "parent")
                    result.success(true)
                }
                
                "syncScreenRecordSettings" -> {
                    // Sync screen recording settings from Supabase
                    CoroutineScope(Dispatchers.IO).launch {
                        ScreenRecordService.syncRecordingSettings(applicationContext)
                    }
                    result.success(true)
                }
                
                "retryPendingUploads" -> {
                    // Retry uploading local_only recordings after token refresh
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val service = ScreenRecordService.getInstance()
                            if (service != null) {
                                service.retryPendingUploads()
                            } else {
                                Log.d(TAG, "ScreenRecordService not running, skipping retry")
                            }
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "retryPendingUploads failed: ${e.message}")
                            runOnUiThread { result.success(false) }
                        }
                    }
                }
                
                "hasScreenRecordPermission" -> {
                    // Check if we have MediaProjection permission
                    result.success(ScreenRecordService.resultData != null)
                }
                
                // ===== GOOGLE DRIVE METHODS =====
                
                "requestGoogleDrivePermission" -> {
                    val signInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                        .requestEmail()
                        .requestScopes(Scope("https://www.googleapis.com/auth/drive.file"))
                        .build()
                    
                    val client = GoogleSignIn.getClient(this, signInOptions)
                    startActivityForResult(client.signInIntent, REQUEST_GOOGLE_SIGN_IN)
                    result.success(true)
                }
                
                "isGoogleDriveConnected" -> {
                    result.success(GoogleDriveUploader.isInitialized(applicationContext))
                }
                
                "getGoogleDriveAccount" -> {
                    result.success(GoogleDriveUploader.getSavedAccount(applicationContext))
                }
                
                "initGoogleDriveWithToken" -> {
                    // Initialize Google Drive with a token provided from Flutter (parent's token from Supabase)
                    val email = call.argument<String>("email") ?: ""
                    val token = call.argument<String>("token")
                    
                    if (!token.isNullOrEmpty()) {
                        Log.d(TAG, "☁️ Initializing Google Drive with parent's token for: $email")
                        GoogleDriveUploader.initialize(applicationContext, email, token)
                        Log.d(TAG, "✅ Google Drive initialized with parent's token")
                        result.success(true)
                    } else {
                        Log.e(TAG, "❌ initGoogleDriveWithToken: No token provided")
                        result.error("NO_TOKEN", "Token is required", null)
                    }
                }
                
                "refreshGoogleDriveToken" -> {
                    // Refresh the Google Drive token silently using GoogleSignIn (parent device only)
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val account = GoogleSignIn.getLastSignedInAccount(applicationContext)
                            if (account?.account != null) {
                                val email = account.email ?: ""
                                Log.d(TAG, "🔄 Refreshing Drive token for: $email")
                                
                                // Invalidate old token first
                                val oldToken = GoogleDriveUploader.loadSavedToken(applicationContext)
                                if (!oldToken.isNullOrEmpty()) {
                                    try {
                                        com.google.android.gms.auth.GoogleAuthUtil.clearToken(applicationContext, oldToken)
                                    } catch (e: Exception) {
                                        Log.w(TAG, "Could not clear old token: ${e.message}")
                                    }
                                }
                                
                                val scope = "oauth2:https://www.googleapis.com/auth/drive.file"
                                val freshToken = com.google.android.gms.auth.GoogleAuthUtil.getToken(
                                    applicationContext, account.account!!, scope
                                )
                                
                                if (!freshToken.isNullOrEmpty()) {
                                    GoogleDriveUploader.initialize(applicationContext, email, freshToken)
                                    Log.d(TAG, "✅ Drive token refreshed: ${freshToken.take(20)}...")
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "email" to email,
                                            "token" to freshToken
                                        ))
                                    }
                                } else {
                                    runOnUiThread {
                                        result.error("REFRESH_FAILED", "Token refresh returned empty", null)
                                    }
                                }
                            } else {
                                Log.d(TAG, "ℹ️ No signed-in Google account - not a parent device")
                                runOnUiThread {
                                    result.error("NO_ACCOUNT", "No Google account signed in", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Token refresh error: ${e.message}", e)
                            runOnUiThread {
                                result.error("REFRESH_ERROR", e.message, null)
                            }
                        }
                    }
                }
                
                "getScreenRecordings" -> {
                    // Get optional device_id parameter (for viewing child's recordings from parent app)
                    val deviceId = call.argument<String>("deviceId")
                    CoroutineScope(Dispatchers.IO).launch {
                        val recordings = getScreenRecordingsFromSupabase(deviceId)
                        runOnUiThread {
                            result.success(recordings)
                        }
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }

    private fun getForegroundAppUsingEvents(): String? {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val begin = now - 5000L
            val events = usm.queryEvents(begin, now)
            val event = UsageEvents.Event()
            var lastPkg: String? = null
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastPkg = event.packageName
                }
            }
            return lastPkg
        } catch (e: Exception) {
            return null
        }
    }

    private fun getForegroundAppPackage(): String? {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats: List<UsageStats> = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 60_000, now)
            if (stats.isNullOrEmpty()) return null
            return stats.maxByOrNull { it.lastTimeUsed }?.packageName
        } catch (e: Exception) {
            return null
        }
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun requestDeviceAdmin() {
        val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val componentName = ComponentName(this, DeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Enable device admin to prevent uninstallation")
        startActivity(intent)
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expectedService = ComponentName(packageName, AppBlockService::class.java.name).flattenToString()
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        
        if (enabledServices.isNullOrEmpty()) return false
        
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedService, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun isUsageAccessGranted(): Boolean {
        return try {
            val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOpsManager.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
            } else {
                appOpsManager.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun isDeviceAdminEnabled(): Boolean {
        val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val componentName = ComponentName(this, DeviceAdminReceiver::class.java)
        return devicePolicyManager.isAdminActive(componentName)
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return enabledListeners?.contains(packageName) == true
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun openBackgroundLocationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // No camera permission handling needed - screen recording uses MediaProjection via onActivityResult
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            REQUEST_MEDIA_PROJECTION -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    Log.d(TAG, "✅ MediaProjection permission granted")
                    ScreenRecordService.setMediaProjectionResult(resultCode, data)
                    methodChannel?.invokeMethod("onScreenRecordPermissionGranted", true)
                } else {
                    Log.d(TAG, "❌ MediaProjection permission denied")
                    methodChannel?.invokeMethod("onScreenRecordPermissionGranted", false)
                }
            }
            
            REQUEST_GOOGLE_SIGN_IN -> {
                val task = GoogleSignIn.getSignedInAccountFromIntent(data)
                try {
                    val account = task.getResult(Exception::class.java)
                    account?.let { acc ->
                        val email = acc.email ?: ""
                        Log.d(TAG, "✅ Google Sign-In successful: $email")
                        
                        // Get OAuth access token in background
                        acc.account?.let { googleAccount ->
                            CoroutineScope(Dispatchers.IO).launch {
                                try {
                                    // Get access token using GoogleAuthUtil
                                    val scope = "oauth2:https://www.googleapis.com/auth/drive.file"
                                    val token = com.google.android.gms.auth.GoogleAuthUtil.getToken(
                                        applicationContext,
                                        googleAccount,
                                        scope
                                    )
                                    
                                    Log.d(TAG, "✅ Got Drive access token: ${token.take(20)}...")
                                    GoogleDriveUploader.initialize(applicationContext, email, token)
                                    
                                    // Notify Flutter on main thread with both email and token
                                    runOnUiThread {
                                        // Send as a map with email and token
                                        val result = mapOf(
                                            "email" to email,
                                            "token" to token
                                        )
                                        methodChannel?.invokeMethod("onGoogleDriveConnected", result)
                                    }
                                } catch (e: com.google.android.gms.auth.UserRecoverableAuthException) {
                                    // Need user consent - launch the consent intent
                                    Log.d(TAG, "🔐 Need user consent for Drive access")
                                    runOnUiThread {
                                        startActivityForResult(e.intent, REQUEST_GOOGLE_SIGN_IN)
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Error getting token: ${e.message}", e)
                                    runOnUiThread {
                                        methodChannel?.invokeMethod("onGoogleDriveConnected", null)
                                    }
                                }
                            }
                        } ?: run {
                            // No account object, just save email
                            Log.w(TAG, "⚠️ No Google account object, saving email only")
                            GoogleDriveUploader.initialize(applicationContext, email, "")
                            methodChannel?.invokeMethod("onGoogleDriveConnected", mapOf("email" to email, "token" to ""))
                        }
                    } ?: run {
                        Log.e(TAG, "❌ Google Sign-In returned null account")
                        methodChannel?.invokeMethod("onGoogleDriveConnected", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Google Sign-In failed: ${e.message}", e)
                    methodChannel?.invokeMethod("onGoogleDriveConnected", null)
                }
            }
            
            100 -> { // VPN permission result
                if (resultCode == Activity.RESULT_OK) {
                    startService(Intent(this, VpnBlockService::class.java))
                }
            }
        }
    }
    
    /**
     * Update recording settings in Supabase
     */
    private suspend fun updateRecordingSettingsInSupabase(enabled: Boolean) {
        try {
            val prefs = getSharedPreferences("screen_record_prefs", Context.MODE_PRIVATE)
            var deviceId = prefs.getString("device_id", null)
            var supabaseUrl = prefs.getString("supabase_url", null)
            var supabaseKey = prefs.getString("supabase_key", null)
            
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
                Log.e(TAG, "❌ Missing device ID")
                return
            }
            
            // Upsert setting
            val jsonPayload = org.json.JSONObject().apply {
                put("device_id", deviceId)
                put("recording_enabled", enabled)
                put("updated_at", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                }.format(java.util.Date()))
            }
            
            val endpoint = "$supabaseUrl/rest/v1/screen_recording_settings"
            val url = java.net.URL(endpoint)
            val connection = url.openConnection() as java.net.HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "resolution=merge-duplicates")
            connection.doOutput = true
            
            connection.outputStream.use { os ->
                os.write(jsonPayload.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 Update recording settings response: $responseCode")
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to update settings: ${e.message}")
        }
    }
    
    /**
     * Get screen recordings from Supabase
     */
    /**
     * Get screen recordings from Supabase
     * @param targetDeviceId Optional device ID to query. If null, uses the current device's ID
     */
    private suspend fun getScreenRecordingsFromSupabase(targetDeviceId: String? = null): List<Map<String, Any?>> {
        try {
            var deviceId = targetDeviceId
            var supabaseUrl: String? = null
            var supabaseKey: String? = null
            
            // If no device ID provided, try to get from prefs
            if (deviceId.isNullOrEmpty()) {
                val prefs = getSharedPreferences("screen_record_prefs", Context.MODE_PRIVATE)
                deviceId = prefs.getString("device_id", null)
                supabaseUrl = prefs.getString("supabase_url", null)
                supabaseKey = prefs.getString("supabase_key", null)
                
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
            }
            
            // Use hardcoded fallback if needed
            if (supabaseUrl.isNullOrEmpty()) {
                supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
            }
            if (supabaseKey.isNullOrEmpty()) {
                supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
            }
            
            if (deviceId.isNullOrEmpty()) {
                Log.w(TAG, "⚠️ No device ID available for fetching recordings")
                return emptyList()
            }
            
            Log.d(TAG, "📱 Fetching recordings for device: $deviceId")
            
            val endpoint = "$supabaseUrl/rest/v1/screen_recordings?device_id=eq.$deviceId&order=recorded_at.desc&limit=50"
            val url = java.net.URL(endpoint)
            val connection = url.openConnection() as java.net.HttpURLConnection
            
            connection.requestMethod = "GET"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            
            val responseCode = connection.responseCode
            if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val jsonArray = org.json.JSONArray(response)
                
                val recordings = mutableListOf<Map<String, Any?>>()
                for (i in 0 until jsonArray.length()) {
                    val item = jsonArray.getJSONObject(i)
                    recordings.add(mapOf(
                        "id" to item.optString("id"),
                        "file_name" to item.optString("file_name"),
                        "drive_file_id" to item.optString("drive_file_id"),
                        "drive_link" to item.optString("drive_link"),
                        "file_size" to item.optLong("file_size"),
                        "duration_seconds" to item.optInt("duration_seconds"),
                        "recorded_at" to item.optString("recorded_at"),
                        "status" to item.optString("status")
                    ))
                }
                
                connection.disconnect()
                return recordings
            }
            
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to get recordings: ${e.message}")
        }
        
        return emptyList()
    }
}
