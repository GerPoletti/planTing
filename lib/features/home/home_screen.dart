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
import '../../services/weather_service.dart';
import '../../ui/theme.dart';
import '../../ui/verdict.dart';
import '../../ui/widgets.dart';
import 'orientation_sheet.dart';
import 'plan_view.dart';

/// Casa: el plano con el mapa de luz de hoy, las plantas y qué conviene medir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _light = true;
  String? _roomId;
  String? _plantId;

  LightMap? _map;
  int _mapRevision = -1;
  double _mapLat = 0;
  int _mapDay = -1;

  /// El mapa se vuelve a calcular solo cuando cambian los datos, la latitud o el día.
  LightMap _mapFor(AppStore store) {
    final lat = store.settings.latitude ?? 40.0;
    final day = SunEngine.dayOfYear(DateTime.now());
    if (_map == null || _mapRevision != store.revision || _mapLat != lat || _mapDay != day) {
      _map = LightMap(
        rooms: List<Room>.of(store.rooms),
        readings: List<Reading>.of(store.readings),
        northOffset: store.settings.northOffset,
        latitude: lat,
        dayOfYear: day,
      );
      _mapRevision = store.revision;
      _mapLat = lat;
      _mapDay = day;
    }
    return _map!;
  }

  void _addRoom() {
    final store = ref.read(storeProvider);
    final s = ref.read(stringsProvider);
    final room = store.addRoom(
      name: s.t('home.new_room', {'n': store.rooms.length + 1}),
      exterior: false,
    );
    context.push('/room/${room.id}');
  }

  void _onTapPlant(String id) {
    setState(() {
      _plantId = _plantId == id ? null : id;
      _roomId = null;
    });
  }

  void _onTapPoint(Offset point, Room? room) {
    final store = ref.read(storeProvider);
    final plant = store.plantById(_plantId);
    if (plant != null && room != null) {
      // Con una planta elegida, tocar el plano la mueve (a pasos de medio metro).
      final x = (point.dx * 2).round() / 2;
      final y = (point.dy * 2).round() / 2;
      store.movePlant(plant, x, y);
      return;
    }
    setState(() {
      _roomId = room?.id;
      _plantId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final alerts = ref.watch(weatherAlertsProvider);
    final map = _mapFor(store);
    final now = DateTime.now();

    // Si lo elegido se borró, se limpia la selección.
    if (_plantId != null && store.plantById(_plantId) == null) _plantId = null;
    if (_roomId != null && store.roomById(_roomId) == null) _roomId = null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.weekday(now)} · ${s.dayMonth(now)}',
                        style: const TextStyle(color: MC.muted, fontSize: 13),
                      ),
                      Text(s.t('home.title'), style: displayStyle(30)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: s.t('home.orientation'),
                  onPressed: () => showOrientationSheet(context),
                  icon: const Icon(Icons.explore_outlined),
                ),
                IconButton(
                  tooltip: s.t('home.add_room'),
                  onPressed: _addRoom,
                  icon: const Icon(Icons.add_home_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: MC.sand,
                  foregroundColor: MC.muted,
                  selectedBackgroundColor: MC.ink,
                  selectedForegroundColor: MC.cream,
                  side: BorderSide.none,
                ),
                segments: [
                  ButtonSegment(value: false, label: Text(s.t('home.mode.plan'))),
                  ButtonSegment(value: true, label: Text(s.t('home.mode.light'))),
                ],
                selected: {_light},
                onSelectionChanged: (v) => setState(() => _light = v.first),
              ),
            ),
            const SizedBox(height: 14),
            if (store.rooms.isEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('home.empty'), style: const TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _addRoom, child: Text(s.t('home.add_room'))),
                  ],
                ),
              )
            else ...[
              PlanView(
                rooms: store.rooms,
                plants: store.plants,
                readings: store.readings,
                map: map,
                showLight: _light,
                northOffset: store.settings.northOffset,
                selectedRoomId: _roomId,
                selectedPlantId: _plantId,
                semanticsLabel: s.t('home.plan_label', {
                  'rooms': store.rooms.length,
                  'plants': store.plants.length,
                }),
                onTapPlant: _onTapPlant,
                onTapPoint: _onTapPoint,
              ),
              if (_light)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      Text(s.t('home.legend.less'), style: const TextStyle(color: MC.muted, fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: const LinearGradient(colors: [MC.sand, MC.sun]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.t('home.legend.more'), style: const TextStyle(color: MC.muted, fontSize: 12)),
                    ],
                  ),
                ),
            ],
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final a in alerts.take(2)) _alertCard(s, a),
            ],
            if (_plantId != null) ...[
              const SizedBox(height: 14),
              _plantPanel(s, store, content, map),
            ] else if (_roomId != null) ...[
              const SizedBox(height: 14),
              _roomPanel(s, store, map),
            ],
            const SizedBox(height: 14),
            _suggestionsCard(s, store, content),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ alertas

  Widget _alertCard(AppStrings s, WeatherAlert a) {
    final String text;
    switch (a.type) {
      case WeatherAlertType.cold:
        text = s.t('alert.cold', {'day': s.dayMonth(a.day), 't': s.number(a.value, digits: 0)});
      case WeatherAlertType.heat:
        text = s.t('alert.heat', {'day': s.dayMonth(a.day), 't': s.number(a.value, digits: 0)});
      case WeatherAlertType.rain:
        text = s.t('alert.rain', {'mm': s.number(a.value, digits: 0)});
    }
    final icon = switch (a.type) {
      WeatherAlertType.cold => Icons.ac_unit,
      WeatherAlertType.heat => Icons.wb_sunny_outlined,
      WeatherAlertType.rain => Icons.water_drop_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        color: MC.terraLight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: MC.terraDark),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- planta elegida

  Widget _plantPanel(AppStrings s, AppStore store, Content content, LightMap map) {
    final plant = store.plantById(_plantId);
    final species = plant == null ? null : content.speciesById(plant.speciesId);
    if (plant == null || species == null) return const SizedBox.shrink();

    final dli = map.lightAt(plant.x, plant.y);
    final verdict = LightModel.verdict(dli, species.dliMin, species.dliMax);
    final best = verdict == LightVerdict.ok ? null : map.bestSpot(species);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plantName(plant, content, s.lang),
                  style: displayStyle(20),
                ),
              ),
              verdictTag(s, verdict),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t('home.plant.est', {
              'dli': s.number(dli),
              'min': s.number(species.dliMin, digits: 0),
              'max': s.number(species.dliMax, digits: 0),
            }),
            style: const TextStyle(color: MC.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (verdict == LightVerdict.ok)
            Text(s.t('home.plant.good'), style: const TextStyle(fontSize: 14))
          else if (best != null && best.inRange) ...[
            Text(
              s.t('home.plant.better', {'room': best.room.name, 'dli': s.number(best.dli)}),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => store.movePlant(plant, best.x, best.y),
              child: Text(s.t('home.plant.move')),
            ),
          ] else
            Text(s.t('home.plant.none'), style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Text(s.t('home.plant.hint'), style: const TextStyle(color: MC.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/plant/${plant.id}'),
                  child: Text(s.t('home.plant.open')),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _plantId = null),
                child: Text(s.t('common.close')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ ambiente elegido

  Widget _roomPanel(AppStrings s, AppStore store, LightMap map) {
    final room = store.roomById(_roomId);
    if (room == null) return const SizedBox.shrink();
    final azimuthOf = (WindowSpot w) => windowAzimuth(w, store.settings.northOffset);
    final readings = map.readingsIn(room.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(room.name, style: displayStyle(20))),
              Tag(
                room.exterior ? s.t('home.exterior') : s.t('home.interior'),
                background: MC.sage,
                color: MC.olive,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final w in room.windows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.window_outlined, color: MC.olive),
              title: Text(
                s.t('home.window_line', {
                  'name': w.name,
                  'dir': directionName(s, azimuthOf(w)),
                  'h': s.number(map.sunHoursOf(w.id)),
                }),
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/window/${w.id}'),
            ),
          const SizedBox(height: 4),
          Text(
            readings > 0
                ? s.t('home.room.factor', {'f': s.number(map.factorOf(room.id), digits: 2)})
                : s.t('home.room.theoretical'),
            style: const TextStyle(color: MC.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/room/${room.id}'),
                  child: Text(s.t('home.room.edit')),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _roomId = null),
                child: Text(s.t('common.close')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- qué medir

  Widget _suggestionsCard(AppStrings s, AppStore store, Content content) {
    final suggestions = measureSuggestions(store);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('suggest.title'), style: displayStyle(18)),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            Text(s.t('suggest.done'), style: const TextStyle(color: MC.muted, fontSize: 14)),
          for (final item in suggestions) _suggestionRow(s, store, content, item),
          const SizedBox(height: 6),
          Text(s.t('suggest.tip'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _suggestionRow(AppStrings s, AppStore store, Content content, MeasureSuggestion item) {
    String text;
    String? plantId = item.plantId;
    switch (item.kind) {
      case SuggestionKind.neverMeasured:
        final p = store.plantById(item.plantId);
        text = s.t('suggest.never', {'name': p == null ? '' : plantName(p, content, s.lang)});
      case SuggestionKind.stale:
        final p = store.plantById(item.plantId);
        text = s.t('suggest.stale', {
          'name': p == null ? '' : plantName(p, content, s.lang),
          'n': item.daysAgo ?? 0,
        });
      case SuggestionKind.roomWithoutReadings:
        final room = store.roomById(item.roomId);
        text = s.t('suggest.room', {'name': room?.name ?? ''});
        for (final p in store.plants) {
          if (p.roomId == item.roomId) {
            plantId = p.id;
            break;
          }
        }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => context.push(plantId == null ? '/measure' : '/measure?plant=$plantId'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: const BorderSide(color: MC.line, width: 1.5),
            ),
            child: Text(s.t('suggest.measure')),
          ),
        ],
      ),
    );
  }
}
