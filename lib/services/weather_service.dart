import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Atribución que exige Open-Meteo al usar sus datos.
const String weatherAttribution = 'Weather data by Open-Meteo.com';

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.min,
    required this.max,
    required this.precipitationMm,
  });

  final DateTime date;
  final double min;
  final double max;
  final double precipitationMm;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'min': min,
        'max': max,
        'precipitationMm': precipitationMm,
      };

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        date: DateTime.parse(j['date'] as String),
        min: (j['min'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
        precipitationMm: (j['precipitationMm'] as num).toDouble(),
      );
}

/// Pronóstico de unos días para la ubicación aproximada.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
    required this.currentTemp,
    required this.currentHumidity,
    required this.days,
  });

  final DateTime fetchedAt;
  final double latitude;
  final double longitude;
  final double? currentTemp;
  final double? currentHumidity;
  final List<WeatherDay> days;

  /// Interpreta la respuesta de la API de Open-Meteo.
  factory WeatherSnapshot.fromOpenMeteo(
    Map<String, dynamic> json,
    DateTime fetchedAt,
  ) {
    final current = (json['current'] as Map?) ?? const {};
    final daily = Map<String, dynamic>.from((json['daily'] as Map?) ?? {});
    final times = (daily['time'] as List?) ?? const [];
    List<num?> col(String key) =>
        ((daily[key] as List?) ?? const []).map((e) => e as num?).toList();
    final mins = col('temperature_2m_min');
    final maxs = col('temperature_2m_max');
    final rain = col('precipitation_sum');
    final days = <WeatherDay>[];
    for (var i = 0; i < times.length; i++) {
      final min = i < mins.length ? mins[i] : null;
      final max = i < maxs.length ? maxs[i] : null;
      if (min == null || max == null) continue;
      days.add(WeatherDay(
        date: DateTime.parse(times[i] as String),
        min: min.toDouble(),
        max: max.toDouble(),
        precipitationMm: (i < rain.length ? rain[i] : null)?.toDouble() ?? 0,
      ));
    }
    return WeatherSnapshot(
      fetchedAt: fetchedAt,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentTemp: (current['temperature_2m'] as num?)?.toDouble(),
      currentHumidity: (current['relative_humidity_2m'] as num?)?.toDouble(),
      days: days,
    );
  }

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'currentTemp': currentTemp,
        'currentHumidity': currentHumidity,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        currentTemp: (j['currentTemp'] as num?)?.toDouble(),
        currentHumidity: (j['currentHumidity'] as num?)?.toDouble(),
        days: ((j['days'] as List?) ?? const [])
            .map((e) => WeatherDay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

enum WeatherAlertType { cold, heat, rain }

class WeatherAlert {
  const WeatherAlert({
    required this.type,
    required this.day,
    required this.value,
    this.plantIds = const [],
  });

  final WeatherAlertType type;
  final DateTime day;

  /// Temperatura mínima, máxima o milímetros de lluvia, según el tipo.
  final double value;
  final List<String> plantIds;
}

/// Planta de exterior y la temperatura mínima que tolera.
class ExteriorPlant {
  const ExteriorPlant(this.id, this.tempMin);

  final String id;
  final double tempMin;
}

/// Alertas de los próximos 3 días: frío para cada planta de exterior,
/// calor fuerte y lluvia que vuelve innecesario el riego.
List<WeatherAlert> computeWeatherAlerts(
  WeatherSnapshot weather,
  List<ExteriorPlant> exteriorPlants, {
  double heatThreshold = 35,
  double rainThresholdMm = 5,
}) {
  final alerts = <WeatherAlert>[];
  for (final day in weather.days.take(3)) {
    final cold = exteriorPlants.where((p) => day.min < p.tempMin).toList();
    if (cold.isNotEmpty) {
      alerts.add(WeatherAlert(
        type: WeatherAlertType.cold,
        day: day.date,
        value: day.min,
        plantIds: cold.map((p) => p.id).toList(),
      ));
    }
    if (exteriorPlants.isNotEmpty && day.max >= heatThreshold) {
      alerts.add(WeatherAlert(
        type: WeatherAlertType.heat,
        day: day.date,
        value: day.max,
        plantIds: exteriorPlants.map((p) => p.id).toList(),
      ));
    }
    if (exteriorPlants.isNotEmpty && day.precipitationMm >= rainThresholdMm) {
      alerts.add(WeatherAlert(
        type: WeatherAlertType.rain,
        day: day.date,
        value: day.precipitationMm,
      ));
    }
  }
  return alerts;
}

/// Consulta Open-Meteo y guarda el último resultado para consultar poco.
class WeatherService {
  WeatherService(this.cacheFile);

  final File cacheFile;

  static const Duration freshFor = Duration(hours: 3);

  /// Devuelve el pronóstico. Usa la copia guardada si es reciente y de la
  /// misma zona; si no hay internet, devuelve la última copia aunque sea vieja.
  Future<WeatherSnapshot?> get(double latitude, double longitude, {bool force = false}) async {
    final cached = _readCache();
    final sameZone = cached != null &&
        (cached.latitude - latitude).abs() < 0.05 &&
        (cached.longitude - longitude).abs() < 0.05;
    if (!force && sameZone && DateTime.now().difference(cached.fetchedAt) < freshFor) {
      return cached;
    }
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toStringAsFixed(1),
        'longitude': longitude.toStringAsFixed(1),
        'current': 'temperature_2m,relative_humidity_2m',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'auto',
        'forecast_days': '3',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return sameZone ? cached : null;
      final snapshot = WeatherSnapshot.fromOpenMeteo(
        jsonDecode(res.body) as Map<String, dynamic>,
        DateTime.now(),
      );
      cacheFile.writeAsStringSync(jsonEncode(snapshot.toJson()));
      return snapshot;
    } catch (_) {
      return sameZone ? cached : null;
    }
  }

  WeatherSnapshot? _readCache() {
    try {
      if (!cacheFile.existsSync()) return null;
      return WeatherSnapshot.fromJson(
        jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
