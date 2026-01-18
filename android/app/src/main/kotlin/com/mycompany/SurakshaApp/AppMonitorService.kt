package com.mycompany.SurakshaApp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AppMonitoringService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val pollInterval = 1000L
    private val channelId = "app_monitor_channel"

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                val pkg = getForegroundPackage()
                if (pkg != null) {
                    val prefs = getSharedPreferences("applock_prefs", Context.MODE_PRIVATE)
                    val locked = prefs.getBoolean("lock_$pkg", false)
                    val until = prefs.getLong("unlocked_until_$pkg", 0L)
                    if (locked && System.currentTimeMillis() >= until) {
                        val intent = Intent(this@AppMonitoringService, LockActivity::class.java).apply {
                            putExtra("target_package", pkg)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                }
            } catch (e: Exception) {
                Log.e("AppMonitoringService", "poll error: ${e.message}")
            } finally {
                handler.postDelayed(this, pollInterval)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(2, foregroundNotification())
        handler.post(pollRunnable)
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 5000, now)
        if (stats.isNullOrEmpty()) return null
        return stats.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(NotificationChannel(channelId, "App Monitor", NotificationManager.IMPORTANCE_LOW))
        }
    }

    private fun foregroundNotification(): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("App lock monitor")
            .setContentText("Monitoring locked apps")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }

    companion object {
        fun start(ctx: Context) {
            val intent = Intent(ctx, AppMonitoringService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(intent) else ctx.startService(intent)
        }

        fun stop(ctx: Context) {
            val intent = Intent(ctx, AppMonitoringService::class.java)
            ctx.stopService(intent)
        }
    }
}
