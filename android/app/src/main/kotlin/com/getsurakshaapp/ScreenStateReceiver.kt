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
            
        /**
         * Initialize screen state from current device state
         * Call this on app startup to get accurate initial state
         */
        fun initializeState(context: Context) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            
            isScreenOn = powerManager.isInteractive
            isDeviceUnlocked = !keyguardManager.isKeyguardLocked
            
            // Update CameraRecordService with current state
            CameraRecordService.updateScreenState(isScreenOn, isDeviceUnlocked)
            
            Log.d(TAG, "📱 Initial state: screenOn=$isScreenOn, unlocked=$isDeviceUnlocked")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "📱 Screen turned ON")
                isScreenOn = true
                // Screen is on but may still be locked
                CameraRecordService.updateScreenState(isScreenOn, isDeviceUnlocked)
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = true, isUnlocked = isDeviceUnlocked)
            }
            
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "📱 Screen turned OFF")
                isScreenOn = false
                isDeviceUnlocked = false
                // Update camera service and STOP recording when screen is off (child mode)
                CameraRecordService.updateScreenState(false, false)
                // Stop any active camera recording when device is locked
                CameraRecordService.onDeviceLocked(context)
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = false, isUnlocked = false)
            }
            
            Intent.ACTION_USER_PRESENT -> {
                Log.d(TAG, "🔓 Device UNLOCKED")
                isDeviceUnlocked = true
                isScreenOn = true // Screen must be on if user present
                // Update camera service - check for pending recordings when device is unlocked
                CameraRecordService.updateScreenState(true, true)
                // Check for pending recording requests when device is unlocked
                CameraRecordService.onDeviceUnlocked(context)
                ScreenRecordService.onScreenStateChanged(context, isScreenOn = true, isUnlocked = true)
            }
        }
    }
}
