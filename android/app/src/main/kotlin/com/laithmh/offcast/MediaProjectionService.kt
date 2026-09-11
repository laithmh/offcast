package com.laithmh.offcast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MediaProjectionService : Service() {
    companion object {
        const val CHANNEL_ID = "hotspot_media_projection_channel"
        const val NOTIFICATION_ID = 9001
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        var onStopListener: (() -> Unit)? = null
        @Volatile
        var isServiceForegroundStarted = false
        var onServiceStartedListener: (() -> Unit)? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val stopIntent = Intent(this, MediaProjectionService::class.java).apply {
                    action = ACTION_STOP
                }
                val stopPendingIntent = PendingIntent.getService(
                    this,
                    0,
                    stopIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )

                val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle("Screen Mirroring Active")
                    .setContentText("Casting screen over Hotspot P2P")
                    .setSmallIcon(android.R.drawable.ic_menu_camera)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setOngoing(true)
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Casting", stopPendingIntent)
                    .build()

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                    isServiceForegroundStarted = true
                    android.util.Log.i("MediaProjectionService", "Foreground service started with MEDIA_PROJECTION type")
                    onServiceStartedListener?.invoke()
                } catch (e: Exception) {
                    android.util.Log.e("MediaProjectionService", "Error in startForeground: ${e.message}")
                    try {
                        startForeground(NOTIFICATION_ID, notification)
                    } catch (_: Exception) {}
                    isServiceForegroundStarted = true
                    onServiceStartedListener?.invoke()
                }
            }
            ACTION_STOP -> {
                isServiceForegroundStarted = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                onStopListener?.invoke()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isServiceForegroundStarted = false
        onStopListener?.invoke()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Mirroring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground service notification for active screen mirroring"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
