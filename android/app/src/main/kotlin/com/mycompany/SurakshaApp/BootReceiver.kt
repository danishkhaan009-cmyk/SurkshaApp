package com.mycompany.SurakshaApp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "BootReceiver triggered with action: $action")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Device boot completed, checking for services to restart")
                
                // Restart location tracking service if it was active
                try {
                    LocationService.restartIfNeeded(context)
                    Log.d(TAG, "Location service restart check completed")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restart location service: ${e.message}")
                }
                
                // Restart monitoring services if needed
                try {
                    MonitoringService.start(context)
                    Log.d(TAG, "Monitoring service started")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start monitoring service: ${e.message}")
                }
            }
        }
    }
}
