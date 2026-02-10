package com.getsurakshaapp

import android.accounts.Account
import android.content.Context
import android.util.Log
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.signin.GoogleSignIn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL

data class DriveUploadResult(
    val fileId: String,
    val fileName: String,
    val webLink: String?
)

object GoogleDriveUploader {
    private const val TAG = "GoogleDriveUploader"
    private const val PREFS = "google_drive_prefs"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_ACCOUNT = "selected_account"
    private const val KEY_TOKEN_EXPIRY = "token_expiry"
    
    // SharedPreferences keys for Supabase (same as CameraRecordService)
    private const val CAMERA_PREFS = "camera_record_prefs"
    private const val KEY_SUPABASE_URL = "supabase_url"
    private const val KEY_SUPABASE_KEY = "supabase_key"
    private const val KEY_DEVICE_ID = "device_id"
    
    private var accessToken: String? = null
    private var folderId: String? = null
    private var lastTokenRefreshRequestTime: Long = 0
    
    /**
     * Initialize Google Drive with access token
     */
    fun initialize(context: Context, accountName: String, token: String) {
        accessToken = token
        
        // Save for later use with expiry time (1 hour from now)
        val expiryTime = System.currentTimeMillis() + (3600 * 1000)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACCOUNT, accountName)
            .putString(KEY_ACCESS_TOKEN, token)
            .putLong(KEY_TOKEN_EXPIRY, expiryTime)
            .apply()
        
