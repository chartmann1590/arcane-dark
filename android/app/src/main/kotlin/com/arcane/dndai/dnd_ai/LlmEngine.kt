package com.arcane.dndai.dnd_ai

import android.app.ActivityManager
import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Thin wrapper around Google's LiteRT-LM Kotlin API (com.google.ai.edge.litertlm),
 * the current (2026) recommended on-device runtime for Gemma 4.
 * https://developers.google.com/edge/litert-lm/android
 *
 * Engine/Conversation lifecycle:
 *  - loadModel(path) creates the Engine + a single long-lived Conversation.
 *  - generate(prompt) streams a fresh reply through that Conversation (so context/history
 *    is retained by the engine itself, in addition to the prompt text DmTurnEngine already
 *    assembles on the Dart side).
 *  - unload() releases both.
 *
 * NOTE: exact class/method availability is based on Google's published docs as of this
 * integration (2026-08); if litertlm-android ships a slightly different surface, the
 * compile error will point at the exact line to adjust here — this file is the only
 * place that talks to the SDK.
 */
class LlmEngine(private val appContext: Context) {
    private var engine: Engine? = null
    private var conversation: com.google.ai.edge.litertlm.Conversation? = null
    private val scope = CoroutineScope(Dispatchers.Main + Job())

    val isLoaded: Boolean
        get() = engine != null && conversation != null

    suspend fun loadModel(modelPath: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val config = EngineConfig(
                modelPath = modelPath,
                backend = Backend.CPU() // generic .litertlm build is CPU-backend; GPU delegate is opt-in per device
            )
            val eng = Engine(config)
            eng.initialize() // can take up to ~10s on first load — always call off the main thread
            val convo = eng.createConversation(
                ConversationConfig(
                    systemInstruction = Contents.of(
                        "You are an expert tabletop Dungeon Master narrating a Dungeons & Dragons style " +
                            "adventure. Narrate in-character, in second person, and never break the fourth wall. " +
                            "When the player's action requires a dice roll, HP change, item change, movement, or " +
                            "quest update, emit exactly one line of the form " +
                            "<<ACTION: name key=val key2=val2>> using only these actions: " +
                            "roll_dice(sides,count,modifier), update_hp(target,delta), add_item(target,item), " +
                            "move_party(x,y), trigger_encounter(id), advance_quest(id,stage). " +
                            "Otherwise just narrate — do not invent actions outside this list."
                    ),
                    samplerConfig = SamplerConfig(topK = 20, topP = 0.9, temperature = 0.85)
                )
            )
            engine = eng
            conversation = convo
            true
        } catch (e: Exception) {
            engine = null
            conversation = null
            throw e
        }
    }

    fun generateStream(
        prompt: String,
        onToken: (String) -> Unit,
        onDone: () -> Unit,
        onError: (String) -> Unit
    ) {
        val convo = conversation
        if (convo == null) {
            onError("MODEL_NOT_LOADED")
            return
        }
        scope.launch {
            try {
                convo.sendMessageAsync(prompt)
                    .flowOn(Dispatchers.IO)
                    .catch { e -> onError(e.message ?: "GENERATION_ERROR") }
                    .collect { chunk -> onToken(chunk.toString()) }
                onDone()
            } catch (e: Exception) {
                onError(e.message ?: "GENERATION_ERROR")
            }
        }
    }

    suspend fun unload() = withContext(Dispatchers.IO) {
        try {
            engine?.close()
        } catch (_: Exception) {
        } finally {
            conversation = null
            engine = null
        }
    }

    /** Total device RAM in MB, used by the Dart side to pick the E2B vs E4B tier. */
    fun deviceRamMb(): Long {
        val am = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return info.totalMem / (1024 * 1024)
    }
}
