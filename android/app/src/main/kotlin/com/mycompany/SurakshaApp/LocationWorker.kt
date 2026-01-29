package com.mycompany.SurakshaApp

import android.content.Context
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.work.*
import com.google.android.gms.location.*
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.math.*

/**
 * WorkManager Worker for periodic background location updates
 * This provides an additional layer of reliability beyond the foreground service
 * WorkManager ensures location updates even if:
 * - App is killed from task manager
 * - Device is restarted
 * - System kills the foreground service
 */
class LocationWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "LocationWorker"
        private const val WORK_NAME = "location_tracking_worker"
        private const val PREFS_NAME = "location_service_prefs"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_IS_TRACKING = "is_tracking"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_KEY = "supabase_key"
        private const val KEY_LAST_LAT = "last_lat"
        private const val KEY_LAST_LNG = "last_lng"
        private const val KEY_LAST_SAVE_TIME = "last_save_time"
        
        // Minimum interval between saves (60 seconds)
        private const val MIN_SAVE_INTERVAL_MS = 60_000L
        // Minimum distance change to save (100 meters)
        private const val MIN_DISTANCE_CHANGE = 100.0
        
        /**
         * Schedule periodic location updates using WorkManager
         * Runs every 15 minutes (minimum allowed by WorkManager)
         */
        fun schedulePeriodicWork(context: Context) {
            Log.d(TAG, "Scheduling periodic location work")
            
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(false) // Allow even on low battery
                .setRequiresCharging(false)
                .setRequiresDeviceIdle(false)
                .build()
            
            val workRequest = PeriodicWorkRequestBuilder<LocationWorker>(
                15, TimeUnit.MINUTES, // Repeat interval
                5, TimeUnit.MINUTES   // Flex interval
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.LINEAR,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(WORK_NAME)
                .setInitialDelay(0, TimeUnit.SECONDS) // Start immediately
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE, // Update to ensure latest config
                workRequest
            )
            
            Log.d(TAG, "Periodic location work scheduled successfully")
        }
        
        /**
         * Cancel periodic location updates
         */
        fun cancelPeriodicWork(context: Context) {
            Log.d(TAG, "Cancelling periodic location work")
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
        
        /**
         * Check if periodic work is scheduled
         * Note: This is a suspending function that should be called from a coroutine
         */
        suspend fun isWorkScheduled(context: Context): Boolean {
            return try {
                val workInfos = WorkManager.getInstance(context)
                    .getWorkInfosForUniqueWork(WORK_NAME)
                    .await()
                workInfos.any { !it.state.isFinished }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking work status: ${e.message}")
                false
            }
        }
    }
    
    private val prefs: SharedPreferences = 
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override suspend fun doWork(): Result {
        Log.d(TAG, "LocationWorker started")
        
        return try {
            // Check if tracking is enabled
            val isTracking = prefs.getBoolean(KEY_IS_TRACKING, false)
            if (!isTracking) {
                Log.d(TAG, "Tracking is disabled, skipping location update")
                return Result.success()
            }
            
            // Get device ID (with fallback to Flutter SharedPreferences)
            val deviceId = getDeviceIdWithFallback()
            if (deviceId == null) {
                Log.w(TAG, "No device ID found, skipping location update")
                return Result.failure()
            }
            
            Log.d(TAG, "📱 Using device ID: $deviceId")

            // Ensure the foreground service is running
            ensureForegroundServiceRunning(deviceId)
            
            // Get current location
            val location = getCurrentLocation()
            if (location == null) {
                Log.w(TAG, "Failed to get current location")
                return Result.retry()
            }
            
            Log.d(TAG, "Location obtained: ${location.latitude}, ${location.longitude}")
            
            // Check if should save (deduplication)
            if (!shouldSaveLocation(location)) {
                Log.d(TAG, "Skipping location save due to deduplication")
                return Result.success()
            }
            
            // Save location to Supabase
            val saved = saveLocationToSupabase(location, deviceId)
            
            if (saved) {
                Log.d(TAG, "Location saved successfully")
                Result.success()
            } else {
                Log.w(TAG, "Failed to save location, will retry")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in LocationWorker: ${e.message}", e)
            Result.retry()
        }
    }
    
    /**
     * Get device ID from native prefs, with fallback to Flutter SharedPreferences
     */
    private fun getDeviceIdWithFallback(): String? {
        // First try native SharedPreferences
        var deviceId = prefs.getString(KEY_DEVICE_ID, null)
        if (deviceId != null && deviceId.isNotEmpty()) {
            Log.d(TAG, "✅ Device ID from native prefs: $deviceId")
            return deviceId
        }

        // Fallback: Try Flutter SharedPreferences
        try {
            val flutterPrefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )

            // Flutter stores with "flutter." prefix
            deviceId = flutterPrefs.getString("flutter.child_device_id", null)
            if (deviceId != null && deviceId.isNotEmpty()) {
                Log.d(TAG, "✅ Device ID from Flutter prefs: $deviceId")

                // Sync to native prefs for future use
                prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
                Log.d(TAG, "✅ Synced device ID to native prefs")

                return deviceId
            }

            // Also try backup key
            deviceId = flutterPrefs.getString("flutter.device_id_backup", null)
            if (deviceId != null && deviceId.isNotEmpty()) {
                Log.d(TAG, "✅ Device ID from Flutter backup prefs: $deviceId")

                // Sync to native prefs for future use
                prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()

                return deviceId
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading Flutter SharedPreferences: ${e.message}")
        }

        Log.w(TAG, "❌ No device ID found in any SharedPreferences")
        return null
    }

    /**
     * Ensure the foreground service is running
     * This is important because WorkManager complements the foreground service
     */
    private fun ensureForegroundServiceRunning(deviceId: String) {
        try {
            if (!LocationService.isRunning(applicationContext)) {
                Log.d(TAG, "Foreground service not running, starting it")
                val supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
                val supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)
                
                if (supabaseUrl != null && supabaseKey != null) {
                    LocationService.start(applicationContext, deviceId, supabaseUrl, supabaseKey)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service: ${e.message}")
        }
    }
    
    /**
     * Get current location using FusedLocationProviderClient
     */
    private suspend fun getCurrentLocation(): Location? {
        return try {
            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(applicationContext)
            
            // First try to get last known location (faster)
            val lastLocation = fusedLocationClient.lastLocation.await()
            if (lastLocation != null && isLocationRecent(lastLocation)) {
                return lastLocation
            }
            
            // If no recent location, request a fresh one with timeout
            val locationRequest = LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                10000 // 10 seconds timeout
            ).apply {
                setMaxUpdates(1)
            }.build()
            
            // Note: For a WorkManager worker, we can't easily do a blocking location request
            // So we'll use the last location or fail gracefully
            lastLocation
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error getting location: ${e.message}")
            null
        }
    }
    
    /**
     * Check if location is recent (within 5 minutes)
     */
    private fun isLocationRecent(location: Location): Boolean {
        val locationAge = System.currentTimeMillis() - location.time
        return locationAge < 5 * 60 * 1000 // 5 minutes
    }
    
    /**
     * Check if location should be saved (deduplication logic)
     */
    private fun shouldSaveLocation(location: Location): Boolean {
        val now = System.currentTimeMillis()
        val lastSaveTime = prefs.getLong(KEY_LAST_SAVE_TIME, 0L)
        val lastLat = prefs.getFloat(KEY_LAST_LAT, 0f).toDouble()
        val lastLng = prefs.getFloat(KEY_LAST_LNG, 0f).toDouble()
        
        if (lastSaveTime == 0L) {
            return true // First save
        }
        
        val timeSinceLastSave = now - lastSaveTime
        
        // Skip if less than minimum interval
        if (timeSinceLastSave < MIN_SAVE_INTERVAL_MS) {
            Log.d(TAG, "Skipping: only ${timeSinceLastSave}ms since last save")
            return false
        }
        
        // Check distance change
        if (lastLat != 0.0 && lastLng != 0.0) {
            val distance = calculateDistance(lastLat, lastLng, location.latitude, location.longitude)
            if (distance < MIN_DISTANCE_CHANGE) {
                Log.d(TAG, "Skipping: location changed only ${distance}m")
                return false
            }
        }
        
        return true
    }
    
    /**
     * Save location to Supabase
     */
    private suspend fun saveLocationToSupabase(location: Location, deviceId: String): Boolean {
        return try {
            val supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null) ?: return false
            val supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null) ?: return false
            
            val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date())
            
            // Get address
            val address = getAddressFromCoordinates(location.latitude, location.longitude)
            print("locationAddres:-$address")
            val jsonData = JSONObject().apply {
                put("device_id", deviceId)
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("address", address)
                put("recorded_at", isoDate)
            }
            
            val url = URL("$supabaseUrl/rest/v1/locations")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Prefer", "return=representation")
            connection.doOutput = true
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            
            connection.outputStream.use { os ->
                os.write(jsonData.toString().toByteArray())
            }
            
            val responseCode = connection.responseCode
            if (responseCode in 200..299) {
                Log.d(TAG, "Location saved: ${location.latitude}, ${location.longitude}")
                
                // Update last save tracking
                prefs.edit().apply {
                    putLong(KEY_LAST_SAVE_TIME, System.currentTimeMillis())
                    putFloat(KEY_LAST_LAT, location.latitude.toFloat())
                    putFloat(KEY_LAST_LNG, location.longitude.toFloat())
                    apply()
                }
                
                connection.disconnect()
                true
            } else {
                val error = connection.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
                Log.e(TAG, "Failed to save location. Response: $responseCode, Error: $error")
                connection.disconnect()
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving location: ${e.message}", e)
            false
        }
    }
    
    /**
     * Get address from coordinates using reverse geocoding
     */
    private fun getAddressFromCoordinates(lat: Double, lng: Double): String {
        return try {
            val url = URL("https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1")
            val connection = url.openConnection() as HttpURLConnection
            connection.setRequestProperty("User-Agent", "SurakshaApp/1.0")
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val response = connection.inputStream.bufferedReader().readText()
            val json = JSONObject(response)
            
            connection.disconnect()
            
            json.optString("display_name", "Lat: $lat, Lng: $lng")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get address: ${e.message}")
            "Lat: ${String.format("%.6f", lat)}, Lng: ${String.format("%.6f", lng)}"
        }
    }
    
    /**
     * Calculate distance between two coordinates in meters
     */
    private fun calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val earthRadius = 6371000.0 // meters
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLng / 2) * sin(dLng / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}