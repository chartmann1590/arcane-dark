package com.arcane.dndai.dnd_ai

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

private const val CONTROL_CHANNEL = "dnd_ai/llm_control"
private const val STREAM_CHANNEL = "dnd_ai/llm_stream"
private const val CAST_CHANNEL = "dnd_ai/system_cast"

class MainActivity : FlutterActivity() {
    private lateinit var llmEngine: LlmEngine
    private val mainScope = CoroutineScope(Dispatchers.Main + Job())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        llmEngine = LlmEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }
                    mainScope.launch {
                        try {
                            val ok = llmEngine.loadModel(path)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("MODEL_LOAD_ERROR", e.message ?: e.toString(), null)
                        }
                    }
                }
                "cancelGeneration" -> {
                    llmEngine.cancelCurrentGeneration()
                    result.success(true)
                }
                "unloadModel" -> {
                    mainScope.launch {
                        llmEngine.unload()
                        result.success(true)
                    }
                }
                "isLoaded" -> result.success(llmEngine.isLoaded)
                "getDeviceRamTier" -> {
                    try {
                        result.success(llmEngine.deviceRamMb())
                    } catch (e: Exception) {
                        result.error("RAM_QUERY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAST_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCastSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_CAST_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent("android.settings.WIFI_DISPLAY_SETTINGS").apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("CAST_ERROR", e2.message ?: "Cast settings unavailable", null)
                        }
                    }
                }
                "openMiracastSettings" -> {
                    try {
                        val intent = Intent("android.settings.WIFI_DISPLAY_SETTINGS").apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_CAST_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("MIRACAST_ERROR", e2.message ?: "Miracast settings unavailable", null)
                        }
                    }
                }
                "openChrome" -> {
                    val url = call.argument<String>("url") ?: "http://google.com"
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            setPackage("com.android.chrome")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("BROWSER_ERROR", e2.message ?: "Failed to open browser", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val argsMap = arguments as? Map<*, *>
                    val prompt = argsMap?.get("prompt") as? String
                    val maxTokens = (argsMap?.get("maxTokens") as? Number)?.toInt() ?: 160
                    if (prompt == null) {
                        events.error("BAD_ARGS", "prompt is required", null)
                        return
                    }
                    llmEngine.generateStream(
                        prompt = prompt,
                        maxTokens = maxTokens,
                        onToken = { chunk -> runOnUiThread { events.success(chunk) } },
                        onDone = { runOnUiThread { events.endOfStream() } },
                        onError = { message -> runOnUiThread { events.error("GENERATION_ERROR", message, null) } }
                    )
                }

                override fun onCancel(arguments: Any?) {
                    llmEngine.cancelCurrentGeneration()
                }
            }
        )
    }
}
