import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/labels.dart';
import '../app/providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// Hoja para elegir una planta. Devuelve su identificador, o null si se cierra.
Future<String?> pickPlant(BuildContext context, WidgetRef ref, {String? selectedId}) {
  final s = ref.read(stringsProvider);
  final store = ref.read(storeProvider);
  final content = ref.read(contentProvider);
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(s.t('measure.pick_plant'), style: displayStyle(20)),
          ),
          for (final p in store.plants)
            ListTile(
              leading: const LeafGlyph(),
              title: Text(plantName(p, content, s.lang)),
              subtitle: Text(store.roomById(p.roomId)?.name ?? ''),
              selected: p.id == selectedId,
              onTap: () => Navigator.of(ctx).pop(p.id),
            ),
        ],
      ),
    ),
  );
}
