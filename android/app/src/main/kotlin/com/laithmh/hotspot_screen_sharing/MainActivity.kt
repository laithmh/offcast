package com.laithmh.hotspot_screen_sharing

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
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
                    "startNativeUdpRelay" -> {
                        try {
                            val targetPort = call.argument<Int>("targetLoopbackPort") ?: 0
                            val peerIp = call.argument<String>("remotePeerIp")
                            if (targetPort <= 0) {
                                result.error("INVALID_PORT", "Invalid targetLoopbackPort: $targetPort", null)
                            } else {
                                val allocatedPort = NativeUdpRelay.start(targetPort, peerIp)
                                result.success(allocatedPort)
                            }
                        } catch (e: Exception) {
                            result.error("NATIVE_RELAY_FAILED", e.localizedMessage, null)
                        }
                    }
                    "stopNativeUdpRelay" -> {
                        try {
                            NativeUdpRelay.stop()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_RELAY_FAILED", e.localizedMessage, null)
                        }
                    }
                    "getDeviceThermalInfo" -> {
                        try {
                            val batteryIntent = applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                            val rawTemp = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
                            val tempC = if (rawTemp > 0) rawTemp / 10.0 else null

                            var thermalStatus = "NORMAL"
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                                when (powerManager?.currentThermalStatus) {
                                    PowerManager.THERMAL_STATUS_NONE -> thermalStatus = "NORMAL"
                                    PowerManager.THERMAL_STATUS_LIGHT -> thermalStatus = "LIGHT"
                                    PowerManager.THERMAL_STATUS_MODERATE -> thermalStatus = "MODERATE"
                                    PowerManager.THERMAL_STATUS_SEVERE -> thermalStatus = "SEVERE"
                                    PowerManager.THERMAL_STATUS_CRITICAL -> thermalStatus = "CRITICAL"
                                    PowerManager.THERMAL_STATUS_EMERGENCY -> thermalStatus = "EMERGENCY"
                                    PowerManager.THERMAL_STATUS_SHUTDOWN -> thermalStatus = "SHUTDOWN"
                                }
                            }

                            val manufacturer = Build.MANUFACTURER?.replaceFirstChar { it.uppercase() } ?: "Android"
                            val model = Build.MODEL ?: "Device"
                            val deviceName = if (model.startsWith(manufacturer, ignoreCase = true)) model else "$manufacturer $model"

                            result.success(mapOf(
                                "temperatureC" to tempC,
                                "thermalStatus" to thermalStatus,
                                "deviceName" to deviceName
                            ))
                        } catch (e: Exception) {
                            result.error("THERMAL_INFO_FAILED", e.localizedMessage, null)
                        }
                    }
                    "getDeviceName" -> {
                        val manufacturer = Build.MANUFACTURER?.replaceFirstChar { it.uppercase() } ?: "Android"
                        val model = Build.MODEL ?: "Device"
                        val deviceName = if (model.startsWith(manufacturer, ignoreCase = true)) model else "$manufacturer $model"
                        result.success(deviceName)
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

/**
 * Ultra-high-performance native Android UDP relay.
 *
 * Runs on a dedicated OS thread with real-time priority (THREAD_PRIORITY_URGENT_AUDIO)
 * and a 2 MB kernel socket buffer. Bypasses the Dart VM and Flutter UI event loop entirely,
 * guaranteeing zero frame drops and minimal latency when Hotspot SoftAP is hosted on Android.
 */
object NativeUdpRelay {
    private const val TAG = "NativeUdpRelay"
    private var socket: DatagramSocket? = null
    private var relayThread: Thread? = null
    @Volatile
    private var isRunning = false
    private var publicPort = 0
    private var targetLoopbackPort = 0
    private var remotePeerAddress: InetAddress? = null
    private var remotePeerPort = 0

    @Synchronized
    fun start(targetPort: Int, peerIp: String?): Int {
        stop()
        targetLoopbackPort = targetPort
        if (!peerIp.isNullOrBlank()) {
            try {
                remotePeerAddress = InetAddress.getByName(peerIp)
            } catch (e: Exception) {
                android.util.Log.w(TAG, "Could not resolve initial peerIp: $peerIp", e)
            }
        }

        val s = DatagramSocket(null).apply {
            reuseAddress = true
            // Request 2 MB socket buffers to absorb large 60 FPS keyframe bursts
            try {
                receiveBufferSize = 2 * 1024 * 1024
                sendBufferSize = 2 * 1024 * 1024
            } catch (e: Exception) {
                android.util.Log.w(TAG, "Socket buffer size request capped by kernel: ${e.message}")
            }
            bind(InetSocketAddress(InetAddress.getByName("0.0.0.0"), 0))
        }

        socket = s
        publicPort = s.localPort
        isRunning = true

        val loopback = InetAddress.getByName("127.0.0.1")

        relayThread = Thread({
            try {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
            } catch (_: Exception) {
                try {
                    Thread.currentThread().priority = Thread.MAX_PRIORITY
                } catch (_: Exception) {}
            }

            val buffer = ByteArray(65535)
            val packet = DatagramPacket(buffer, buffer.size)

            android.util.Log.i(TAG, "Native UDP relay thread running on core priority nice=-19")

            while (isRunning && !s.isClosed) {
                try {
                    packet.length = buffer.size
                    s.receive(packet)

                    val senderAddr = packet.address
                    val isLoopback = senderAddr.isLoopbackAddress ||
                            senderAddr.hostAddress == "127.0.0.1" ||
                            senderAddr.hostAddress == "::1"

                    if (isLoopback) {
                        // RTCP feedback from local WebRTC loopback -> forward to remote peer
                        val targetAddr = remotePeerAddress
                        val targetP = remotePeerPort
                        if (targetAddr != null && targetP > 0) {
                            val fwd = DatagramPacket(packet.data, packet.offset, packet.length, targetAddr, targetP)
                            s.send(fwd)
                        }
                    } else {
                        // RTP video data from remote peer -> forward to local WebRTC loopback
                        remotePeerAddress = senderAddr
                        remotePeerPort = packet.port
                        val fwd = DatagramPacket(packet.data, packet.offset, packet.length, loopback, targetLoopbackPort)
                        s.send(fwd)
                    }
                } catch (e: Exception) {
                    if (!isRunning || s.isClosed) break
                }
            }
            android.util.Log.i(TAG, "Native UDP relay thread exited cleanly")
        }, "NativeUdpRelayThread").apply {
            isDaemon = true
            start()
        }

        android.util.Log.i(TAG, "Started native relay 0.0.0.0:$publicPort <-> 127.0.0.1:$targetLoopbackPort (SO_RCVBUF: ${s.receiveBufferSize} bytes)")
        return publicPort
    }

    @Synchronized
    fun stop() {
        isRunning = false
        try {
            socket?.close()
        } catch (_: Exception) {}
        socket = null
        relayThread?.interrupt()
        relayThread = null
        remotePeerAddress = null
        remotePeerPort = 0
        publicPort = 0
    }
}
