package com.mycompany.SurakshaApp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver to restart the LocationService when it gets killed
 */
class RestartReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "RestartReceiver"
        const val ACTION_RESTART_SERVICE = "com.mycompany.SurakshaApp.RESTART_LOCATION_SERVICE"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "RestartReceiver triggered with action: ${intent.action}")
        
        when (intent.action) {
            ACTION_RESTART_SERVICE,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.PACKAGE_REPLACED" -> {
                Log.d(TAG, "Attempting to restart LocationService")
                restartLocationService(context)
            }
        }
    }
    
    private fun restartLocationService(context: Context) {
        try {
            // Check if tracking should be active
            val prefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
            val shouldTrack = prefs.getBoolean("is_tracking", false)
            
            if (shouldTrack) {
                Log.d(TAG, "Tracking is enabled, starting LocationService")
                val serviceIntent = Intent(context, LocationService::class.java)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d(TAG, "LocationService start command sent")
            } else {
                Log.d(TAG, "Tracking is not enabled, not starting service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart LocationService: ${e.message}")
        }
    }
}
