import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../engine/light_map.dart';
import '../../engine/placement.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/species_picker.dart';

/// «¿Dónde la pongo?»: los tres mejores lugares de la casa para una planta o
/// una especie, con el rango probable de luz, por qué y qué se supone.
class WhereScreen extends ConsumerStatefulWidget {
  const WhereScreen({super.key, this.plantId, this.speciesId});

  final String? plantId;
  final String? speciesId;

  @override
  ConsumerState<WhereScreen> createState() => _WhereScreenState();
}

class _WhereScreenState extends ConsumerState<WhereScreen> {
  String? _plantId;
  String? _speciesId;

  /// Altura donde iría la maceta. Empieza en la de la planta (o una mesa).
  double? _heightCm;

  @override
  void initState() {
    super.initState();
    _plantId = widget.plantId;
    _speciesId = widget.speciesId;
    _heightCm = ref.read(storeProvider).plantById(_plantId)?.heightCm;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final plant = store.plantById(_plantId);
    final species = content.speciesById(plant?.speciesId ?? _speciesId);

    if (species == null) return _chooser(s, store.plants, content);

    final map = ref.watch(lightMapProvider);
    final result = PlacementEngine.suggest(
      map: map,
      species: species,
      plants: store.plants,
      ignorePlantId: plant?.id,
      hasLocation: store.settings.latitude != null,
      heightCm: _heightCm ?? defaultPlantHeightCm,
    );
    final level = PlantLevel.nearest(_heightCm ?? defaultPlantHeightCm);
    final title = plant != null ? plantName(plant, content, s.lang) : species.name(s.lang);
    final hereDli = plant == null ? null : map.lightAt(plant.x, plant.y, heightCm: plant.heightCm);

    return PageScaffold(
      title: s.t('where.title'),
      subtitle: title,
      showBack: true,
      children: [
        // Sin especie identificada no se muestran necesidades: serían inventadas.
        if (!species.isUnknown)
          Text(
            s.t('where.needs', {
              'min': s.number(species.dliMin, digits: 0),
              'max': s.number(species.dliMax, digits: 0),
            }),
            style: const TextStyle(color: MC.muted, fontSize: 14, height: 1.4),
          ),
        if (!species.isUnknown && hereDli != null && plant!.roomId != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.t('where.now', {'dli': s.number(hereDli)}),
              style: const TextStyle(color: MC.muted, fontSize: 14),
            ),
          ),
        const SizedBox(height: 10),
        Text(s.t('where.height'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final l in PlantLevel.values)
              ChoiceChip(
                label: Text(s.t('level.${l.name}')),
                selected: level == l,
                selectedColor: MC.sage,
                backgroundColor: MC.card,
                onSelected: (_) => setState(() => _heightCm = l.cm),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (result.options.isEmpty)
          AppCard(child: Text(_emptyText(s, result), style: const TextStyle(fontSize: 14, height: 1.4)))
        else ...[
          if (result.onlyCandidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RomuSays(s.t('where.only_candidates')),
            )
          else if (!result.hasGood)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RomuSays(s.t('where.none_good')),
            ),
          for (var i = 0; i < result.options.length; i++)
            _optionCard(s, store.settings, result.options[i], i, plant, species),
        ],
        SectionTitle(s.t('where.assumptions')),
        for (final a in result.assumptions) _bullet(s.t('where.assume.${a.name}')),
        _bullet(s.t('where.assume.today')),
        _bullet(s.t('where.assume.model')),
        if (result.assumptions.contains(PlacementAssumption.noLocation))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => askLocation(context, ref),
              child: Text(s.t('measure.set_location')),
            ),
          ),
      ],
    );
  }

  String _emptyText(AppStrings s, PlacementResult r) {
    if (r.assumptions.contains(PlacementAssumption.noCompatibleRoom)) return s.t('where.no_room');
    if (r.assumptions.contains(PlacementAssumption.noWindows)) return s.t('where.no_windows');
    if (r.assumptions.contains(PlacementAssumption.unknownSpecies)) return s.t('where.unknown_species');
    return s.t('where.no_spot');
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('·  ', style: TextStyle(color: MC.muted)),
            Expanded(child: Text(text, style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.4))),
          ],
        ),
      );

  Widget _optionCard(
    AppStrings s,
    Settings settings,
    PlacementOption o,
    int index,
    PlantItem? plant,
    Species species,
  ) {
    final store = ref.read(storeProvider);
    final (fitText, fitColor, fitBg) = !o.measured
        ? (s.t('where.fit.candidate'), MC.ink, MC.sunLight)
        : switch (o.fit) {
      PlacementFit.good => (s.t('where.fit.good'), MC.olive, MC.sage),
      PlacementFit.uncertain => (s.t('where.fit.uncertain'), MC.ink, MC.sand),
      PlacementFit.low => (s.t('where.fit.low'), MC.terraDark, MC.terraLight),
      PlacementFit.high => (s.t('where.fit.high'), MC.terraDark, MC.terraLight),
          };
    final measureHere = plant == null
        ? null
        : '/measure?plant=${plant.id}&x=${o.x.toStringAsFixed(2)}&y=${o.y.toStringAsFixed(2)}'
            '&z=${(_heightCm ?? defaultPlantHeightCm).round()}';
    final w = o.window;
    final why = o.room.exterior
        ? s.t('where.why_outdoor', {
            'kind': s.t('room.kind.${o.room.kind}'),
            'h': s.number(o.sunHours),
          })
        : w == null
        ? s.t('where.why_center')
        : s.t('where.why', {
            'd': s.number(o.windowDistance ?? 0),
            'window': w.name,
            'dir': directionName(s, windowAzimuth(w, settings.northOffset)),
            'h': s.number(o.sunHours),
          });
    final basis = o.measured
        ? s.plural('where.basis_measured', o.readings)
        : s.t('where.basis_theory');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: index == 0 ? MC.olive : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${index + 1}. ${o.room.name}', style: displayStyle(20)),
                ),
                const SizedBox(width: 8),
                Flexible(child: Tag(fitText, color: fitColor, background: fitBg)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.t('where.range', {
                'low': s.number(o.low),
                'high': s.number(o.high),
                'pct': (o.margin * 100).round(),
              }),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(why, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 2),
            Text(basis, style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (plant != null && o.actionable) ...[
                  FilledButton(
                    onPressed: () {
                      store.movePlant(plant, o.x, o.y);
                      store.updatePlant(plant, (p) => p.heightCm = _heightCm ?? p.heightCm);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(s.t('where.moved', {'room': o.room.name}))));
                    },
                    child: Text(s.t('where.move')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push(measureHere!),
                    child: Text(s.t('where.measure_here')),
                  ),
                ] else if (plant != null)
                  FilledButton(
                    onPressed: () => context.push(measureHere!),
                    child: Text(s.t('where.measure_here')),
                  )
                else
                  FilledButton(
                    onPressed: () {
                      final p = store.addPlant(speciesId: species.id, x: o.x, y: o.y);
                      store.updatePlant(p, (q) => q.heightCm = _heightCm);
                      if (o.actionable) {
                        context.pushReplacement('/plant/${p.id}');
                      } else {
                        context.pushReplacement('/measure?plant=${p.id}');
                      }
                    },
                    child: Text(o.actionable ? s.t('where.add_here') : s.t('where.add_measure')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sin planta ni especie: elegir una de las plantas o buscar una especie.
  Widget _chooser(AppStrings s, List<PlantItem> plants, Content content) {
    return PageScaffold(
      title: s.t('where.title'),
      showBack: true,
      children: [
        Text(s.t('where.choose'), style: const TextStyle(color: MC.muted, fontSize: 14, height: 1.4)),
        if (plants.isNotEmpty) ...[
          SectionTitle(s.t('where.your_plants')),
          for (final p in plants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const LeafGlyph(),
              title: Text(plantName(p, content, s.lang)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _plantId = p.id),
            ),
        ],
        SectionTitle(s.t('where.a_species')),
        SpeciesPicker(onSelected: (sp) => setState(() => _speciesId = sp.id)),
      ],
    );
  }
}
