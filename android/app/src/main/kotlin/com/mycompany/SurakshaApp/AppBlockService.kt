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
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.*

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
        
        // Browser packages to monitor for URL blocking
        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.opera.mini.native",
            "com.brave.browser",
            "com.UCMobile.intl",
            "com.sec.android.app.sbrowser",
            "org.chromium.chrome",
            "com.duckduckgo.mobile.android"
        )

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
    private var lastCheckedUrl: String? = null
    private val urlSyncJob = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onServiceConnected() {
        super.onServiceConnected()
        loadPersistedState()
        createNotificationChannel()
        
        // Start periodic URL sync
        startUrlSync()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or 
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        serviceInfo = info
        Log.d(TAG, "✅ Security Engine Connected with URL Blocking")
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

        val packageName = event?.packageName?.toString() ?: return
        
        // Skip self
        if (packageName == OUR_PACKAGE_NAME || packageName.contains("SurakshaApp")) return

        // Check if it's a browser
        val isBrowser = BROWSER_PACKAGES.contains(packageName)
        
        // ALWAYS monitor browser URLs for history tracking (regardless of child mode)
        if (isBrowser && (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || 
                         event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)) {
            Log.d(TAG, "🌐 Browser activity detected: $packageName (ChildMode: $isChildModeActive)")
            checkBrowserUrl(event)
        }
        
        // App blocking only works in child mode
        if (!isChildModeActive) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // Check app blocking
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
    
    /**
     * Check browser URL for blocked content
     */
    private fun checkBrowserUrl(event: AccessibilityEvent?) {
        try {
            val source = event?.source ?: rootInActiveWindow ?: return
            val url = extractUrlFromNode(source)
            source.recycle()
            
            if (!url.isNullOrEmpty() && url != lastCheckedUrl) {
                lastCheckedUrl = url
                Log.d(TAG, "🌐 Checking URL: $url")
                Log.d(TAG, "🌐 Blocked URLs count: ${UrlBlockService.getBlockedUrls().size}")
                Log.d(TAG, "🌐 Blocked URLs: ${UrlBlockService.getBlockedUrls()}")

                if (UrlBlockService.isUrlBlocked(url)) {
                    Log.d(TAG, "🚫 BLOCKED URL DETECTED: $url")
                  /*  AlertDialog.Builder(this)
                        .setTitle("Access Blocked")
                        .setMessage("This website is blocked by your parent")
                        .setCancelable(false)
                        .setPositiveButton("OK") { dialog, _ ->
                            dialog.dismiss()
                        }
                        .show()*/
                    blockUrl(url, event?.packageName?.toString() ?: "")
                    // Record blocked URL attempt in browsing history
                    Log.d(TAG, "📝 Recording BLOCKED URL to history: $url")
                    UrlBlockService.recordBrowsingHistory(applicationContext, url, "[BLOCKED] $url")
                } else {
                    Log.d(TAG, "✅ URL allowed: $url")
                    // Record allowed URL visit in browsing history
                    Log.d(TAG, "📝 Recording ALLOWED URL to history: $url")
                    UrlBlockService.recordBrowsingHistory(applicationContext, url)
                }

                // Reset after 3 seconds
                handler.postDelayed({ lastCheckedUrl = null }, 3000)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking browser URL: ${e.message}")
        }
    }
    
    /**
     * Extract URL from accessibility node
     */
    private fun extractUrlFromNode(node: AccessibilityNodeInfo?): String? {
        if (node == null) return null
        
        try {
            // Look for EditText or specific class names used by browsers for URL bar
            val className = node.className?.toString() ?: ""
            
            // Chrome uses "android.widget.EditText" for URL bar
            if (className.contains("EditText") || className.contains("UrlBar")) {
                val text = node.text?.toString() ?: ""
                if (text.isNotEmpty() && !text.contains(" ")) { // URLs don't have spaces
                    return text
                }
            }
            
            // Also check contentDescription and hintText
            val desc = node.contentDescription?.toString()
            if (!desc.isNullOrEmpty() && isLikelyUrl(desc)) {
                return desc
            }
            
            // Recursively search children
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                val url = extractUrlFromNode(child)
                child?.recycle()
                if (!url.isNullOrEmpty()) {
                    return url
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting URL: ${e.message}")
        }
        
        return null
    }
    
    private fun isLikelyUrl(text: String): Boolean {
        val trimmed = text.trim()
        
        // Must have reasonable length
        if (trimmed.length < 3 || trimmed.length > 2048) return false
        
        // Has protocol
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return true
        
        // Has scheme separator
        if (trimmed.contains("://")) return true
        
        // Domain pattern (must have dot and no spaces)
        if (!trimmed.contains(" ") && trimmed.matches(Regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}(/.*)?$"))) {
            return true
        }
        
        // IP address pattern
        if (trimmed.matches(Regex("^\\d{1,3}(\\.\\d{1,3}){3}(:\\d+)?(/.*)?$"))) {
            return true
        }
        
        return false
    }
    
    /**
     * Block access to a URL
     */
    private fun blockUrl(url: String, packageName: String) {
        try {
            Log.d(TAG, "🛑 Blocking URL: $url")

            // Close the browser or navigate back
            performGlobalAction(GLOBAL_ACTION_BACK)

            // Show a toast notification
            handler.post {


                Toast.makeText(this, "🚫 This website is blocked by your parent", Toast.LENGTH_LONG).show()
            }
            
            // Optionally block the entire browser if needed
            // blockApp(packageName)
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking URL: ${e.message}")
        }
    }
    
    /**
     * Start periodic URL sync
     */
    private fun startUrlSync() {
        urlSyncJob.launch {
            while (isActive) {
                try {
                    UrlBlockService.syncBlockedUrls(applicationContext)
                } catch (e: Exception) {
                    Log.e(TAG, "URL sync error: ${e.message}")
                }
                delay(10 * 1000L) // Sync every 5 minutes
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        urlSyncJob.cancel()
        Log.d(TAG, "🛑 Service destroyed")
    }
}
