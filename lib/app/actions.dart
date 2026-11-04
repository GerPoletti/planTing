import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/primer_screen.dart';
import '../services/location_service.dart';
import 'providers.dart';

/// Resultado de pedir la ubicación.
enum LocationAsk {
  /// Quedó guardada.
  saved,

  /// La persona prefirió escribir su ciudad.
  chooseCity,

  /// Se aceptó pero el sistema no pudo darla (permiso, GPS apagado, etc.).
  failed,
}

/// Explica para qué se usa la ubicación, la pide y la guarda ya redondeada.
Future<LocationAsk> requestLocation(
  BuildContext context,
  WidgetRef ref, {
  bool withPrimer = true,
}) async {
  final store = ref.read(storeProvider);
  if (withPrimer) {
    final go = await showPrimer(context, PrimerKind.location);
    if (!go) return LocationAsk.chooseCity;
  }
  final result = await LocationService.current();
  final loc = result.location;
  if (loc == null) return LocationAsk.failed;
  store.updateSettings((st) {
    st.latitude = loc.latitude;
    st.longitude = loc.longitude;
    st.placeName = loc.name;
  });
  return LocationAsk.saved;
}

/// Guarda una ubicación elegida a mano, por ejemplo al buscar una ciudad.
void saveLocation(WidgetRef ref, ApproxLocation loc) {
  ref.read(storeProvider).updateSettings((st) {
    st.latitude = loc.latitude;
    st.longitude = loc.longitude;
    st.placeName = loc.name;
  });
}
