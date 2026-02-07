package com.getsurakshaapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.os.PowerManager
import android.app.KeyguardManager

/**
 * Receiver to detect screen on/off state for smart recording
 */
class ScreenStateReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "ScreenStateReceiver"
        var isScreenOn = true
            private set
        var isDeviceUnlocked = true // Default to true since app opening means device is unlocked
            private set
        
        // Track last update time for debugging
        private var lastStateUpdate: Long = 0
            
        /**
         * Initialize screen state from current device state
         * Call this on app startup to get accurate initial state
         */
        fun initializeState(context: Context) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            
            val wasScreenOn = isScreenOn
            val wasUnlocked = isDeviceUnlocked
            
            isScreenOn = powerManager.isInteractive
            isDeviceUnlocked = !keyguardManager.isKeyguardLocked
            lastStateUpdate = System.currentTimeMillis()
            
            if (wasScreenOn != isScreenOn || wasUnlocked != isDeviceUnlocked) {
                Log.d(TAG, "📱 State UPDATED: screenOn=$isScreenOn (was $wasScreenOn), unlocked=$isDeviceUnlocked (was $wasUnlocked)")
            } else {
                Log.d(TAG, "📱 State confirmed: screenOn=$isScreenOn, unlocked=$isDeviceUnlocked")
            }
        }
        
        /**
         * Get state freshness for debugging
         */
        fun getStateAge(): Long {
            return System.currentTimeMillis() - lastStateUpdate
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "📱 Screen turned ON")
                isScreenOn = true
                lastStateUpdate = System.currentTimeMillis()
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = true, isUnlocked = isDeviceUnlocked)
            }
            
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "📱 Screen turned OFF")
                isScreenOn = false
                isDeviceUnlocked = false
                lastStateUpdate = System.currentTimeMillis()
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = false, isUnlocked = false)
            }
            
            Intent.ACTION_USER_PRESENT -> {
                Log.d(TAG, "🔓 Device UNLOCKED")
                isDeviceUnlocked = true
                isScreenOn = true // Screen must be on if user present
                lastStateUpdate = System.currentTimeMillis()
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = true, isUnlocked = true)
            }
        }
    }
}
