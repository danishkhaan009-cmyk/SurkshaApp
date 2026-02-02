package com.mycompany.SurakshaApp

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject
import java.util.Collections
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Service to fetch and manage blocked URLs from Supabase
 */
object UrlBlockService {
    private const val TAG = "UrlBlockService"
    private const val PREFS = "url_block_prefs"
    private const val KEY_BLOCKED_URLS = "blocked_urls"
    private const val KEY_LAST_SYNC = "last_sync"
    private const val KEY_SUPABASE_URL = "supabase_url"
    private const val KEY_SUPABASE_KEY = "supabase_key"
    private const val KEY_DEVICE_ID = "device_id"
    
    private val blockedUrls = Collections.synchronizedSet(mutableSetOf<String>())
    private var lastSyncTime = 0L
    private const val SYNC_INTERVAL = 30 * 1000L // 30 seconds
    
    private var supabaseUrl: String? = null
    private var supabaseKey: String? = null
    private var deviceId: String? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Initialize the URL blocking service
     */
    fun initialize(context: Context, supUrl: String, supKey: String, devId: String) {
        supabaseUrl = supUrl
        supabaseKey = supKey
        deviceId = devId
        
        // Save credentials to SharedPreferences for persistence
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString(KEY_SUPABASE_URL, supUrl)
            putString(KEY_SUPABASE_KEY, supKey)
            putString(KEY_DEVICE_ID, devId)
            apply()
        }
        
        Log.d(TAG, "✅ Credentials saved - URL: ${supUrl.take(30)}..., Key: ${supKey.take(20)}..., Device: $devId")
        
        loadFromPrefs(context)
        
        // Sync immediately on init
        scope.launch {
            syncBlockedUrls(context)
        }
        
