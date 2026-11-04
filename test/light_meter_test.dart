import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/services/light_meter.dart';

void main() {
  test('promedia las lecturas del sensor', () {
    final s = summarizeSensorSamples([100, 110, 90, 100], 40000)!;
    expect(s.lux, closeTo(100, 1e-9));
    expect(s.saturated, isFalse);
    expect(s.samples, 4);
  });

  test('detecta cuando el sensor llegó a su tope', () {
    final s = summarizeSensorSamples([40000, 40000, 39900, 12000], 40000)!;
    expect(s.saturated, isTrue);
    expect(summarizeSensorSamples([], 40000), isNull);
  });

  test('una lectura estable no es inestable', () {
    expect(isUnstable([1000, 1020, 990, 1010, 1005]), isFalse);
  });

  test('una lectura que salta mucho es inestable', () {
    expect(isUnstable([1000, 200, 1800, 100, 2000, 300]), isTrue);
  });

  test('con muy poca luz no se considera inestable', () {
    expect(isUnstable([1, 4, 0.5, 3]), isFalse);
    expect(isUnstable([100, 5000]), isFalse); // muy pocas muestras
  });
}
