/*
  Run instructions (Windows PowerShell) - run each line separately:

  1) Open project folder:
     cd "D:\without_database 2"

  2) Clean and fetch packages:
     flutter clean
     flutter pub get

  3) Run app (verbose logs are useful for diagnostics):
     flutter run -v

  If flutter run fails with Kotlin/Gradle compilation errors, run Gradle with stacktrace:
     cd android
     .\gradlew.bat :app:compileDebugKotlin --stacktrace
     .\gradlew.bat assembleDebug --stacktrace

  What to paste here if it fails:
  - The first ~200 lines around the error from `flutter run -v` or the Gradle --stacktrace output.
  - That output allows me to produce the exact minimal fix.

  Note: I cannot run the app from here — these commands are for your local machine.
*/
package com.getsurakshaapp

import android.content.Context

/**
 * Standalone OpsManager stub placed in the SurakshaApp package.
 *
 * Why:
 * - MainActivity (and possibly other files) expect OpsManager in this package.
 * - Previously this file delegated to com.mycompany.withoutdatabase.OpsManager,
 *   which caused "Unresolved reference 'OpsManager'" during compilation.
 * - Providing a self-contained no-op implementation here resolves the compile error
 *   without changing any existing application logic or flows.
 *
 * Constraints kept:
 * - Pure placeholder: no state, no side effects, no PIN/auth logic.
 * - Safe to replace later with the real implementation.
 */

object OpsManager {
    // Initialize any required resources. Left intentionally empty.
    fun initialize(context: Context) {
        // no-op placeholder
    }

    // Whether the app/device should be considered locked. Default=false.
    fun isLocked(context: Context): Boolean = false

    // Return stored PIN if any. Default = null (no PIN).
    fun getPin(context: Context): String? = null

    // Store/replace PIN. No-op here.
    fun setPin(context: Context, pin: String) {
        // no-op placeholder
    }

    // Convenience helper; defaults to isLocked.
    fun shouldShowLockScreen(context: Context): Boolean = isLocked(context)
}
