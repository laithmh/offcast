package com.laithmh.offcast

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var methodChannel: MethodChannel? = null
    private val channelName = "com.laithmh.offcast/foreground_service"
    private var vadEventChannel: EventChannel? = null
    private val vadChannelName = "com.laithmh.offcast/audio_vad"

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
            val wifiMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wifiManager?.createWifiLock(wifiMode, "HotspotHighPerfWifiLock")?.apply {
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
                            runOnUiThread {
                                if (keepOn) {
                                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                                } else {
                                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
                    "setVadThreshold" -> {
                        val threshold = call.argument<Double>("threshold") ?: -42.0
                        AudioVadEngine.thresholdDb = threshold
                        result.success(true)
                    }
                    "isVadSupported" -> {
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        vadEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, vadChannelName).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AudioVadEngine.start(applicationContext, events)
                }

                override fun onCancel(arguments: Any?) {
                    AudioVadEngine.stop()
                }
            })
        }

        MediaProjectionService.onStopListener = {
            runOnUiThread {
                methodChannel?.invokeMethod("onScreenShareStopped", null)
            }
        }
    }

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private fun bindProcessToWifiNetwork() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return

                networkCallback?.let {
                    try { connectivityManager.unregisterNetworkCallback(it) } catch (_: Exception) {}
                }

                val request = android.net.NetworkRequest.Builder()
                    .addTransportType(android.net.NetworkCapabilities.TRANSPORT_WIFI)
                    .removeCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()

                networkCallback = object : ConnectivityManager.NetworkCallback() {
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

                connectivityManager.requestNetwork(request, networkCallback!!)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (resultCode == android.app.Activity.RESULT_OK && data != null) {
            try {
                val serviceIntent = Intent(this, MediaProjectionService::class.java).apply {
                    action = MediaProjectionService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to start MediaProjectionService in onActivityResult: ${e.message}")
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        instance = null
        MediaProjectionService.onStopListener = null
        try {
            networkCallback?.let {
                val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
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
        try {
            AudioVadEngine.stop()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
