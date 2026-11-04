import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart' show PlatformException;
import 'package:mirasol_light/mirasol_light.dart';

enum MeasureError { noSensor, noPermission, unstable, failed, cancelled }

/// Medición de luz ya promediada.
class LuxMeasurement {
  const LuxMeasurement({
    required this.lux,
    required this.saturated,
    required this.samples,
  });

  final double lux;

  /// El sensor llegó a su tope: la luz real es mayor o igual.
  final bool saturated;
  final int samples;
}

class MeasureOutcome {
  const MeasureOutcome.ok(LuxMeasurement this.value) : error = null;
  const MeasureOutcome.failed(MeasureError this.error) : value = null;

  final LuxMeasurement? value;
  final MeasureError? error;
}

/// Resume las lecturas continuas del sensor de luz de Android.
LuxMeasurement? summarizeSensorSamples(List<double> samples, double maxRange) {
  if (samples.isEmpty) return null;
  final mean = samples.reduce((a, b) => a + b) / samples.length;
  final atCeiling = maxRange > 0
      ? samples.where((v) => v >= maxRange * 0.98).length / samples.length
      : 0.0;
  return LuxMeasurement(lux: mean, saturated: atCeiling > 0.5, samples: samples.length);
}

/// La lectura cambió demasiado durante la medición (teléfono en movimiento
/// o luz que parpadea).
bool isUnstable(List<double> samples) {
  if (samples.length < 3) return false;
  final mean = samples.reduce((a, b) => a + b) / samples.length;
  if (mean < 5) return false;
  final variance =
      samples.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / samples.length;
  return math.sqrt(variance) / mean > 0.4;
}

/// Una medición de luz: promedia durante [seconds] segundos.
/// En Android usa el sensor de luz; en iPhone, la cámara.
class MeasureSession {
  MeasureSession({
    this.seconds = 5,
    this.cameraCalibration = 1,
    this.onProgress,
  });

  final double seconds;
  final double cameraCalibration;
  final void Function(double progress)? onProgress;

  bool _cancelled = false;
  StreamSubscription<double>? _sub;
  Timer? _timer;

  void cancel() {
    _cancelled = true;
    _sub?.cancel();
    _timer?.cancel();
  }

  Future<MeasureOutcome> run() {
    return Platform.isIOS ? _runIos() : _runAndroid();
  }

  void _startProgress(double totalSeconds, Completer<void>? done) {
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final p = DateTime.now().difference(start).inMilliseconds / (totalSeconds * 1000);
      onProgress?.call(p.clamp(0.0, 1.0));
      if (p >= 1) {
        t.cancel();
        if (done != null && !done.isCompleted) done.complete();
      }
    });
  }

  Future<MeasureOutcome> _runAndroid() async {
    final info = await MirasolLight.sensorInfo();
    if (!info.available) return const MeasureOutcome.failed(MeasureError.noSensor);

    final samples = <double>[];
    final done = Completer<void>();
    _sub = MirasolLight.luxStream().listen(
      samples.add,
      onError: (Object _) {
        if (!done.isCompleted) done.complete();
      },
    );
    _startProgress(seconds, done);
    await done.future;
    _timer?.cancel();
    await _sub?.cancel();

    if (_cancelled) return const MeasureOutcome.failed(MeasureError.cancelled);
    final summary = summarizeSensorSamples(samples, info.maxRange);
    if (summary == null) return const MeasureOutcome.failed(MeasureError.failed);
    if (!summary.saturated && isUnstable(samples)) {
      return const MeasureOutcome.failed(MeasureError.unstable);
    }
    return MeasureOutcome.ok(summary);
  }

  Future<MeasureOutcome> _runIos() async {
    if (!await MirasolLight.requestCameraAccess()) {
      return const MeasureOutcome.failed(MeasureError.noPermission);
    }
    // La cámara usa un segundo extra para acomodar la exposición.
    _startProgress(seconds + 1, null);
    try {
      final result = await MirasolLight.measureWithCamera(seconds: seconds);
      _timer?.cancel();
      if (_cancelled) return const MeasureOutcome.failed(MeasureError.cancelled);
      if (result == null) return const MeasureOutcome.failed(MeasureError.failed);
      return MeasureOutcome.ok(LuxMeasurement(
        lux: result.lux * cameraCalibration,
        saturated: result.saturated,
        samples: result.samples,
      ));
    } on PlatformException catch (e) {
      _timer?.cancel();
      if (e.code == 'NO_PERMISSION') {
        return const MeasureOutcome.failed(MeasureError.noPermission);
      }
      return const MeasureOutcome.failed(MeasureError.failed);
    }
  }
}
