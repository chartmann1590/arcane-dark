package com.arcane.dndai.dnd_ai

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val argsMap = arguments as? Map<*, *>
                    val prompt = argsMap?.get("prompt") as? String
                    if (prompt == null) {
                        events.error("BAD_ARGS", "prompt is required", null)
                        return
                    }
                    llmEngine.generateStream(
                        prompt = prompt,
                        onToken = { chunk -> runOnUiThread { events.success(chunk) } },
                        onDone = { runOnUiThread { events.endOfStream() } },
                        onError = { message -> runOnUiThread { events.error("GENERATION_ERROR", message, null) } }
                    )
                }

                override fun onCancel(arguments: Any?) {
                    // Generation for this turn either already completed or the Dart side
                    // stopped listening (e.g. screen disposed) — nothing to clean up here,
                    // the underlying Conversation stays loaded for the next turn.
                }
            }
        )
    }
}
