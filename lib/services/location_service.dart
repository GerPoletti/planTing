import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Ubicación aproximada: las coordenadas se redondean a una décima de grado
/// (unos 10 km) antes de guardarse o de enviarse al servicio del clima.
class ApproxLocation {
  const ApproxLocation(this.latitude, this.longitude, {this.name});

  final double latitude;
  final double longitude;
  final String? name;
}

enum LocationFailure { servicesOff, denied, deniedForever, timeout }

class LocationResult {
  const LocationResult.ok(ApproxLocation this.location) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : location = null;

  final ApproxLocation? location;
  final LocationFailure? failure;
}

class LocationService {
  const LocationService._();

  static double round1(double v) => (v * 10).round() / 10;

  /// Pide el permiso si hace falta y devuelve la ubicación aproximada.
  static Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(LocationFailure.servicesOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failed(LocationFailure.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failed(LocationFailure.deniedForever);
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult.ok(
        ApproxLocation(round1(pos.latitude), round1(pos.longitude)),
      );
    } catch (_) {
      return const LocationResult.failed(LocationFailure.timeout);
    }
  }

  /// Busca una ciudad por nombre (servicio de geocodificación de Open-Meteo).
  /// Solo se envía el texto que escribió la persona.
  static Future<List<ApproxLocation>> searchPlace(String query, String lang) async {
    final text = query.trim();
    if (text.length < 2) return [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': text,
      'count': '5',
      'language': lang,
      'format': 'json',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      return results.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final parts = <String>[
          m['name'] as String? ?? '',
          if (m['admin1'] != null) m['admin1'] as String,
          if (m['country'] != null) m['country'] as String,
        ].where((s) => s.isNotEmpty).toList();
        return ApproxLocation(
          round1((m['latitude'] as num).toDouble()),
          round1((m['longitude'] as num).toDouble()),
          name: parts.join(', '),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