        Log.d(TAG, "✅ URL Block Service initialized with ${blockedUrls.size} blocked URLs")
    }

    /**
     * Check if a URL is blocked
     */
    fun isUrlBlocked(url: String): Boolean {
        val cleanUrl = cleanUrl(url)
        
        // Check exact match
        if (blockedUrls.contains(cleanUrl)) {
            Log.d(TAG, "🚫 URL blocked (exact): $cleanUrl")
            return true
        }
        
        // Check domain match
        synchronized(blockedUrls) {
            for (blockedUrl in blockedUrls) {
                if (matchesDomain(cleanUrl, blockedUrl)) {
                    Log.d(TAG, "🚫 URL blocked (domain): $cleanUrl matches $blockedUrl")
                    return true
                }
            }
        }
        
        return false
    }

    /**
     * Sync blocked URLs from Supabase
     */

    suspend fun syncBlockedUrls(context: Context) {
        // Load credentials from SharedPreferences if not in memory
        if (supabaseUrl == null || supabaseKey == null || deviceId == null) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
            supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)
            deviceId = prefs.getString(KEY_DEVICE_ID, null)

            if (deviceId.isNullOrEmpty()) {
                val locationPrefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                deviceId = locationPrefs.getString("device_id", null)
            }

            // Also try FlutterSharedPreferences
            if (deviceId.isNullOrEmpty()) {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                deviceId = flutterPrefs.getString("flutter.device_id", null)
                Log.d(TAG, "📂 Fallback device ID from FlutterSharedPreferences: $deviceId")
            }
        }

        if (supabaseUrl.isNullOrEmpty() || supabaseKey.isNullOrEmpty() || deviceId.isNullOrEmpty()) {
            Log.e(TAG, "❌ Missing credentials - URL: $supabaseUrl, Key exists: ${!supabaseKey.isNullOrEmpty()}, Device: $deviceId")
            return
        }

        Log.d(TAG, "🔄 Syncing for device: $deviceId")
        Log.d(TAG, "🔄 Supabase URL: ${supabaseUrl?.take(50)}...")

        try {
            val endpoint = "$supabaseUrl/rest/v1/blocked_urls?device_id=eq.$deviceId&is_active=eq.true&select=url"
            val url = URL(endpoint)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "GET"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 Response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "📡 Response: $response")
                
                // Parse JSON response
                val jsonArray = JSONArray(response)
                val newUrls = mutableSetOf<String>()
                
                for (i in 0 until jsonArray.length()) {
                    val item = jsonArray.getJSONObject(i)
                    val blockedUrl = item.getString("url")
                    newUrls.add(cleanUrl(blockedUrl))
                }
                
                // Update blocked URLs
                synchronized(blockedUrls) {
                    blockedUrls.clear()
                    blockedUrls.addAll(newUrls)
                }
                
                // Save to SharedPreferences
                saveToPrefs(context)
                lastSyncTime = System.currentTimeMillis()
                
                Log.d(TAG, "✅ Synced ${blockedUrls.size} blocked URLs")
                Log.d(TAG, "🔍 Blocked URLs: $blockedUrls")
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Sync failed with code $responseCode: $errorStream")
            }
            
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Sync error: ${e.message}", e)
            e.printStackTrace()
        }
    }


    /**
     * Add blocked URLs manually (for testing)
     */
    fun addBlockedUrl(context: Context, url: String) {
        val cleanedUrl = cleanUrl(url)
        blockedUrls.add(cleanedUrl)
        saveToPrefs(context)
        Log.d(TAG, "➕ Added blocked URL: $cleanedUrl")
    }

    /**
     * Clean and normalize URL
     */
    private fun cleanUrl(url: String): String {
        var cleaned = url.trim().lowercase()
        
        // Remove protocol
        cleaned = cleaned.replace("http://", "")
        cleaned = cleaned.replace("https://", "")
        
        // Remove trailing slash
        cleaned = cleaned.trimEnd('/')
        
        // Remove www prefix for consistency
        cleaned = cleaned.removePrefix("www.")
        
        return cleaned
    }

    /**
     * Extract domain from URL
     */
    private fun extractDomain(url: String): String {
        val cleaned = cleanUrl(url)
        // Take everything before the first slash
        val domain = cleaned.split('/').first()
        return domain
    }

    /**
     * Save blocked URLs to SharedPreferences
     */
    private fun saveToPrefs(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val editor = prefs.edit()
            editor.putStringSet(KEY_BLOCKED_URLS, blockedUrls)
            editor.putLong(KEY_LAST_SYNC, lastSyncTime)
            editor.apply()
            Log.d(TAG, "💾 Saved ${blockedUrls.size} URLs to preferences")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to save URLs: ${e.message}")
        }
    }

    /**
     * Load blocked URLs from SharedPreferences
     */
    private fun loadFromPrefs(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val savedUrls = prefs.getStringSet(KEY_BLOCKED_URLS, emptySet()) ?: emptySet()
            blockedUrls.clear()
            blockedUrls.addAll(savedUrls)
            lastSyncTime = prefs.getLong(KEY_LAST_SYNC, 0L)
            Log.d(TAG, "📂 Loaded ${blockedUrls.size} URLs from preferences")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load URLs: ${e.message}")
        }
    }

    /**
     * Get all blocked URLs
     */
    fun getBlockedUrls(): Set<String> {
        return blockedUrls.toSet()
    }

    /**
     * Force sync now
     */
    fun forceSyncNow(context: Context, callback: (() -> Unit)? = null) {
        lastSyncTime = 0L
        scope.launch {
            syncBlockedUrls(context)
            withContext(Dispatchers.Main) {
                callback?.invoke()
            }
        }
    }

    /**
     * Check if two URLs match domains
     */
    private fun matchesDomain(url: String, blockedUrl: String): Boolean {
        val urlDomain = extractDomain(url)
        val blockedDomain = extractDomain(blockedUrl)
        
        // Exact match
        if (urlDomain == blockedDomain) return true
        
        // Subdomain match: www.facebook.com matches facebook.com
        if (urlDomain.endsWith(".$blockedDomain")) return true
        
        // Reverse: facebook.com should match www.facebook.com
        if (blockedDomain.endsWith(".$urlDomain")) return true
        
        return false
    }

    // Track recently recorded URLs to avoid duplicates
    private val recentlyRecordedUrls = Collections.synchronizedSet(mutableSetOf<String>())
    private const val RECORD_COOLDOWN = 30 * 1000L // 30 seconds cooldown for same URL

    /**
     * Record a URL visit to Supabase search_history table
     */
    fun recordBrowsingHistory(context: Context, url: String, title: String? = null) {
        scope.launch {
            recordBrowsingHistoryAsync(context, url, title)
        }
    }

    /**
     * Record browsing history asynchronously
     */
    private suspend fun recordBrowsingHistoryAsync(context: Context, url: String, title: String? = null) {
        try {
            Log.d(TAG, "📝 recordBrowsingHistoryAsync called with URL: $url")
            
            // Load credentials if needed
            if (supabaseUrl == null || supabaseKey == null || deviceId == null) {
                Log.d(TAG, "🔑 Loading credentials from SharedPreferences...")
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null)
                supabaseKey = prefs.getString(KEY_SUPABASE_KEY, null)
                deviceId = prefs.getString(KEY_DEVICE_ID, null)
                
                Log.d(TAG, "🔑 From url_block_prefs - URL: ${supabaseUrl?.take(30)}, Key: ${supabaseKey?.take(20)}, Device: $deviceId")

                if (deviceId.isNullOrEmpty()) {
                    val locationPrefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                    deviceId = locationPrefs.getString("device_id", null)
                    Log.d(TAG, "🔑 From location_service_prefs - Device: $deviceId")
                }

                if (deviceId.isNullOrEmpty()) {
                    val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    deviceId = flutterPrefs.getString("flutter.device_id", null)
                    Log.d(TAG, "🔑 From FlutterSharedPreferences - Device: $deviceId")
                }
                
                // Fallback to hardcoded Supabase credentials if not found
                if (supabaseUrl.isNullOrEmpty()) {
                    supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
                    Log.d(TAG, "🔑 Using hardcoded Supabase URL")
                }
                if (supabaseKey.isNullOrEmpty()) {
                    supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
                    Log.d(TAG, "🔑 Using hardcoded Supabase key")
                }
            }

            if (supabaseUrl.isNullOrEmpty() || supabaseKey.isNullOrEmpty() || deviceId.isNullOrEmpty()) {
                Log.e(TAG, "❌ Cannot record history - missing credentials")
                Log.e(TAG, "   supabaseUrl: ${if (supabaseUrl.isNullOrEmpty()) "MISSING" else "OK"}")
                Log.e(TAG, "   supabaseKey: ${if (supabaseKey.isNullOrEmpty()) "MISSING" else "OK"}")
                Log.e(TAG, "   deviceId: ${if (deviceId.isNullOrEmpty()) "MISSING" else deviceId}")
                return
            }

            // Clean URL
            var cleanedUrl = url.trim()
            if (!cleanedUrl.startsWith("http://") && !cleanedUrl.startsWith("https://")) {
                cleanedUrl = "https://$cleanedUrl"
            }

            // Check if we recently recorded this URL
            val urlKey = "$deviceId:$cleanedUrl"
            if (recentlyRecordedUrls.contains(urlKey)) {
                Log.d(TAG, "⏭️ Skipping recently recorded URL: $cleanedUrl")
                return
            }

            // Add to recently recorded set
            recentlyRecordedUrls.add(urlKey)
            
            // Remove from set after cooldown
            scope.launch {
                delay(RECORD_COOLDOWN)
                recentlyRecordedUrls.remove(urlKey)
            }

            // Create ISO 8601 timestamp
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
            val timestamp = dateFormat.format(Date())

            // Create JSON payload
            val jsonPayload = JSONObject().apply {
                put("device_id", deviceId)
                put("url", cleanedUrl)
                put("title", title ?: extractDomain(cleanedUrl))
                put("visited_at", timestamp)
                put("visit_count", 1)
            }

            Log.d(TAG, "📝 Recording browsing history: $cleanedUrl")

            // Send to Supabase
            val endpoint = "$supabaseUrl/rest/v1/search_history"
            val urlConnection = URL(endpoint).openConnection() as HttpURLConnection
            
            urlConnection.requestMethod = "POST"
            urlConnection.setRequestProperty("apikey", supabaseKey)
            urlConnection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            urlConnection.setRequestProperty("Content-Type", "application/json")
            urlConnection.setRequestProperty("Prefer", "return=minimal")
            urlConnection.doOutput = true
            urlConnection.connectTimeout = 10000
            urlConnection.readTimeout = 10000

            urlConnection.outputStream.use { os ->
                os.write(jsonPayload.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }

            val responseCode = urlConnection.responseCode
            
            if (responseCode == HttpURLConnection.HTTP_CREATED || responseCode == HttpURLConnection.HTTP_OK) {
                Log.d(TAG, "✅ Browsing history recorded: $cleanedUrl")
            } else {
                val errorStream = urlConnection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Failed to record history ($responseCode): $errorStream")
                
                // If conflict (duplicate), try to update visit_count instead
                if (responseCode == 409) {
                    updateVisitCount(cleanedUrl)
                }
            }

            urlConnection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error recording browsing history: ${e.message}", e)
        }
    }

    /**
     * Update visit count for an existing URL
     */
    private suspend fun updateVisitCount(url: String) {
        try {
            if (supabaseUrl.isNullOrEmpty() || supabaseKey.isNullOrEmpty() || deviceId.isNullOrEmpty()) {
                return
            }

            // First, get current visit count
            val selectEndpoint = "$supabaseUrl/rest/v1/search_history?device_id=eq.$deviceId&url=eq.${java.net.URLEncoder.encode(url, "UTF-8")}&select=id,visit_count"
            val selectUrl = URL(selectEndpoint)
            val selectConnection = selectUrl.openConnection() as HttpURLConnection
            
            selectConnection.requestMethod = "GET"
            selectConnection.setRequestProperty("apikey", supabaseKey)
            selectConnection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            selectConnection.setRequestProperty("Content-Type", "application/json")
            selectConnection.connectTimeout = 10000
            selectConnection.readTimeout = 10000

            val selectResponseCode = selectConnection.responseCode
            if (selectResponseCode == HttpURLConnection.HTTP_OK) {
                val response = selectConnection.inputStream.bufferedReader().use { it.readText() }
                val jsonArray = JSONArray(response)
                
                if (jsonArray.length() > 0) {
                    val item = jsonArray.getJSONObject(0)
                    val recordId = item.getString("id")
                    val currentCount = item.optInt("visit_count", 0)

                    // Update with new visit count
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                    val timestamp = dateFormat.format(Date())

                    val updatePayload = JSONObject().apply {
                        put("visit_count", currentCount + 1)
                        put("visited_at", timestamp)
                    }

                    val updateEndpoint = "$supabaseUrl/rest/v1/search_history?id=eq.$recordId"
                    val updateUrl = URL(updateEndpoint)
                    val updateConnection = updateUrl.openConnection() as HttpURLConnection
                    
                    updateConnection.requestMethod = "PATCH"
                    updateConnection.setRequestProperty("apikey", supabaseKey)
                    updateConnection.setRequestProperty("Authorization", "Bearer $supabaseKey")
                    updateConnection.setRequestProperty("Content-Type", "application/json")
                    updateConnection.setRequestProperty("Prefer", "return=minimal")
                    updateConnection.doOutput = true

                    updateConnection.outputStream.use { os ->
                        os.write(updatePayload.toString().toByteArray(Charsets.UTF_8))
                        os.flush()
                    }

                    val updateResponseCode = updateConnection.responseCode
                    if (updateResponseCode == HttpURLConnection.HTTP_OK || updateResponseCode == HttpURLConnection.HTTP_NO_CONTENT) {
                        Log.d(TAG, "✅ Updated visit count for: $url (count: ${currentCount + 1})")
                    }
                    updateConnection.disconnect()
                }
            }
            selectConnection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating visit count: ${e.message}")
        }
    }
}
