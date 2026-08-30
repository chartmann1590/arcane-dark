import 'dart:async';

Future<T> traced<T>(String name, Future<T> Function() op) async {
  final sw = Stopwatch()..start();
  try {
    return await op();
  } finally {
    sw.stop();
    // In production this starts/stops a Firebase Performance trace
    // For now just log the timing
    // print('[Perf] $name ${sw.elapsedMilliseconds}ms');
  }
}
