package com.getsurakshaapp

import android.app.Application
import android.util.Log
import androidx.work.Configuration
import androidx.work.WorkManager

class MainApplication : Application() {
    
    companion object {
        private const val TAG = "MainApplication"
    }
    
    override fun onCreate() {
        super.onCreate()
        com.getsurakshaapp.AppContextHolder.app = this
        
        // Initialize WorkManager with custom configuration
        initializeWorkManager()
        
        // Check if location tracking should be running and restart if needed
        try {
            LocationService.restartIfNeeded(this)
            Log.d(TAG, "Location service restart check completed")
            
            // Also ensure WorkManager is scheduled if tracking was active
            val prefs = getSharedPreferences("location_service_prefs", MODE_PRIVATE)
            val isTracking = prefs.getBoolean("is_tracking", false)
            if (isTracking) {
                LocationWorker.schedulePeriodicWork(this)
                Log.d(TAG, "WorkManager location worker re-scheduled")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check/restart location service: ${e.message}")
        }
    }
    
    private fun initializeWorkManager() {
        try {
            val config = Configuration.Builder()
                .setMinimumLoggingLevel(Log.INFO)
                .build()
            WorkManager.initialize(this, config)
            Log.d(TAG, "WorkManager initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "WorkManager already initialized or error: ${e.message}")
        }
    }
}
