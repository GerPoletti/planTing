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

/// Respuestas posibles a «¿Cuándo la regaste por última vez?».
enum WateredWhen { today, yesterday, fewDays, week, unknown }

/// Fecha aproximada del último riego, o null si no se sabe.
DateTime? wateredAtFor(WateredWhen w, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final noon = DateTime(n.year, n.month, n.day, 12);
  switch (w) {
    case WateredWhen.today:
      return n;
    case WateredWhen.yesterday:
      return noon.subtract(const Duration(days: 1));
    case WateredWhen.fewDays:
      return noon.subtract(const Duration(days: 3));
    case WateredWhen.week:
      return noon.subtract(const Duration(days: 7));
    case WateredWhen.unknown:
      return null;
  }
}

/// Fichas para elegir cuándo se regó por última vez una planta nueva.
class WateredWhenChips extends ConsumerWidget {
  const WateredWhenChips({super.key, required this.value, required this.onChanged});

  final WateredWhen value;
  final ValueChanged<WateredWhen> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final w in WateredWhen.values)
          ChoiceChip(
            label: Text(s.t('watered.${w.name}')),
            selected: value == w,
            selectedColor: MC.sage,
            backgroundColor: MC.card,
            onSelected: (_) => onChanged(w),
          ),
      ],
    );
  }
}
