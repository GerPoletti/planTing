import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../engine/light_map.dart';
import '../../engine/light_model.dart';
import '../../engine/sun_engine.dart';
import '../../ui/dialogs.dart';
import '../../ui/theme.dart';
import '../../ui/verdict.dart';
import '../../ui/widgets.dart';

/// Una ventana: hacia dónde mira, cuánto sol directo recibe y qué plantas hay cerca.
class WindowScreen extends ConsumerStatefulWidget {
  const WindowScreen({super.key, required this.windowId});

  final String windowId;

  @override
  ConsumerState<WindowScreen> createState() => _WindowScreenState();
}

class _WindowScreenState extends ConsumerState<WindowScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final w = ref.read(storeProvider).windowById(widget.windowId);
    _name = TextEditingController(text: w?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final store = ref.read(storeProvider);
    final s = ref.read(stringsProvider);
    final room = store.roomOfWindow(widget.windowId);
    final window = store.windowById(widget.windowId);
    if (room == null || window == null) return;
    final ok = await confirmDialog(
      context,
      title: s.t('window.delete'),
      body: s.t('window.delete_confirm', {'name': window.name}),
      confirmLabel: s.t('common.delete'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    store.removeWindow(room, window.id);
    store.replaceAllPlants();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final window = store.windowById(widget.windowId);
    final room = store.roomOfWindow(widget.windowId);
    if (window == null || room == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final now = DateTime.now();
    final lat = store.settings.latitude ?? 40.0;
    final doy = SunEngine.dayOfYear(now);
    final azimuth = windowAzimuth(window, store.settings.northOffset);
    final geometry = WindowGeometry(azimuth: azimuth, obstruction: window.obstruction);
    final hours = SunEngine.sunHours(geometry, lat, doy);
    final strip = SunEngine.litStrip(geometry, lat, doy);
    final months = SunEngine.monthlySunHours(geometry, lat, now.year);
    final map = LightMap(
      rooms: List.of(store.rooms),
      readings: List.of(store.readings),
      northOffset: store.settings.northOffset,
      latitude: lat,
      dayOfYear: doy,
    );
    final windowPoint = AppStore.windowPoint(room, window);
    final nearby = store.plants.where((p) => p.windowId == window.id).toList();

    return PageScaffold(
      title: window.name,
      subtitle: room.name,
      showBack: true,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: s.t('window.name')),
          onChanged: (v) {
            final name = v.trim();
            if (name.isNotEmpty) store.updateWindow(window, (w) => w.name = name);
          },
        ),
        SectionTitle(s.t('window.wall')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final wall in ['t', 'r', 'b', 'l'])
              ChoiceChip(
                label: Text(s.t('window.wall.$wall')),
                selected: window.wall == wall,
                selectedColor: MC.sage,
                backgroundColor: MC.card,
                onSelected: (_) {
                  store.updateWindow(window, (w) => w.wall = wall);
                  store.replaceAllPlants();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          s.t('window.faces', {'dir': directionName(s, azimuth), 'deg': azimuth.round()}),
          style: displayStyle(20),
        ),
        const SizedBox(height: 14),
        Text(s.t('window.position'), style: const TextStyle(color: MC.muted, fontSize: 13)),
        Slider(
          value: window.pos.clamp(0.0, 1.0),
          onChanged: (v) => store.updateWindow(window, (w) => w.pos = v),
          onChangeEnd: (_) => store.replaceAllPlants(),
        ),
        Text(
          s.t('window.obstruction', {'n': window.obstruction.round()}),
          style: const TextStyle(color: MC.muted, fontSize: 13),
        ),
        Slider(
          value: window.obstruction.clamp(0.0, 60.0),
          min: 0,
          max: 60,
          divisions: 60,
          onChanged: (v) => store.updateWindow(window, (w) => w.obstruction = v.roundToDouble()),
        ),
        Text(
          s.t('window.obstruction_help'),
          style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('window.sun_today', {'h': s.number(hours)}), style: displayStyle(20)),
              const SizedBox(height: 10),
              Text(s.t('window.strip'), style: const TextStyle(color: MC.muted, fontSize: 12)),
              const SizedBox(height: 6),
              _SunStrip(cells: strip),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0', style: TextStyle(color: MC.muted, fontSize: 11)),
                  Text('6', style: TextStyle(color: MC.muted, fontSize: 11)),
                  Text('12', style: TextStyle(color: MC.muted, fontSize: 11)),
                  Text('18', style: TextStyle(color: MC.muted, fontSize: 11)),
                  Text('24', style: TextStyle(color: MC.muted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 14),
              Text(s.t('window.months'), style: const TextStyle(color: MC.muted, fontSize: 12)),
              const SizedBox(height: 8),
              _MonthBars(values: months, current: now.month - 1, s: s),
              const SizedBox(height: 10),
              Text(
                s.t('window.dli', {'dli': s.number(map.lightAt(windowPoint.dx, windowPoint.dy))}),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(s.t('window.note'), style: const TextStyle(color: MC.muted, fontSize: 12)),
            ],
          ),
        ),
        SectionTitle(s.t('window.plants')),
        if (nearby.isEmpty)
          Text(s.t('window.no_plants'), style: const TextStyle(color: MC.muted, fontSize: 14)),
        for (final p in nearby) _plantRow(s, content, map, p),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, color: MC.terraDark),
          label: Text(s.t('window.delete'), style: const TextStyle(color: MC.terraDark)),
        ),
      ],
    );
  }

  Widget _plantRow(AppStrings s, Content content, LightMap map, PlantItem plant) {
    final species = content.speciesById(plant.speciesId);
    final dli = map.lightAt(plant.x, plant.y);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push('/plant/${plant.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const LeafGlyph(size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                plantName(plant, content, s.lang),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (species != null) verdictTag(s, LightModel.verdict(dli, species.dliMin, species.dliMax)),
          ],
        ),
      ),
    );
  }
}

class _SunStrip extends StatelessWidget {
  const _SunStrip({required this.cells});

  final List<bool> cells;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          for (final lit in cells)
            Expanded(child: Container(height: 20, color: lit ? MC.sun : MC.sand)),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.values, required this.current, required this.s});

  final List<double> values;
  final int current;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(1.0, values.reduce(math.max));
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var m = 0; m < values.length; m++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: math.max(2.0, values[m] / maxValue * 70),
                      decoration: BoxDecoration(
                        color: m == current ? MC.olive : MC.line,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.monthInitial(m + 1), style: const TextStyle(color: MC.muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
