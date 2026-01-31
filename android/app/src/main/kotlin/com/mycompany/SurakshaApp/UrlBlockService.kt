package com.mycompany.SurakshaApp

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import java.util.Collections

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
}
