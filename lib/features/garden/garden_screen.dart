import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/advice.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../../engine/light_model.dart';
import '../../ui/theme.dart';
import '../../ui/verdict.dart';
import '../../ui/widgets.dart';

/// Jardín: todas las plantas, con su luz, su próximo riego y si están en tratamiento.
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final plants = List<PlantItem>.of(store.plants)
      ..sort((a, b) => plantName(a, content, s.lang).compareTo(plantName(b, content, s.lang)));

    return PageScaffold(
      title: s.t('garden.title'),
      subtitle: s.plural('garden.count', plants.length),
      bottom: FilledButton.icon(
        onPressed: () => context.push('/plants/add'),
        icon: const Icon(Icons.add),
        label: Text(s.t('garden.add')),
      ),
      children: [
        if (plants.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RomuFace(size: 48),
                const SizedBox(height: 10),
                Text(s.t('garden.empty'), style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        for (final plant in plants) _PlantCard(plant: plant),
      ],
    );
  }
}

class _PlantCard extends ConsumerWidget {
  const _PlantCard({required this.plant});

  final PlantItem plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final species = content.speciesById(plant.speciesId);
    final room = store.roomById(plant.roomId);
    final readings = store.readingsFor(plant.id);
    final advice = wateringAdviceFor(ref, plant);
    final treatments = store.treatmentsFor(plant.id, onlyActive: true);

    Widget lightTag = Tag(s.t('garden.not_measured'), color: MC.muted, background: MC.sand);
    if (species != null && readings.isNotEmpty) {
      lightTag = verdictTag(s, LightModel.verdict(readings.first.dli, species.dliMin, species.dliMax));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => context.push('/plant/${plant.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBubble(child: LeafGlyph(size: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plantName(plant, content, s.lang), style: displayStyle(18)),
                      Text(
                        [
                          if (plant.nickname.trim().isNotEmpty && species != null) species.name(s.lang),
                          room?.name ?? s.t('garden.unplaced'),
                        ].join(' · '),
                        style: const TextStyle(color: MC.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                lightTag,
                if (advice != null)
                  Text(
                    s.t('garden.next_water', {'when': s.relativeDay(advice.due)}),
                    style: const TextStyle(color: MC.muted, fontSize: 13),
                  ),
              ],
            ),
            for (final t in treatments)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_outlined, size: 18, color: MC.terraDark),
                    const SizedBox(width: 6),
                    Text(
                      s.t('garden.treating', {'pest': content.pestById(t.pestId)?.name(s.lang) ?? ''}),
                      style: const TextStyle(color: MC.terraDark, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
