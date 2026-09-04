package com.laithmh.hotspot_screen_sharing

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

object AudioVadEngine {
    private const val TAG = "AudioVadEngine"
    private const val SAMPLE_RATE = 16000
    private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private const val HANGOVER_MS = 750L // Keep speaking state active during natural pauses between words

    @Volatile
    var thresholdDb: Double = -50.0 // Studio room speech sensitivity

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var isRunning = false
    private var recordingThread: Thread? = null
    private var audioRecord: AudioRecord? = null
    private var eventSink: EventChannel.EventSink? = null

    @Synchronized
    fun start(context: Context, sink: EventChannel.EventSink?) {
        stop()
        eventSink = sink

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.w(TAG, "Audio recording permission not granted")
            return
        }

        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        val bufferSize = Math.max(minBufSize, 2048)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                android.util.Log.e(TAG, "AudioRecord initialization failed")
                audioRecord?.release()
                audioRecord = null
                return
            }

            audioRecord?.startRecording()
            isRunning = true

            recordingThread = Thread({
                val audioBuffer = ShortArray(1024)
                var lastSpokenTime = 0L
                var lastReportTime = 0L

                while (isRunning) {
                    try {
                        val record = audioRecord ?: break
                        if (!isRunning || record.state != AudioRecord.STATE_INITIALIZED) break
                        val readCount = record.read(audioBuffer, 0, audioBuffer.size)
                        if (!isRunning) break

                        if (readCount > 0) {
                            var sum = 0.0
                            for (i in 0 until readCount) {
                                val sample = audioBuffer[i].toDouble()
                                sum += sample * sample
                            }
                            val rms = Math.sqrt(sum / readCount)
                            val db = if (rms > 0.0) 20.0 * Math.log10(rms / 32767.0) else -100.0
                            val audioLevel = (rms / 32767.0).coerceIn(0.0, 1.0)
                            val now = System.currentTimeMillis()

                            val isSignalAboveThreshold = db >= thresholdDb
                            if (isSignalAboveThreshold) {
                                lastSpokenTime = now
                            }

                            val isSpeaking = (now - lastSpokenTime) < HANGOVER_MS

                            // Report ~25 times per second (every 40ms)
                            if (now - lastReportTime >= 40) {
                                lastReportTime = now
                                val payload = mapOf(
                                    "isSpeaking" to isSpeaking,
                                    "decibels" to db,
                                    "audioLevel" to audioLevel
                                )
                                mainHandler.post {
                                    try {
                                        eventSink?.success(payload)
                                    } catch (_: Exception) {}
                                }
                            }
                        }
                    } catch (e: Exception) {
                        if (!isRunning) break
                    }
                }
            }, "AudioVadThread").apply {
                priority = Thread.NORM_PRIORITY
                isDaemon = true
                start()
            }
            android.util.Log.i(TAG, "AudioVadEngine started successfully at 16kHz")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to start AudioVadEngine: ${e.localizedMessage}")
            stop()
        }
    }

    @Synchronized
    fun stop() {
        isRunning = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        recordingThread?.interrupt()
        recordingThread = null
        eventSink = null
    }
}
