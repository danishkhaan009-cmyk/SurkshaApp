package com.mycompany.SurakshaApp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.InetAddress
import java.net.URI

class VpnBlockService : VpnService() {
    companion object {
        private const val TAG = "VpnBlockService"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "vpn_block_channel"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            startVpn()
        }
        return START_STICKY
    }

    private fun startVpn() {
        try {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, createNotification())

            val builder = Builder()
                .setSession("URL Blocker")
                .addAddress("10.0.0.2", 24)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("10.0.0.1") // Point to our custom DNS handler
                .setBlocking(true)

            vpnInterface = builder.establish()
            isRunning = true

            Log.d(TAG, "✅ VPN started for URL blocking")

            // Start packet processing thread
            Thread { processPackets() }.start()

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start VPN: ${e.message}", e)
        }
    }

    private fun processPackets() {
        val inputStream = FileInputStream(vpnInterface?.fileDescriptor)
        val outputStream = FileOutputStream(vpnInterface?.fileDescriptor)
        val buffer = ByteBuffer.allocate(32767)

        try {
            while (isRunning && !Thread.interrupted()) {
                val length = inputStream.read(buffer.array())
                if (length > 0) {
                    buffer.limit(length)
                    
                    // Extract destination URL/IP from packet
                    val packet = buffer.array()
                    val destIp = extractDestinationIp(packet)
                    
                    // Check if URL is blocked
                    if (isDestinationBlocked(destIp)) {
                        Log.d(TAG, "🚫 Blocked packet to: $destIp")
                        buffer.clear()
                        continue
                    }

                    // Forward packet
                    outputStream.write(buffer.array(), 0, length)
                    buffer.clear()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing packets: ${e.message}")
        }
    }

    private fun extractDestinationIp(packet: ByteArray): String {
        // IP header starts at byte 0, destination IP at bytes 16-19
        return try {
            "${packet[16].toInt() and 0xFF}.${packet[17].toInt() and 0xFF}." +
            "${packet[18].toInt() and 0xFF}.${packet[19].toInt() and 0xFF}"
        } catch (e: Exception) {
            ""
        }
    }

    private val domainToIpCache = mutableMapOf<String, Set<String>>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private fun isDestinationBlocked(ip: String): Boolean {
        val blockedUrls = UrlBlockService.getBlockedUrls()
        
        // Check if IP matches any cached blocked domain
        synchronized(domainToIpCache) {
            for ((domain, ips) in domainToIpCache) {
                if (ips.contains(ip)) {
                    return true
                }
            }
        }
        
        // Resolve domains to IPs in background
        scope.launch {
            resolveBlockedDomains(blockedUrls)
        }
        
        return false
    }

    private suspend fun resolveBlockedDomains(blockedUrls: Set<String>) {
        for (url in blockedUrls) {
            val domain = extractDomain(url)
            if (domain.isNotEmpty() && !domainToIpCache.containsKey(domain)) {
                try {
                    val addresses = InetAddress.getAllByName(domain)
                    val ips = addresses.map { it.hostAddress }.toSet()
                    synchronized(domainToIpCache) {
                        domainToIpCache[domain] = ips
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to resolve $domain: ${e.message}")
                }
            }
        }
    }

    private fun extractDomain(url: String): String {
        return try {
            var urlToParse = url
            if (!url.startsWith("http://") && !url.startsWith("https://")) {
                urlToParse = "https://$url"
            }
            val uri = URI(urlToParse)
            var host = uri.host ?: ""
            if (host.startsWith("www.")) {
                host = host.substring(4)
            }
            host
        } catch (e: Exception) {
            // If URI parsing fails, try simple extraction
            try {
                var domain = url.replace("https://", "").replace("http://", "")
                domain = domain.split("/")[0]
                if (domain.startsWith("www.")) {
                    domain = domain.substring(4)
                }
                domain
            } catch (e2: Exception) {
                ""
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "URL Blocker VPN",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("URL Blocker Active")
            .setContentText("Monitoring and blocking restricted websites")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        vpnInterface?.close()
        Log.d(TAG, "🛑 VPN stopped")
    }
}