package com.getsurakshaapp

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors
import kotlin.math.*

class LocationService : Service() {

    companion object {
        private const val TAG = "LocationService"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "location_tracking_channel"
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
        // Location update interval (10 minutes)
        private const val LOCATION_INTERVAL_MS = 10 * 60 * 1000L
        // Fastest location update interval (5 minutes)
        private const val FASTEST_INTERVAL_MS = 5 * 60 * 1000L

        fun start(context: Context, deviceId: String, supabaseUrl: String, supabaseKey: String) {
            Log.d(TAG, "Starting LocationService for device: $deviceId")
            
            // Save configuration to SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString(KEY_DEVICE_ID, deviceId)
                putString(KEY_SUPABASE_URL, supabaseUrl)
                putString(KEY_SUPABASE_KEY, supabaseKey)
                putBoolean(KEY_IS_TRACKING, true)
                apply()
            }

            val intent = Intent(context, LocationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            Log.d(TAG, "Stopping LocationService")
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean(KEY_IS_TRACKING, false)
                remove(KEY_DEVICE_ID)
                apply()
            }

            val intent = Intent(context, LocationService::class.java)
            context.stopService(intent)
        }

        fun isRunning(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_IS_TRACKING, false)
        }

        fun getDeviceId(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            var deviceId = prefs.getString(KEY_DEVICE_ID, null)

            // If not in native prefs, try Flutter SharedPreferences
            if (deviceId == null || deviceId.isEmpty()) {
                try {
                    val flutterPrefs = context.getSharedPreferences(
                        "FlutterSharedPreferences",
                        Context.MODE_PRIVATE
                    )
                    deviceId = flutterPrefs.getString("flutter.child_device_id", null)

                    if (deviceId != null && deviceId.isNotEmpty()) {
                        Log.d(TAG, "✅ Device ID from Flutter prefs: $deviceId")
                        // Sync to native prefs
                        prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
                    } else {
                        // Try backup key
                        deviceId = flutterPrefs.getString("flutter.device_id_backup", null)
                        if (deviceId != null && deviceId.isNotEmpty()) {
                            Log.d(TAG, "✅ Device ID from Flutter backup prefs: $deviceId")
                            prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error reading Flutter SharedPreferences: ${e.message}")
                }
            }

            return deviceId
        }

        fun restartIfNeeded(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val wasTracking = prefs.getBoolean(KEY_IS_TRACKING, false)
            val deviceId = getDeviceId(context) // Use the fallback method
            val supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
            val supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)

            if (wasTracking && deviceId != null && supabaseUrl != null && supabaseKey != null) {
                Log.d(TAG, "Restarting location service for device: $deviceId")
                start(context, deviceId, supabaseUrl, supabaseKey)
            } else {
                Log.w(TAG, "Cannot restart - wasTracking: $wasTracking, deviceId: $deviceId")
            }
        }
    }

    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var prefs: SharedPreferences? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LocationService onCreate")
        
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()

        // IMPORTANT: Call startForeground() immediately to avoid RemoteServiceException
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        acquireWakeLock()
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "Location received: ${location.latitude}, ${location.longitude}")
                    saveLocation(location, false)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "LocationService onStartCommand")
        
        // startForeground is already called in onCreate
        // Just update the notification if needed
        val notification = createNotification()
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)

        startLocationUpdates()
        
        // Return START_STICKY to restart service if killed
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "LocationService onDestroy - checking if should restart")
        
        // If tracking should still be active, restart the service immediately
        val shouldTrack = prefs?.getBoolean(KEY_IS_TRACKING, false) ?: false
        if (shouldTrack) {
            Log.d(TAG, "Service destroyed but tracking should continue, scheduling immediate restart")
            scheduleRestart()
            sendRestartBroadcast()
        } else {
            stopLocationUpdates()
            releaseWakeLock()
        }
        
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "LocationService onTaskRemoved - app killed from task manager")
        
        // If tracking should still be active, restart the service
        val shouldTrack = prefs?.getBoolean(KEY_IS_TRACKING, false) ?: false
        if (shouldTrack) {
            Log.d(TAG, "Task removed but tracking should continue, scheduling immediate restart")
            // Schedule restart before calling super
            scheduleRestart()
            sendRestartBroadcast()
            
            // Also try to restart immediately using startService
            try {
                val restartIntent = Intent(applicationContext, LocationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(restartIntent)
                } else {
                    applicationContext.startService(restartIntent)
                }
                Log.d(TAG, "Service restart triggered immediately")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart service immediately: ${e.message}")
            }
        }
        
        super.onTaskRemoved(rootIntent)
    }

    private fun scheduleRestart() {
        Log.d(TAG, "Scheduling service restart...")
        
        // Method 1: Use AlarmManager for guaranteed restart
        val restartIntent = Intent(applicationContext, LocationService::class.java)
        restartIntent.action = "RESTART_SERVICE"
        
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Schedule restart in 1 second
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 1000,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 1000,
                pendingIntent
            )
        }
        
        // Method 2: Also schedule a backup restart in 5 seconds
        val backupIntent = Intent(applicationContext, LocationService::class.java)
        backupIntent.action = "RESTART_SERVICE_BACKUP"
        
        val backupPendingIntent = PendingIntent.getService(
            applicationContext,
            2,
            backupIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 5000,
                backupPendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 5000,
                backupPendingIntent
            )
        }
        
        Log.d(TAG, "Service restart scheduled for 1s and 5s")
    }

    private fun sendRestartBroadcast() {
        try {
            val broadcastIntent = Intent(RestartReceiver.ACTION_RESTART_SERVICE)
            broadcastIntent.setPackage(packageName)
            sendBroadcast(broadcastIntent)
            Log.d(TAG, "Restart broadcast sent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send restart broadcast: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when location tracking is active"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Tracking Active")
            .setContentText("SurakshaApp is tracking your location")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SurakshaApp:LocationServiceWakeLock"
        ).apply {
            acquire()
        }
        Log.d(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "WakeLock released")
            }
        }
        wakeLock = null
    }

    private fun startLocationUpdates() {
        try {
            val locationRequest = LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                LOCATION_INTERVAL_MS
            ).apply {
                setMinUpdateIntervalMillis(FASTEST_INTERVAL_MS)
                setMinUpdateDistanceMeters(MIN_DISTANCE_CHANGE.toFloat())
                setWaitForAccurateLocation(false)
            }.build()

            locationCallback?.let { callback ->
                fusedLocationClient?.requestLocationUpdates(
                    locationRequest,
                    callback,
                    Looper.getMainLooper()
                )
                Log.d(TAG, "Location updates started")
            }

            // Get initial location
            fusedLocationClient?.lastLocation?.addOnSuccessListener { location ->
                location?.let {
                    Log.d(TAG, "Initial location: ${it.latitude}, ${it.longitude}")
                    saveLocation(it, true)
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start location updates: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
            Log.d(TAG, "Location updates stopped")
        }
    }

    private fun saveLocation(location: Location, forceUpdate: Boolean) {
        val deviceId = prefs?.getString(KEY_DEVICE_ID, null)
        val supabaseUrl = prefs?.getString(KEY_SUPABASE_URL, null)
        val supabaseKey = prefs?.getString(KEY_SUPABASE_KEY, null)

        if (deviceId == null || supabaseUrl == null || supabaseKey == null) {
            Log.w(TAG, "Cannot save location: missing configuration")
            return
        }

        val now = System.currentTimeMillis()
        val lastSaveTime = prefs?.getLong(KEY_LAST_SAVE_TIME, 0L) ?: 0L
        val lastLat = prefs?.getFloat(KEY_LAST_LAT, 0f)?.toDouble() ?: 0.0
        val lastLng = prefs?.getFloat(KEY_LAST_LNG, 0f)?.toDouble() ?: 0.0

        // Check if we should skip this save (deduplication)
        if (!forceUpdate && lastSaveTime > 0) {
            val timeSinceLastSave = now - lastSaveTime

            // Skip if less than minimum interval
            if (timeSinceLastSave < MIN_SAVE_INTERVAL_MS) {
                Log.d(TAG, "Skipping save: only ${timeSinceLastSave}ms since last save")
                return
            }

            // Skip if location hasn't changed significantly
            if (lastLat != 0.0 && lastLng != 0.0) {
                val distance = calculateDistance(lastLat, lastLng, location.latitude, location.longitude)
                if (distance < MIN_DISTANCE_CHANGE && timeSinceLastSave < MIN_SAVE_INTERVAL_MS * 10) {
                    Log.d(TAG, "Skipping save: location changed only ${distance}m")
                    return
                }
            }
        }

        // Save in background thread
        executor.execute {
            try {
                val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(Date())

                // Get address (simple implementation - can be enhanced)
                val address = getAddressFromCoordinates(location.latitude, location.longitude)

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
                    Log.d(TAG, "Location saved successfully: ${location.latitude}, ${location.longitude}")
                    
                    // Update last save tracking
                    prefs?.edit()?.apply {
                        putLong(KEY_LAST_SAVE_TIME, now)
                        putFloat(KEY_LAST_LAT, location.latitude.toFloat())
                        putFloat(KEY_LAST_LNG, location.longitude.toFloat())
                        apply()
                    }
                } else {
                    val error = connection.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
                    Log.e(TAG, "Failed to save location. Response: $responseCode, Error: $error")
                }

                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Error saving location: ${e.message}")
            }
        }
    }

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
