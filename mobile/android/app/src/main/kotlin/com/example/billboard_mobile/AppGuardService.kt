package com.example.billboard_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Ilova yopilganda ma'lum vaqt o'tgach qayta ochadi.
 * Alohida processda ishlaydi — ilova kill qilinsa ham xizmat ishlashda qoladi.
 */
class AppGuardService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var runnable: Runnable? = null

    companion object {
        private const val CHANNEL_ID = "billboard_guard_channel"
        private const val NOTIFICATION_ID = 9001
        /** Ilova yopilgan bo'lsa shu sekunddan keyin qayta ochish */
        private const val RELAUNCH_DELAY_MS = 60_000L // 60 soniya
        /** Boot yoki xizmat birinchi ishga tushganda birinchi ochish kechikmasi */
        private const val FIRST_LAUNCH_DELAY_MS = 15_000L // 15 soniya
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        scheduleRelaunch()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Billboard",
                NotificationManager.IMPORTANCE_LOW
            ).apply { setShowBadge(false) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Billboard")
            .setContentText("Ilova qayta ochiladi")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun scheduleRelaunch() {
        runnable = object : Runnable {
            override fun run() {
                launchMainActivity()
                handler.postDelayed(this, RELAUNCH_DELAY_MS)
            }
        }
        handler.postDelayed(runnable!!, FIRST_LAUNCH_DELAY_MS)
    }

    private fun launchMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Activity start failed (e.g. from background on strict devices)
        }
    }

    override fun onDestroy() {
        runnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }
}
