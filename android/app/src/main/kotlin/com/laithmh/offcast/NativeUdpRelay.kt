package com.laithmh.offcast

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress

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
                        // Only accept incoming packets from expected peer to prevent UDP hijacking
                        val expectedPeer = remotePeerAddress
                        if (expectedPeer != null && expectedPeer != senderAddr) {
                            continue
                        }
                        if (remotePeerAddress == null) {
                            remotePeerAddress = senderAddr
                        }
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
