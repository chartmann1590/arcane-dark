import 'package:flutter/foundation.dart';

class CrashReporting {
  static void log(String message) {
    if (kDebugMode) print('[CrashReporting] $message');
  }

  static void recordError(Object e, StackTrace? st, {String? reason, bool fatal = false}) {
    if (kDebugMode) print('[CrashReporting] ${fatal ? "FATAL" : "non-fatal"} $reason: $e');
    // Real implementation will call FirebaseCrashlytics.instance.recordError
  }

  static void setCustomKey(String key, String value) {
    if (kDebugMode) print('[CrashReporting] setKey $key=$value');
  }
}
