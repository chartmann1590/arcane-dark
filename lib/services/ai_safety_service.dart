import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'crash_reporting.dart';

enum AiReportCategory {
  offensive('offensive', 'Offensive / Inappropriate Content'),
  hateSpeech('hate_speech', 'Harassment / Hate Speech'),
  sexual('sexual', 'Sexually Explicit / NSFW'),
  violence('violence', 'Dangerous / Excessive Violence'),
  hallucination('hallucination', 'Severe Hallucination / Glitch'),
  other('other', 'Other Policy Concern');

  final String code;
  final String displayName;
  const AiReportCategory(this.code, this.displayName);
}

class AiSafetyService {
  AiSafetyService._();
  static final AiSafetyService instance = AiSafetyService._();

  static const String _reportEndpoint =
      'https://arcane-dark-reports.charles-h-hartmann1.workers.dev/api/reports';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Submits an AI-generated content safety report to the Cloudflare Worker.
  /// Returns true if accepted by the server.
  Future<bool> submitReport({
    required AiReportCategory category,
    required String aiMessage,
    String? details,
    String? context,
    String? campaignId,
    String? characterName,
    String? sessionId,
  }) async {
    try {
      String appVersion = '1.0.0';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final payload = {
        'category': category.code,
        'details': details?.trim() ?? '',
        'aiMessage': aiMessage.trim(),
        'context': context?.trim() ?? '',
        'campaignId': campaignId ?? '',
        'characterName': characterName ?? '',
        'sessionId': sessionId ?? '',
        'appVersion': appVersion,
        'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _dio.post(_reportEndpoint, data: payload);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        CrashReporting.log('AI report submitted successfully: ${category.code}');
        return true;
      } else {
        CrashReporting.log(
          'AI report submission returned HTTP ${response.statusCode}: ${response.data}',
        );
        return false;
      }
    } catch (e, stack) {
      CrashReporting.recordError(e, stack, reason: 'Failed to submit AI safety report');
      return false;
    }
  }
}
