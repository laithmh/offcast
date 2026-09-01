package com.laithmh.hotspot_screen_sharing

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var methodChannel: MethodChannel? = null
    private val channelName = "com.laithmh.hotspot_screen_sharing/foreground_service"

    companion object {
        var instance: MainActivity? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("HotspotDiscoveryMulticastLock")?.apply {
                setReferenceCounted(true)
                acquire()
            }
            wifiLock = wifiManager?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "HotspotHighPerfWifiLock")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        try {
                            val intent = Intent(this@MainActivity, MediaProjectionService::class.java).apply {
                                action = MediaProjectionService.ACTION_START
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.localizedMessage, null)
                        }
                    }
                    "stopService" -> {
                        try {
                            val intent = Intent(this@MainActivity, MediaProjectionService::class.java).apply {
                                action = MediaProjectionService.ACTION_STOP
                            }
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_FAILED", e.localizedMessage, null)
                        }
                    }
                    "setKeepScreenOn" -> {
                        try {
                            val keepOn = call.argument<Boolean>("keepOn") ?: false
                            activity?.runOnUiThread {
                                if (keepOn) {
                                    activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                                } else {
                                    activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("KEEP_SCREEN_ON_FAILED", e.localizedMessage, null)
                        }
                    }
                    "bindToWifiNetwork" -> {
                        try {
                            bindProcessToWifiNetwork()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BIND_WIFI_FAILED", e.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MediaProjectionService.onStopListener = {
            activity?.runOnUiThread {
                methodChannel?.invokeMethod("onScreenShareStopped", null)
            }
        }
    }

    private var networkCallback: android.net.ConnectivityManager.NetworkCallback? = null

    private fun bindProcessToWifiNetwork() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager ?: return

                // 1. Unregister previous callback if any
                networkCallback?.let {
                    try { connectivityManager.unregisterNetworkCallback(it) } catch (_: Exception) {}
                }

                // 2. Build request for all Wi-Fi networks even without internet uplink
                val request = android.net.NetworkRequest.Builder()
                    .addTransportType(android.net.NetworkCapabilities.TRANSPORT_WIFI)
                    .removeCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()

                networkCallback = object : android.net.ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: android.net.Network) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                connectivityManager.bindProcessToNetwork(network)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }

                    override fun onLost(network: android.net.Network) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                connectivityManager.bindProcessToNetwork(null)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                connectivityManager.registerNetworkCallback(request, networkCallback!!)

                // 3. Immediately inspect all current networks
                var bound = false
                val networks = connectivityManager.allNetworks
                for (network in networks) {
                    val caps = connectivityManager.getNetworkCapabilities(network) ?: continue
                    if (caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                        connectivityManager.bindProcessToNetwork(network)
                        bound = true
                        break
                    }
                }
                if (!bound) {
                    connectivityManager.bindProcessToNetwork(null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        instance = null
        MediaProjectionService.onStopListener = null
        try {
            networkCallback?.let {
                val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
                connectivityManager?.unregisterNetworkCallback(it)
            }
        } catch (_: Exception) {}
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}

class MediaProjectionService : Service() {
    companion object {
        const val CHANNEL_ID = "hotspot_media_projection_channel"
        const val NOTIFICATION_ID = 9001
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        var onStopListener: (() -> Unit)? = null
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

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val fgsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                    } else {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                    }
                    startForeground(NOTIFICATION_ID, notification, fgsType)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
            ACTION_STOP -> {
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