        Log.d(TAG, "✅ Google Drive initialized for: $accountName")
    }
    
    /**
     * Set access token directly
     */
    fun setAccessToken(token: String) {
        accessToken = token
        Log.d(TAG, "✅ Access token updated")
    }
    
    /**
     * Check if Drive is initialized and token is valid
     */
    fun isInitialized(context: Context? = null): Boolean {
        if (!accessToken.isNullOrEmpty()) {
            // Check if token might be expired
            if (context != null) {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val expiry = prefs.getLong(KEY_TOKEN_EXPIRY, 0)
                if (expiry > 0 && System.currentTimeMillis() > expiry) {
                    Log.w(TAG, "⚠️ Access token may be expired")
                    // Token expired but we still have it - try anyway
                }
            }
            return true
        }
        return false
    }
    
    /**
     * Get saved account name
     */
    fun getSavedAccount(context: Context): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ACCOUNT, null)
    }
    
    /**
     * Load saved token
     */
    fun loadSavedToken(context: Context): String? {
        val token = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ACCESS_TOKEN, null)
        if (!token.isNullOrEmpty()) {
            accessToken = token
        }
        return token
    }
    
    /**
     * Silently refresh token using last signed-in Google account
     * This works if user previously signed in with Google
     */
    suspend fun refreshTokenSilently(context: Context): Boolean = withContext(Dispatchers.IO) {
        try {
            // First try to get the last signed-in account
            val account = GoogleSignIn.getLastSignedInAccount(context)
            if (account?.account != null) {
                Log.d(TAG, "🔄 Found signed-in account: ${account.email}")
                
                // Invalidate old token first if we have one
                val currentToken = accessToken
                if (!currentToken.isNullOrEmpty()) {
                    try {
                        GoogleAuthUtil.clearToken(context, currentToken)
                        Log.d(TAG, "🗑️ Cleared old token")
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not clear old token: ${e.message}")
                    }
                }

                // Try to get a fresh token silently
                val scope = "oauth2:https://www.googleapis.com/auth/drive.file"
                try {
                    val token = GoogleAuthUtil.getToken(context, account.account!!, scope)
                    if (!token.isNullOrEmpty()) {
                        Log.d(TAG, "✅ Silently refreshed token: ${token.take(20)}...")
                        initialize(context, account.email ?: "", token)
                        return@withContext true
                    } else {
                        Log.w(TAG, "⚠️ Token refresh returned empty token")
                    }
                } catch (e: com.google.android.gms.auth.UserRecoverableAuthException) {
                    // User needs to re-consent - can't do this silently
                    Log.w(TAG, "⚠️ User needs to re-consent for Drive access")
                    Log.w(TAG, "   User must open app and reconnect Google Drive")
                } catch (e: com.google.android.gms.auth.GoogleAuthException) {
                    Log.e(TAG, "❌ Google Auth error: ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Silent token refresh failed: ${e.message}")
                }
            } else {
                Log.d(TAG, "ℹ️ No previously signed-in Google account found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking for signed-in account: ${e.message}")
        }
        return@withContext false
    }
    
    /**
     * Refresh token by re-fetching from Supabase (parent's latest token).
     * This is the KEY fallback for child devices where GoogleSignIn is not available.
     * The parent device refreshes its token and saves it to Supabase.
     * The child can re-fetch the latest token.
     */
    suspend fun refreshTokenFromSupabase(context: Context): Boolean = withContext(Dispatchers.IO) {
        try {
            // Get Supabase credentials and device ID from SharedPreferences
            val cameraPrefs = context.getSharedPreferences(CAMERA_PREFS, Context.MODE_PRIVATE)
            var deviceId = cameraPrefs.getString(KEY_DEVICE_ID, null)
            var supabaseUrl = cameraPrefs.getString(KEY_SUPABASE_URL, null)
            var supabaseKey = cameraPrefs.getString(KEY_SUPABASE_KEY, null)
            
            // Fallback: try other SharedPreferences
            if (deviceId.isNullOrEmpty()) {
                val locationPrefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                deviceId = locationPrefs.getString("device_id", null)
            }
            if (deviceId.isNullOrEmpty()) {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                deviceId = flutterPrefs.getString("flutter.child_device_id", null)
                    ?: flutterPrefs.getString("flutter.device_id_backup", null)
            }
            
            if (supabaseUrl.isNullOrEmpty()) {
                supabaseUrl = "https://myxdypywnifdsaorlhsy.supabase.co"
            }
            if (supabaseKey.isNullOrEmpty()) {
                supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
            }
            
            if (deviceId.isNullOrEmpty()) {
                Log.e(TAG, "❌ Cannot refresh from Supabase: no device ID")
                return@withContext false
            }
            
            Log.d(TAG, "🔄 Refreshing token from Supabase for device: $deviceId")
            
            val endpoint = "$supabaseUrl/rest/v1/devices?id=eq.$deviceId&select=google_drive_email,google_drive_token,google_drive_token_updated_at"
            val url = URL(endpoint)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "GET"
            connection.setRequestProperty("apikey", supabaseKey)
            connection.setRequestProperty("Authorization", "Bearer $supabaseKey")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            
            val responseCode = connection.responseCode
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val jsonArray = JSONArray(response)
                
                if (jsonArray.length() > 0) {
                    val device = jsonArray.getJSONObject(0)
                    val email = device.optString("google_drive_email", "")
                    val token = device.optString("google_drive_token", "")
                    val updatedAt = device.optString("google_drive_token_updated_at", "")
                    
                    if (token.isNotEmpty() && email.isNotEmpty()) {
                        // Check if this is a DIFFERENT (newer) token than what we had
                        val currentToken = accessToken
                        if (token != currentToken) {
                            Log.d(TAG, "✅ Got fresh token from Supabase!")
                            Log.d(TAG, "   Email: $email")
                            Log.d(TAG, "   Token updated: $updatedAt")
                            Log.d(TAG, "   Token: ${token.take(20)}...")
                            initialize(context, email, token)
                            connection.disconnect()
                            return@withContext true
                        } else {
                            Log.w(TAG, "⚠️ Supabase has same token (also expired)")
                            Log.w(TAG, "   Token updated: $updatedAt")
                            Log.w(TAG, "   Requesting parent to refresh token...")
                            
                            // Signal the parent device to refresh the token
                            requestTokenRefreshFromParent(context)
                        }
                    } else {
                        Log.w(TAG, "⚠️ No Google Drive token in Supabase for device: $deviceId")
                    }
                } else {
                    Log.w(TAG, "⚠️ Device not found in Supabase: $deviceId")
                }
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Supabase request failed (HTTP $responseCode): $errorBody")
            }
            
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error refreshing token from Supabase: ${e.message}", e)
        }
        return@withContext false
    }
    
    /**
     * Clear saved token from SharedPreferences (call on confirmed 401)
     */
    fun clearSavedToken(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ACCESS_TOKEN)
            .putLong(KEY_TOKEN_EXPIRY, 0)
            .apply()
        accessToken = null
        folderId = null
        Log.d(TAG, "🗑️ Cleared saved token from SharedPreferences")
    }
    
    /**
     * Request the parent device to refresh the Google Drive token.
     * Writes a flag to the Supabase devices table so parent can detect it.
     * Rate-limited to once every 5 minutes to avoid spamming.
     */
    private fun requestTokenRefreshFromParent(context: Context) {
        try {
            // Rate limit: only request once every 5 minutes
            val now = System.currentTimeMillis()
            if (now - lastTokenRefreshRequestTime < 5 * 60 * 1000) {
                Log.d(TAG, "⏰ Token refresh already requested recently, skipping")
                return
            }
            lastTokenRefreshRequestTime = now
            
            val cameraPrefs = context.getSharedPreferences(CAMERA_PREFS, Context.MODE_PRIVATE)
            var deviceId = cameraPrefs.getString(KEY_DEVICE_ID, null)
            if (deviceId.isNullOrEmpty()) {
                val locationPrefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                deviceId = locationPrefs.getString("device_id", null)
            }
            if (deviceId.isNullOrEmpty()) {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                deviceId = flutterPrefs.getString("flutter.child_device_id", null)
                    ?: flutterPrefs.getString("flutter.device_id_backup", null)
            }
            
            if (deviceId.isNullOrEmpty()) {
                Log.w(TAG, "⚠️ Cannot request token refresh: no device ID")
                return
            }
            
            val supabaseUrl = cameraPrefs.getString(KEY_SUPABASE_URL, null)
                ?: "https://myxdypywnifdsaorlhsy.supabase.co"
            val supabaseKey = cameraPrefs.getString(KEY_SUPABASE_KEY, null)
                ?: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8"
            
            Log.d(TAG, "📨 Writing token_refresh_requested for device: $deviceId")
            
            val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
            dateFormat.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val nowStr = dateFormat.format(java.util.Date())
            
            val payload = JSONObject().apply {
                put("token_refresh_requested", true)
                put("token_refresh_requested_at", nowStr)
            }
            
            val endpoint = "$supabaseUrl/rest/v1/devices?id=eq.$deviceId"
            val url = URL(endpoint)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "PATCH"
            conn.setRequestProperty("apikey", supabaseKey)
            conn.setRequestProperty("Authorization", "Bearer $supabaseKey")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Prefer", "return=minimal")
            conn.doOutput = true
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            
            conn.outputStream.use { os ->
                os.write(payload.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }
            
            val responseCode = conn.responseCode
            if (responseCode in 200..299) {
                Log.d(TAG, "✅ Token refresh request written to Supabase")
            } else {
                // Column may not exist yet - this is non-fatal
                Log.d(TAG, "ℹ️ Token refresh request column may not exist yet (HTTP $responseCode)")
            }
            conn.disconnect()
            
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Error requesting token refresh: ${e.message}")
        }
    }
    
    /**
     * Upload file to Google Drive using REST API
     */
    suspend fun uploadFile(context: Context, file: File): DriveUploadResult? = withContext(Dispatchers.IO) {
        try {
            // Load token if not set
            if (accessToken.isNullOrEmpty()) {
                loadSavedToken(context)
            }
            
            // Check if token is near expiry (within 5 minutes) and proactively refresh
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val tokenExpiry = prefs.getLong(KEY_TOKEN_EXPIRY, 0)
            val fiveMinutes = 5 * 60 * 1000L
            if (tokenExpiry > 0 && System.currentTimeMillis() > (tokenExpiry - fiveMinutes)) {
                Log.d(TAG, "⏰ Token expired or near expiry, proactively refreshing...")
                val refreshed = refreshTokenSilently(context) || refreshTokenFromSupabase(context)
                if (refreshed) {
                    Log.d(TAG, "✅ Proactive token refresh successful!")
                } else {
                    Log.w(TAG, "⚠️ Proactive refresh failed, will try upload with current token anyway")
                }
            }
            
            // Try silent token refresh if still no token
            if (accessToken.isNullOrEmpty()) {
                Log.d(TAG, "🔄 No saved token, attempting refresh chain...")
                if (refreshTokenSilently(context)) {
                    Log.d(TAG, "✅ Silent refresh successful!")
                } else if (refreshTokenFromSupabase(context)) {
                    Log.d(TAG, "✅ Supabase token refresh successful!")
                }
            }
            
            if (accessToken.isNullOrEmpty()) {
                Log.e(TAG, "❌ No access token available - Google Drive not connected")
                Log.e(TAG, "   User needs to connect Google Drive in app settings")
                return@withContext null
            }
            
            val fileSizeKB = file.length() / 1024
            Log.d(TAG, "📤 Starting upload: ${file.name} (${fileSizeKB}KB)")
            Log.d(TAG, "   Token available: ${accessToken?.take(20)}...")
            
            // Get or create Suraksha folder
            val parentFolderId = getOrCreateFolder("SurakshaRecordings")
            Log.d(TAG, "   Folder ID: ${parentFolderId ?: "root"}")
            
            // Upload using multipart upload
            var result = uploadFileMultipart(context, file, parentFolderId)

            // If upload failed with auth error (401/403 clears accessToken), try refresh chain
            if (result == null && accessToken == null) {
                Log.d(TAG, "🔄 Upload failed with auth error, trying refresh chain...")
                
                // First try GoogleSignIn refresh (works on parent device)
                var refreshed = refreshTokenSilently(context)
                
                // If GoogleSignIn failed, try Supabase (works on child device)
                if (!refreshed) {
                    Log.d(TAG, "🔄 GoogleSignIn refresh failed, trying Supabase refresh...")
                    refreshed = refreshTokenFromSupabase(context)
                }
                
                if (refreshed) {
                    Log.d(TAG, "✅ Token refreshed, retrying upload...")
                    // Also need to refresh folder ID since it may have been created with old token
                    folderId = null
                    val newFolderId = getOrCreateFolder("SurakshaRecordings")
                    result = uploadFileMultipart(context, file, newFolderId)
                    
                    // If retry also failed, try one more time after a delay
                    if (result == null && accessToken == null) {
                        Log.d(TAG, "🔄 Second attempt failed, trying Supabase refresh one more time...")
                        kotlinx.coroutines.delay(3000)
                        refreshed = refreshTokenFromSupabase(context)
                        if (refreshed) {
                            folderId = null
                            val retryFolderId = getOrCreateFolder("SurakshaRecordings")
                            result = uploadFileMultipart(context, file, retryFolderId)
                        }
                    }
                } else {
                    Log.e(TAG, "❌ All token refresh methods failed!")
                    Log.e(TAG, "   Parent needs to open the app to refresh Google Drive token")
                    // Request parent to refresh token via Supabase flag
                    requestTokenRefreshFromParent(context)
                }
            }

            if (result != null) {
                Log.d(TAG, "✅ Upload completed successfully!")
                Log.d(TAG, "   📎 File ID: ${result.fileId}")
                Log.d(TAG, "   📄 Name: ${result.fileName}")
                Log.d(TAG, "   🔗 Link: ${result.webLink}")
            } else {
                Log.e(TAG, "❌ Upload returned null result")
            }
            
            return@withContext result
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Upload failed with exception: ${e.message}", e)
            e.printStackTrace()
            return@withContext null
        }
    }
    
    /**
     * Upload file using multipart request
     */
    private fun uploadFileMultipart(context: Context, file: File, parentFolderId: String?): DriveUploadResult? {
        var connection: HttpURLConnection? = null
        try {
            val boundary = "====${System.currentTimeMillis()}===="
            val url = URL("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink,webContentLink")
            connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Content-Type", "multipart/related; boundary=$boundary")
            connection.doOutput = true
            connection.connectTimeout = 120000  // 2 minutes for slow connections
            connection.readTimeout = 120000
            
            Log.d(TAG, "🔄 Connecting to Google Drive API...")
            
            // Build metadata
            val metadata = JSONObject().apply {
                put("name", file.name)
                put("mimeType", "video/mp4")
                if (parentFolderId != null) {
                    put("parents", org.json.JSONArray().put(parentFolderId))
                }
            }
            
            connection.outputStream.use { os ->
                val writer = os.bufferedWriter()
                
                // Write metadata part
                writer.write("--$boundary\r\n")
                writer.write("Content-Type: application/json; charset=UTF-8\r\n\r\n")
                writer.write(metadata.toString())
                writer.write("\r\n")
                
                // Write file part
                writer.write("--$boundary\r\n")
                writer.write("Content-Type: video/mp4\r\n\r\n")
                writer.flush()
                
                // Stream file content
                Log.d(TAG, "📤 Streaming file content...")
                var totalBytes = 0L
                FileInputStream(file).use { fis ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (fis.read(buffer).also { bytesRead = it } != -1) {
                        os.write(buffer, 0, bytesRead)
                        totalBytes += bytesRead
                    }
                }
                Log.d(TAG, "   Streamed ${totalBytes / 1024}KB")
                
                writer.write("\r\n--$boundary--\r\n")
                writer.flush()
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📨 Response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK || responseCode == HttpURLConnection.HTTP_CREATED) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "📨 Response: $response")
                val json = JSONObject(response)
                
                // Try to get webViewLink or webContentLink
                var webLink = json.optString("webViewLink", null)
                if (webLink.isNullOrEmpty()) {
                    webLink = json.optString("webContentLink", null)
                }
                // Construct link if not provided
                if (webLink.isNullOrEmpty()) {
                    val fileId = json.getString("id")
                    webLink = "https://drive.google.com/file/d/$fileId/view"
                }
                
                return DriveUploadResult(
                    fileId = json.getString("id"),
                    fileName = json.getString("name"),
                    webLink = webLink
                )
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "❌ Upload failed (HTTP $responseCode)")
                Log.e(TAG, "   Error: $errorStream")
                
                // Check for auth errors
                if (responseCode == 401 || responseCode == 403) {
                    Log.e(TAG, "🔑 Authentication error - token expired or invalid")
                    Log.e(TAG, "   Clearing invalid token from memory AND SharedPreferences")
                    clearSavedToken(context)  // Clear from both memory and SharedPreferences
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Multipart upload error: ${e.message}", e)
            e.printStackTrace()
        } finally {
            connection?.disconnect()
        }
        
        return null
    }
    
    /**
     * Get or create a folder in Google Drive
     */
    private fun getOrCreateFolder(folderName: String): String? {
        try {
            // Check if folder already exists
            if (folderId != null) return folderId
            
            // Search for existing folder
            val query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false"
            val searchUrl = URL("https://www.googleapis.com/drive/v3/files?q=${java.net.URLEncoder.encode(query, "UTF-8")}&fields=files(id,name)")
            val searchConnection = searchUrl.openConnection() as HttpURLConnection
            
            searchConnection.requestMethod = "GET"
            searchConnection.setRequestProperty("Authorization", "Bearer $accessToken")
            searchConnection.connectTimeout = 10000
            searchConnection.readTimeout = 10000
            
            if (searchConnection.responseCode == HttpURLConnection.HTTP_OK) {
                val response = searchConnection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                val files = json.getJSONArray("files")
                
                if (files.length() > 0) {
                    folderId = files.getJSONObject(0).getString("id")
                    Log.d(TAG, "📁 Found existing folder: $folderId")
                    searchConnection.disconnect()
                    return folderId
                }
            }
            searchConnection.disconnect()
            
            // Create new folder
            val createUrl = URL("https://www.googleapis.com/drive/v3/files?fields=id")
            val createConnection = createUrl.openConnection() as HttpURLConnection
            
            createConnection.requestMethod = "POST"
            createConnection.setRequestProperty("Authorization", "Bearer $accessToken")
            createConnection.setRequestProperty("Content-Type", "application/json")
            createConnection.doOutput = true
            
            val folderMetadata = JSONObject().apply {
                put("name", folderName)
                put("mimeType", "application/vnd.google-apps.folder")
            }
            
            createConnection.outputStream.use { os ->
                os.write(folderMetadata.toString().toByteArray(Charsets.UTF_8))
            }
            
            if (createConnection.responseCode == HttpURLConnection.HTTP_OK || createConnection.responseCode == HttpURLConnection.HTTP_CREATED) {
                val response = createConnection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                folderId = json.getString("id")
                Log.d(TAG, "📁 Created new folder: $folderId")
            }
            
            createConnection.disconnect()
            return folderId
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to get/create folder: ${e.message}")
        }
        
        return null
    }
    
    /**
     * List all recordings in Drive folder
     */
    suspend fun listRecordings(): List<DriveUploadResult> = withContext(Dispatchers.IO) {
        try {
            if (accessToken.isNullOrEmpty()) {
                return@withContext emptyList()
            }
            
            val query = if (folderId != null) {
                "'$folderId' in parents and mimeType='video/mp4' and trashed=false"
            } else {
                "name contains 'SurakshaRecord' and mimeType='video/mp4' and trashed=false"
            }
            
            val url = URL("https://www.googleapis.com/drive/v3/files?q=${java.net.URLEncoder.encode(query, "UTF-8")}&fields=files(id,name,webViewLink)&orderBy=createdTime desc&pageSize=50")
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "GET"
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                val files = json.getJSONArray("files")
                
                val results = mutableListOf<DriveUploadResult>()
                for (i in 0 until files.length()) {
                    val file = files.getJSONObject(i)
                    results.add(DriveUploadResult(
                        fileId = file.getString("id"),
                        fileName = file.getString("name"),
                        webLink = file.optString("webViewLink", null)
                    ))
                }
                
                connection.disconnect()
                return@withContext results
            }
            
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to list recordings: ${e.message}")
        }
        
        return@withContext emptyList()
    }
}
