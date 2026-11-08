import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme.dart';
import 'providers.dart';

/// Muestra arriba de la pantalla, si falló el guardado en el teléfono, un
/// aviso con «Reintentar». Envuelve cada ruta para que el aviso se vea
/// también en las pantallas que se abren por encima de la navegación.
class SaveStatusFrame extends ConsumerWidget {
  const SaveStatusFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(storeProvider.select((st) => st.saveFailed));
    if (!failed) return child;
    final s = ref.watch(stringsProvider);
    return Column(
      children: [
        Material(
          color: MC.terraLight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: MC.terraDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.t('save.failed_banner'), style: const TextStyle(fontSize: 13, height: 1.35)),
                  ),
                  TextButton(
                    onPressed: () => ref.read(storeProvider).flush(),
                    child: Text(s.t('settings.save_retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Debajo del aviso la pantalla ya no necesita reservar la barra de estado.
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ],
    );
  }
}
