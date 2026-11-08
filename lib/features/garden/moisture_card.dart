import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/advice.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/models.dart';
import '../../engine/watering.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../../data/dates.dart';

String _adviceTitleKey(WateringAction a) {
  switch (a) {
    case WateringAction.waterNow:
      return 'advice.water_now';
    case WateringAction.waterSoon:
      return 'advice.water_soon';
    case WateringAction.wait:
      return 'advice.wait';
    case WateringAction.check:
      return 'advice.check';
    case WateringAction.skipRain:
      return 'advice.rain';
  }
}

/// Cuándo se revisó la tierra por última vez, en palabras.
String _whenText(AppStrings s, DateTime at) {
  final days = daysBetween(at, DateTime.now());
  return days <= 0 ? s.t('rel.today') : s.plural('rel.ago', days);
}

/// Humedad de la tierra de una planta y qué hacer con el riego.
class MoistureCard extends ConsumerWidget {
  const MoistureCard({super.key, required this.plant});

  final PlantItem plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final advice = wateringAdviceFor(ref, plant);
    if (advice == null) return const SizedBox.shrink();
    final history = store.moistureFor(plant.id);
    final last = history.isEmpty ? null : history.first;

    final canWater =
        advice.action == WateringAction.waterNow || advice.action == WateringAction.waterSoon;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('moisture.title'), style: displayStyle(18)),
          if (ref.watch(contentProvider).speciesById(plant.speciesId)?.medium == 'bark')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.t('moisture.bark_note'), style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.35)),
            ),
          const SizedBox(height: 10),
          _LevelBars(level: last?.level),
          const SizedBox(height: 8),
          Text(
            last == null
                ? s.t('moisture.none')
                : s.t('moisture.checked', {
                    'when': _whenText(s, last.at),
                    'level': s.t('moisture.level.${last.level.name}').toLowerCase(),
                  }),
            style: const TextStyle(color: MC.muted, fontSize: 13),
          ),
          const Divider(height: 24),
          Text(
            s.t(_adviceTitleKey(advice.action)),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('advice.why.${advice.reason.name}'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            s.t('advice.next', {'when': s.relativeDay(advice.due)}),
            style: const TextStyle(color: MC.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showMoistureSheet(context, plant),
                  child: Text(s.t('moisture.check')),
                ),
              ),
              if (canWater) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _water(context, ref, null),
                    child: Text(s.t('moisture.water_now')),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              if (!canWater)
                ActionChip(
                  label: Text(s.t('moisture.watered_today')),
                  onPressed: () => _water(context, ref, null),
                ),
              ActionChip(
                label: Text(s.t('moisture.watered_yesterday')),
                onPressed: () {
                  final y = DateTime.now().subtract(const Duration(days: 1));
                  _water(context, ref, DateTime(y.year, y.month, y.day, 12));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Anota un riego (hoy o en [at]) y permite deshacerlo.
  void _water(BuildContext context, WidgetRef ref, DateTime? at) {
    final s = ref.read(stringsProvider);
    final store = ref.read(storeProvider);
    final e = store.addEvent(plant.id, CareType.water, at: at);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s.t('moisture.watered')),
      action: SnackBarAction(
        label: s.t('common.undo'),
        onPressed: () => store.removeEvent(e.id),
      ),
    ));
  }
}

/// Cuatro barras: cuántas están llenas indica qué tan mojada está la tierra.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level});

  final MoistureLevel? level;

  @override
  Widget build(BuildContext context) {
    final filled = level == null ? 0 : level!.index + 1;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < filled ? MC.olive : MC.sand,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hoja para registrar cómo está la tierra: al tacto o con un medidor.
Future<void> showMoistureSheet(BuildContext context, PlantItem plant) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoistureSheet(plant: plant),
  );
}

class _MoistureSheet extends ConsumerStatefulWidget {
  const _MoistureSheet({required this.plant});

  final PlantItem plant;

  @override
  ConsumerState<_MoistureSheet> createState() => _MoistureSheetState();
}

class _MoistureSheetState extends ConsumerState<_MoistureSheet> {
  bool _meter = false;
  double _percent = 40;

  void _save(MoistureLevel level, {required String method, double? percent}) {
    final s = ref.read(stringsProvider);
    ref
        .read(storeProvider)
        .addMoisture(widget.plant.id, level, method: method, percent: percent);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('moisture.saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('moisture.check'), style: displayStyle(22)),
            const SizedBox(height: 4),
            Text(s.t('moisture.how'), style: const TextStyle(color: MC.muted, fontSize: 14)),
            const SizedBox(height: 14),
            if (!_meter)
              for (final level in MoistureLevel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => _save(level, method: 'finger'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('moisture.level.${level.name}'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.t('moisture.hint.${level.name}'),
                          style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('moisture.meter_toggle')),
              value: _meter,
              onChanged: (v) => setState(() => _meter = v),
            ),
            if (_meter) ...[
              Text(
                s.t('moisture.meter_value', {'n': _percent.round()}),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _percent,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_percent.round()} %',
                onChanged: (v) => setState(() => _percent = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _save(
                  MoistureLevel.fromMeter(_percent),
                  method: 'meter',
                  percent: _percent.roundToDouble(),
                ),
                child: Text(s.t('common.save')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
