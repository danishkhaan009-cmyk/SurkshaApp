package com.mycompany.SurakshaApp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        com.mycompany.SurakshaApp.AppContextHolder.app = this
    }
}
