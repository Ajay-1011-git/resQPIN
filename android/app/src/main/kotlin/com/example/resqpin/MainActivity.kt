package com.example.resqpin

import android.media.MediaRecorder
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.resqpin/panic"
    private var methodChannel: MethodChannel? = null

    // Track volume-down presses for triple-press detection
    private val pressTimes = mutableListOf<Long>()
    private val TRIPLE_PRESS_WINDOW_MS = 1500L // 1.5 seconds window for 3 presses

    // Audio recording
    private var mediaRecorder: MediaRecorder? = null
    private var currentRecordingPath: String? = null
    private var isRecording = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    try {
                        val path = startRecording()
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("RECORDING_ERROR", e.message, null)
                    }
                }
                "stopRecording" -> {
                    try {
                        val path = stopRecording()
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("RECORDING_ERROR", e.message, null)
                    }
                }
                "isRecording" -> {
                    result.success(isRecording)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val now = System.currentTimeMillis()
            // Remove presses older than the detection window
            pressTimes.removeAll { now - it > TRIPLE_PRESS_WINDOW_MS }
            pressTimes.add(now)

            if (pressTimes.size >= 3) {
                pressTimes.clear()
                // Triple-press detected — notify Flutter
                methodChannel?.invokeMethod("triggerPanic", null)
            }
            return true // Consume the key event
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun startRecording(): String? {
        if (isRecording) return currentRecordingPath

        val timestamp = System.currentTimeMillis()
        val dir = applicationContext.filesDir
        currentRecordingPath = "${dir.absolutePath}/panic_recording_$timestamp.m4a"

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(applicationContext)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        mediaRecorder?.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioEncodingBitRate(128000)
            setOutputFile(currentRecordingPath)
            prepare()
            start()
        }

        isRecording = true
        return currentRecordingPath
    }

    private fun stopRecording(): String? {
        if (!isRecording) return null

        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        mediaRecorder?.release()
        mediaRecorder = null
        isRecording = false

        return currentRecordingPath
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }
}
