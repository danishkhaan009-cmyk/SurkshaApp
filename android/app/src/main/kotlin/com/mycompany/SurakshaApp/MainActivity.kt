package com.mycompany.SurakshaApp

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

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "parental_control/permissions"
    private var methodChannel: MethodChannel? = null

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
}
