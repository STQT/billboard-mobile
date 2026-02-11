package com.example.billboard_mobile

import android.content.Intent
import android.content.pm.ActivityInfo
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        super.onCreate(savedInstanceState)
        startAppGuardService()
    }

    private fun startAppGuardService() {
        val intent = Intent(this, AppGuardService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
