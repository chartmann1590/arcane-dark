import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ModelManifest {
  final String url;
  final String sha256;
  final int sizeBytes;
  final String version;
  final String filename;
  ModelManifest({required this.url, required this.sha256, required this.sizeBytes, required this.version, required this.filename});
  factory ModelManifest.fromJson(Map<String, dynamic> j) => ModelManifest(
        url: j['url'],
        sha256: j['sha256'],
        sizeBytes: j['sizeBytes'],
        version: j['version'],
        filename: j['filename'],
      );

  static Future<ModelManifest> load() async {
    final raw = await rootBundle.loadString('assets/model_manifest.json');
    return ModelManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class ModelDownloadException implements Exception {
  final String message;
  ModelDownloadException(this.message);
  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Real, resumable, checksum-verified download of the Gemma 4 .litertlm model file
/// (see assets/model_manifest.json). Downloads to a .part file so an interrupted
/// download resumes via HTTP Range instead of restarting from zero.
class ModelDownloadManager {
  Future<File> _modelFile() async {
    final manifest = await ModelManifest.load();
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);
    return File('${modelsDir.path}/${manifest.filename}');
  }

  Future<bool> isModelPresent() async {
    try {
      final manifest = await ModelManifest.load();
      final f = await _modelFile();
      if (!f.existsSync()) return false;
      // Cheap presence check: exact final size match (full checksum is verified once, at download time).
      return f.lengthSync() == manifest.sizeBytes;
    } catch (_) {
      return false;
    }
  }

  Future<String> modelFilePath() async => (await _modelFile()).path;

  /// Streams download progress 0.0..1.0. Throws [ModelDownloadException] on
  /// network failure or checksum mismatch (the partial/corrupt file is deleted
  /// on checksum failure so a retry starts clean).
  Stream<double> downloadWithProgress() async* {
    if (await isModelPresent()) {
      yield 1.0;
      return;
    }
    final manifest = await ModelManifest.load();
    final target = await _modelFile();
    final partFile = File('${target.path}.part');

    final dio = Dio();
    final controller = StreamController<double>();
    var startBytes = 0;
    if (partFile.existsSync()) {
      startBytes = partFile.lengthSync();
    }

    final options = Options(
      headers: startBytes > 0 ? {'Range': 'bytes=$startBytes-'} : null,
      responseType: ResponseType.stream,
      followRedirects: true,
    );

    unawaited(() async {
      IOSink? sink;
      try {
        final response = await dio.get<ResponseBody>(manifest.url, options: options);
        final total = manifest.sizeBytes;
        var received = startBytes;
        sink = partFile.openWrite(mode: startBytes > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly);
        var lastReported = startBytes;
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (received - lastReported >= 2 * 1024 * 1024 || received == total) {
            lastReported = received;
            controller.add((received / total).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;

        // Verify checksum before promoting .part -> final filename.
        final digest = await sha256.bind(partFile.openRead()).first;
        final actualHash = digest.toString();
        if (actualHash.toLowerCase() != manifest.sha256.toLowerCase()) {
          await partFile.delete();
          controller.addError(ModelDownloadException(
              'Checksum mismatch after download (expected ${manifest.sha256}, got $actualHash) — corrupt or tampered download, deleted. Please retry.'));
          await controller.close();
          return;
        }
        await partFile.rename(target.path);
        controller.add(1.0);
        await controller.close();
      } catch (e) {
        await sink?.close();
        controller.addError(e is ModelDownloadException ? e : ModelDownloadException(e.toString()));
        await controller.close();
      }
    }());

    yield* controller.stream;
  }

  Future<void> deleteModel() async {
    final target = await _modelFile();
    if (target.existsSync()) await target.delete();
    final part = File('${target.path}.part');
    if (part.existsSync()) await part.delete();
  }
}
