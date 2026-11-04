import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Ficha de una especie: luz, riego, temperatura, humedad y mascotas.
class SpeciesScreen extends ConsumerWidget {
  const SpeciesScreen({super.key, required this.speciesId});

  final String speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final species = content.speciesById(speciesId);
    if (species == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final mine = store.plants.where((p) => p.speciesId == species.id).length;
    final otherNames = species.names(s.lang).skip(1).join(', ');

    Widget info(String label, String value) => AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: MC.muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        );

    return PageScaffold(
      title: species.name(s.lang),
      subtitle: species.scientific + (otherNames.isEmpty ? '' : ' · $otherNames'),
      showBack: true,
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(color: MC.leaf, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: const LeafGlyph(size: 72),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Tag(s.t('species.place.${species.place}'), color: MC.olive, background: MC.sage),
            species.toxicToPets
                ? Tag(s.t('species.toxic'), color: MC.terraDark, background: MC.terraLight)
                : Tag(s.t('species.safe'), color: MC.olive, background: MC.sage),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            info(
              s.t('species.light'),
              s.t('species.light_value', {
                'min': s.number(species.dliMin, digits: 0),
                'max': s.number(species.dliMax, digits: 0),
              }),
            ),
            info(s.t('species.water'), s.t('species.water_value', {'n': species.waterDays})),
            info(s.t('species.temp'), '${s.number(species.tempMin, digits: 0)} °C'),
            info(
              s.t('species.humidity'),
              s.t('species.humidity_value', {'n': s.number(species.humidityMin, digits: 0)}),
            ),
          ],
        ),
        if (species.isDraft)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(s.t('plant.draft_note'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
          ),
        const SizedBox(height: 14),
        Text(s.t('species.your_plants', {'n': mine}), style: const TextStyle(color: MC.muted, fontSize: 14)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => context.push('/plants/add?species=${species.id}'),
          child: Text(s.t('species.add')),
        ),
      ],
    );
  }
}
