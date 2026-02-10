package com.getsurakshaapp

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import android.util.Log
import androidx.activity.OnBackPressedCallback

class LockActivity : AppCompatActivity() {
    private val TAG = "LockActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lock)

        val pinInput = findViewById<EditText>(R.id.pinInput)
        val unlockButton = findViewById<Button>(R.id.unlockButton)

        val targetPkg = intent?.getStringExtra("target_package")
        val prefs = applicationContext.getSharedPreferences("applock_prefs", Context.MODE_PRIVATE)

        unlockButton.setOnClickListener {
            val entered = pinInput.text?.toString()?.trim()
            
            val specificPin = if (!targetPkg.isNullOrEmpty()) prefs.getString("lock_pin_$targetPkg", null) else null
            val globalPin = prefs.getString("applock_pin", null)
            val stored = specificPin ?: globalPin

            val ok = if (stored == null || entered == null || entered.isEmpty()) {
                false
            } else {
                stored == entered
            }

            if (ok) {
                if (!targetPkg.isNullOrEmpty()) {
                    // Temporarily unlock for 10 MINUTES (600,000 milliseconds)
                    // This prevents asking for PIN every single time the app is opened
                    prefs.edit().putLong("unlocked_until_$targetPkg", System.currentTimeMillis() + 600_000L).apply()
                }
                finish()
            } else {
                Toast.makeText(this, "Wrong PIN", Toast.LENGTH_SHORT).show()
                pinInput.text?.clear()
            }
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val startMain = Intent(Intent.ACTION_MAIN)
                startMain.addCategory(Intent.CATEGORY_HOME)
                startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(startMain)
                finishAffinity()
            }
        })
    }
}
