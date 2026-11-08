import 'dart:async';

import 'package:flutter/services.dart';

/// Datos del sensor de luz del teléfono (solo Android).
class LightSensorInfo {
  const LightSensorInfo({required this.available, required this.maxRange});

  final bool available;

  /// Máximo que puede medir el sensor, en lux. Con sol directo muchos
  /// teléfonos llegan a este tope y dejan de medir con precisión.
  final double maxRange;
}

/// Resultado de estimar la luz con la cámara (solo iPhone).
class CameraLuxResult {
  const CameraLuxResult({
    required this.lux,
    required this.samples,
    required this.saturated,
  });

  final double lux;
  final int samples;

  /// La cámara llegó a su exposición mínima: la luz real es mayor o igual.
  final bool saturated;
}

/// Acceso a la luz del teléfono. Android usa el sensor de luz ambiente;
/// iPhone estima la luz con los parámetros de exposición de la cámara.
class MirasolLight {
  MirasolLight._();

  static const MethodChannel _method = MethodChannel('mirasol_light/method');
  static const EventChannel _lux = EventChannel('mirasol_light/lux');

  static Future<LightSensorInfo> sensorInfo() async {
    try {
      final result =
          await _method.invokeMapMethod<String, dynamic>('sensorInfo');
      if (result == null) {
        return const LightSensorInfo(available: false, maxRange: 0);
      }
      return LightSensorInfo(
        available: result['available'] == true,
        maxRange: (result['maxRange'] as num?)?.toDouble() ?? 0,
      );
    } on MissingPluginException {
      return const LightSensorInfo(available: false, maxRange: 0);
    }
  }

  /// Lecturas continuas del sensor de luz, en lux (solo Android).
  static Stream<double> luxStream() {
    return _lux.receiveBroadcastStream().map((e) => (e as num).toDouble());
  }

  /// Pide el permiso de la cámara (solo iPhone). Devuelve true si se concedió.
  static Future<bool> requestCameraAccess() async {
    try {
      return await _method.invokeMethod<bool>('requestCameraAccess') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Corta la medición en curso y apaga el sensor o la cámara.
  static Future<void> cancelMeasure() async {
    try {
      await _method.invokeMethod<void>('cancelMeasure');
    } on MissingPluginException {
      // Sin plugin no hay nada que cortar.
    }
  }

  /// Estima la luz con la cámara durante [seconds] segundos (solo iPhone).
  /// Lanza [PlatformException] si falta el permiso o la cámara no responde.
  static Future<CameraLuxResult?> measureWithCamera({
    double seconds = 5,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'measureWithCamera',
        {'seconds': seconds},
      );
      if (result == null) return null;
      return CameraLuxResult(
        lux: (result['lux'] as num).toDouble(),
        samples: (result['samples'] as num?)?.toInt() ?? 0,
        saturated: result['saturated'] == true,
      );
    } on MissingPluginException {
      return null;
    }
  }
}
