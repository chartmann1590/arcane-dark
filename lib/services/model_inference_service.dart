import 'dart:async';
import 'package:flutter/services.dart';
import 'model_download_manager.dart';

/// Abstraction matching plan Phase 02 — ModelInferenceService.
abstract class ModelInferenceService {
  Future<void> ensureModelReady();
  Stream<String> generate(String prompt, {int maxTokens = 160});
  Future<void> unload();
  String get deviceTier; // E2B / E4B
}

class ModelLoadException implements Exception {
  final String code;
  final String message;
  ModelLoadException(this.code, this.message);
  @override
  String toString() => 'ModelLoadException($code): $message';
}

/// Real on-device Gemma 4 inference via Google's LiteRT-LM Kotlin API,
/// reached through a platform channel to android/.../LlmEngine.kt.
/// See plan/02-on-device-ai-runtime.md.
class LiteRtModelInferenceService implements ModelInferenceService {
  static const _control = MethodChannel('dnd_ai/llm_control');
  static const _stream = EventChannel('dnd_ai/llm_stream');

  bool _ready = false;
  String _tier = 'E2B';

  @override
  String get deviceTier => _tier;

  @override
  Future<void> ensureModelReady() async {
    if (_ready) return;
    try {
      final ramMb = await _control.invokeMethod<int>('getDeviceRamTier') ?? 0;
      _tier = ramMb >= 6000 ? 'E4B' : 'E2B';
    } on PlatformException {
      _tier = 'E2B';
    }
    final downloadManager = ModelDownloadManager();
    if (!await downloadManager.isModelPresent()) {
      throw ModelLoadException('MODEL_NOT_DOWNLOADED', 'Gemma 4 model file is not on disk yet — download it from Settings or Onboarding first.');
    }
    final path = await downloadManager.modelFilePath();
    try {
      final ok = await _control.invokeMethod<bool>('loadModel', {'path': path});
      _ready = ok ?? false;
      if (!_ready) throw ModelLoadException('LOAD_FAILED', 'Engine returned false for loadModel');
    } on PlatformException catch (e) {
      throw ModelLoadException(e.code, e.message ?? 'Unknown platform error loading model');
    }
  }

  @override
  Stream<String> generate(String prompt, {int maxTokens = 160}) async* {
    if (!_ready) await ensureModelReady();
    final controller = StreamController<String>();
    late final StreamSubscription sub;
    Timer? heartbeatTimer;
    bool hasReceivedFirstToken = false;

    void resetHeartbeat(Duration duration) {
      heartbeatTimer?.cancel();
      heartbeatTimer = Timer(duration, () {
        sub.cancel();
        _control.invokeMethod('cancelGeneration').catchError((_) => null);
        controller.addError(ModelLoadException('TIMEOUT', 'Inference timed out after ${duration.inSeconds}s of inactivity'));
        controller.close();
      });
    }

    // Initial prefill allowance (up to 75 seconds for slow mobile CPU prefill)
    resetHeartbeat(const Duration(seconds: 75));

    sub = _stream.receiveBroadcastStream({'prompt': prompt, 'maxTokens': maxTokens}).listen(
      (event) {
        if (!hasReceivedFirstToken) {
          hasReceivedFirstToken = true;
        }
        // Per-token heartbeat: reset to 25 seconds for each generated token
        resetHeartbeat(const Duration(seconds: 25));
        controller.add(event as String);
      },
      onError: (Object e) {
        heartbeatTimer?.cancel();
        if (e is PlatformException) {
          controller.addError(ModelLoadException(e.code, e.message ?? 'generation error'));
        } else {
          controller.addError(e);
        }
        controller.close();
      },
      onDone: () {
        heartbeatTimer?.cancel();
        controller.close();
      },
      cancelOnError: true,
    );

    controller.onCancel = () {
      heartbeatTimer?.cancel();
      sub.cancel();
      _control.invokeMethod('cancelGeneration').catchError((_) => null);
    };

    yield* controller.stream;
  }

  @override
  Future<void> unload() async {
    try {
      await _control.invokeMethod('unloadModel');
    } finally {
      _ready = false;
    }
  }
}

enum RamTier { e2b, e4b }
RamTier detectRamTier(int totalMemMb) => totalMemMb >= 6000 ? RamTier.e4b : RamTier.e2b;
