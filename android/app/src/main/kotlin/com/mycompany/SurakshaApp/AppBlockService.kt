package com.mycompany.SurakshaApp

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

class AppBlockService : AccessibilityService() {
    companion object {
        private const val TAG = "AppBlockService"
        private const val NOTIFICATION_CHANNEL_ID = "app_block_channel"
        private const val NOTIFICATION_ID = 1001
        private const val OUR_PACKAGE_NAME = "com.mycompany.SurakshaApp"
        private const val PREFS = "applock_prefs"
        
        private val lockedApps = mutableSetOf<String>()
        private var isChildModeActive = false
        private var isInitialized = false

        fun setLockedApps(apps: Set<String>) {
            lockedApps.clear()
            val filteredApps = apps.filter { it != OUR_PACKAGE_NAME }
            lockedApps.addAll(filteredApps)

            Log.d(TAG, "📝 Syncing locked apps: ${lockedApps.size} items")

            val ctx = AppContextHolder.app
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            
            // Clear current lock flags but keep pins
            val allKeys = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).all.keys
            for (key in allKeys) {
                if (key.startsWith("lock_") && !key.startsWith("lock_pin_")) {
                    prefs.remove(key)
                }
            }
            
            // Save new flags
            for (pkg in filteredApps) {
                prefs.putBoolean("lock_$pkg", true)
            }
            prefs.apply()
        }

        fun setAppLockPin(pin: String, packageName: String? = null) {
            val ctx = AppContextHolder.app
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            if (!packageName.isNullOrEmpty()) {
                prefs.putString("lock_pin_$packageName", pin)
            } else {
                prefs.putString("applock_pin", pin)
            }
            prefs.apply()
        }

        fun getLockedApps(): Set<String> {
            if (lockedApps.isNotEmpty()) return lockedApps.toSet()
            val ctx = AppContextHolder.app
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.all.keys
                .filter { it.startsWith("lock_") && !it.startsWith("lock_pin_") }
                .map { it.removePrefix("lock_") }
                .toSet()
        }

        fun setChildMode(active: Boolean) {
            isChildModeActive = active
            isInitialized = true
            Log.d(TAG, "🔒 Blocking Engine State: $isChildModeActive")
            val ctx = AppContextHolder.app
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("child_mode", active).apply()
        }
    }

    private var lastCheckedPackage: String? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        loadPersistedState()
        createNotificationChannel()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
        serviceInfo = info
        Log.d(TAG, "✅ Security Engine Connected")
    }

    private fun loadPersistedState() {
        try {
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            isChildModeActive = prefs.getBoolean("child_mode", false)
            
            val savedApps = prefs.all.keys
                .filter { it.startsWith("lock_") && !it.startsWith("lock_pin_") && prefs.getBoolean(it, false) }
                .map { it.removePrefix("lock_") }
                .toSet()
            
            lockedApps.clear()
            lockedApps.addAll(savedApps)
            isInitialized = true
            Log.d(TAG, "📂 Loaded State: Mode=$isChildModeActive, LockedApps=${lockedApps.size}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Persistence Load Error: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isInitialized) loadPersistedState()
        if (!isChildModeActive) return

        val packageName = event?.packageName?.toString() ?: return
        
        // Skip self
        if (packageName == OUR_PACKAGE_NAME || packageName.contains("SurakshaApp")) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (lockedApps.contains(packageName)) {
                if (isTemporarilyUnlocked(packageName)) return
                
                Log.d(TAG, "🚫 Blocked launch detected: $packageName")
                blockApp(packageName)
            }
        }
    }

    private fun blockApp(packageName: String) {
        if (packageName == lastCheckedPackage) return
        lastCheckedPackage = packageName
        
        try {
            val appName = getAppName(packageName)
            
            // Show overlay immediately
            val intent = Intent(this, LockActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NO_ANIMATION
                putExtra("target_package", packageName)
            }
            startActivity(intent)
            
            // Auto-reset check after 2 seconds
            handler.postDelayed({ lastCheckedPackage = null }, 2000)
        } catch (e: Exception) {
            Log.e(TAG, "Block Error: ${e.message}")
        }
    }

    private fun isTemporarilyUnlocked(pkg: String): Boolean {
        val until = getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("unlocked_until_$pkg", 0L)
        return System.currentTimeMillis() < until
    }

    override fun onInterrupt() {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, "App Security", NotificationManager.IMPORTANCE_HIGH)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = applicationContext.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName.split(".").lastOrNull() ?: packageName
        }
    }
}
