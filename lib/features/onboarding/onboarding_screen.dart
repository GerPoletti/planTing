import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../services/compass_service.dart';
import '../../services/location_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'species_picker.dart';

/// Primer uso: elegir la planta, ubicarla y ponerle un apodo.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<String> _roomKeys = ['living', 'kitchen', 'bedroom', 'balcony', 'office'];

  int _step = 0;
  Species? _species;
  String _roomKey = 'living';
  double _azimuth = 180;
  bool _compassBusy = false;
  String? _compassMessage;
  bool _cityMode = false;
  String? _cityMessage;
  bool _searching = false;
  List<ApproxLocation> _cityResults = [];
  String? _plantId;

  final TextEditingController _city = TextEditingController();
  final TextEditingController _nickname = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    _nickname.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- acciones

  Future<void> _readCompass() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _compassBusy = true;
      _compassMessage = null;
    });
    final heading = await CompassService.readOnce();
    if (!mounted) return;
    setState(() {
      _compassBusy = false;
      if (heading == null) {
        _compassMessage = s.t('onb.where.compass_fail');
      } else {
        _azimuth = CompassService.snapToEight(heading);
        _compassMessage = s.t('onb.where.reading', {
          'dir': directionName(s, _azimuth),
          'deg': _azimuth.round(),
        });
      }
    });
  }

  Future<void> _useLocation() async {
    final result = await requestLocation(context, ref);
    if (!mounted) return;
    final s = ref.read(stringsProvider);
    setState(() {
      if (result == LocationAsk.saved) {
        _cityMode = false;
        _cityMessage = null;
      } else {
        _cityMode = true;
        _cityMessage = result == LocationAsk.failed ? s.t('onb.loc.denied') : null;
      }
    });
  }

  Future<void> _searchCity() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _searching = true;
      _cityMessage = null;
    });
    final results = await LocationService.searchPlace(_city.text, s.lang);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _cityResults = results;
      if (results.isEmpty) _cityMessage = s.t('onb.loc.none');
    });
  }

  void _chooseCity(ApproxLocation loc) {
    saveLocation(ref, loc);
    setState(() {
      _cityMode = false;
      _cityResults = [];
      _cityMessage = null;
    });
  }

  /// Crea el ambiente, la ventana y la planta con lo elegido.
  void _createHome() {
    final store = ref.read(storeProvider);
    final s = ref.read(stringsProvider);
    final exterior = _roomKey == 'balcony';
    final room = store.addRoom(
      name: s.t('onb.room.$_roomKey'),
      exterior: exterior,
      x: 0,
      y: 0,
      w: 4,
      h: exterior ? 2 : 3,
    );
    store.addWindow(room, name: s.t('onb.window_name'), wall: 't');
    // La pared de arriba del plano mira hacia donde mira la ventana.
    store.updateSettings((st) => st.northOffset = _azimuth);
    final plant = store.addPlant(speciesId: _species!.id, x: room.w / 2, y: 0.9);
    _plantId = plant.id;
    setState(() => _step = 2);
  }

  void _finish({required bool measure}) {
    final store = ref.read(storeProvider);
    final id = _plantId;
    final name = _nickname.text.trim();
    if (id != null && name.isNotEmpty) {
      final plant = store.plantById(id);
      if (plant != null) store.updatePlant(plant, (p) => p.nickname = name);
    }
    store.updateSettings((st) => st.onboardingDone = true);
    context.go(measure && id != null ? '/measure?plant=$id' : '/');
  }

  // ------------------------------------------------------------------ vista

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? MC.olive : MC.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                children: switch (_step) {
                  0 => _plantStep(s),
                  1 => _whereStep(s),
                  _ => _nameStep(s),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _bottom(s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottom(AppStrings s) {
    switch (_step) {
      case 0:
        return FilledButton(
          onPressed: _species == null ? null : () => setState(() => _step = 1),
          child: Text(
            _species == null
                ? s.t('common.continue')
                : s.t('onb.plant.next', {'name': _species!.name(s.lang)}),
          ),
        );
      case 1:
        return Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: Text(s.t('common.back')),
            ),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: _createHome, child: Text(s.t('common.continue')))),
          ],
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(onPressed: () => _finish(measure: true), child: Text(s.t('onb.name.measure'))),
            const SizedBox(height: 6),
            TextButton(onPressed: () => _finish(measure: false), child: Text(s.t('onb.name.enter'))),
          ],
        );
    }
  }

  // ---- paso 1: la planta

  List<Widget> _plantStep(AppStrings s) {
    return [
      Text(s.t('onb.step', {'n': 1}), style: const TextStyle(color: MC.muted, fontSize: 13)),
      const SizedBox(height: 2),
      Text(s.t('onb.plant.title'), style: displayStyle(30)),
      const SizedBox(height: 6),
      Text(s.t('onb.plant.sub'), style: const TextStyle(color: MC.muted, fontSize: 14)),
      const SizedBox(height: 16),
      SpeciesPicker(
        selectedId: _species?.id,
        onSelected: (sp) => setState(() => _species = sp),
      ),
      const SizedBox(height: 8),
      Opacity(
        opacity: 0.6,
        child: AppCard(
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: MC.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(s.t('onb.plant.photo'))),
              Tag(s.t('onb.plant.soon')),
            ],
          ),
        ),
      ),
    ];
  }

  // ---- paso 2: dónde vive

  List<Widget> _whereStep(AppStrings s) {
    final store = ref.watch(storeProvider);
    final hasLocation = store.settings.latitude != null;
    return [
      Text(s.t('onb.step', {'n': 2}), style: const TextStyle(color: MC.muted, fontSize: 13)),
      const SizedBox(height: 2),
      Text(s.t('onb.where.title'), style: displayStyle(30)),
      const SizedBox(height: 6),
      Text(s.t('onb.where.sub'), style: const TextStyle(color: MC.muted, fontSize: 14)),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final key in _roomKeys)
            ChoiceChip(
              label: Text(s.t('onb.room.$key')),
              selected: _roomKey == key,
              selectedColor: MC.sage,
              backgroundColor: MC.card,
              onSelected: (_) => setState(() => _roomKey = key),
            ),
        ],
      ),
      SectionTitle(s.t('onb.where.window')),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 56, height: 56, child: CustomPaint(painter: _CompassPainter(_azimuth))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(directionName(s, _azimuth), style: displayStyle(22)),
                      Text('${_azimuth.round()}°', style: const TextStyle(color: MC.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _compassBusy ? null : _readCompass,
              icon: const Icon(Icons.explore_outlined),
              label: Text(_compassBusy ? s.t('onb.where.compass_busy') : s.t('onb.where.compass')),
            ),
            if (_compassMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_compassMessage!, style: const TextStyle(color: MC.muted, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.45,
              children: [
                for (var i = 0; i < 8; i++)
                  OutlinedButton(
                    onPressed: () => setState(() => _azimuth = i * 45.0),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      backgroundColor: _azimuth == i * 45.0 ? MC.sage : null,
                      side: BorderSide(
                        color: _azimuth == i * 45.0 ? MC.olive : MC.line,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      directionName(s, i * 45.0),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      SectionTitle(s.t('onb.loc.title')),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLocation) ...[
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: MC.olive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('onb.loc.ok', {'place': store.settings.placeName ?? s.t('onb.loc.approx')}),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ] else if (!_cityMode) ...[
              FilledButton(onPressed: _useLocation, child: Text(s.t('onb.loc.use'))),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _cityMode = true),
                child: Text(s.t('primer.location.alt')),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _city,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchCity(),
                      decoration: InputDecoration(hintText: s.t('onb.loc.city_hint')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _searchCity,
                    style: FilledButton.styleFrom(minimumSize: const Size(80, 52)),
                    child: Text(s.t('onb.loc.search')),
                  ),
                ],
              ),
              if (_cityMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_cityMessage!, style: const TextStyle(color: MC.muted, fontSize: 13)),
                ),
              for (final r in _cityResults)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(r.name ?? ''),
                  onTap: () => _chooseCity(r),
                ),
              TextButton(
                onPressed: () => setState(() => _cityMode = false),
                child: Text(s.t('onb.loc.later')),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ---- paso 3: el apodo

  List<Widget> _nameStep(AppStrings s) {
    final content = ref.watch(contentProvider);
    final species = content.speciesById(_species?.id);
    return [
      Text(s.t('onb.step', {'n': 3}), style: const TextStyle(color: MC.muted, fontSize: 13)),
      const SizedBox(height: 2),
      Text(s.t('onb.name.title'), style: displayStyle(30)),
      const SizedBox(height: 6),
      Text(s.t('onb.name.sub'), style: const TextStyle(color: MC.muted, fontSize: 14)),
      const SizedBox(height: 20),
      Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(color: MC.leaf, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const LeafGlyph(size: 64),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: Text(
          species?.name(s.lang) ?? '',
          style: displayStyle(22),
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _nickname,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: s.t('onb.name.field')),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: Tag(s.t('onb.name.milestone')),
      ),
      const SizedBox(height: 16),
      const RomuFace(size: 44),
    ];
  }
}

/// Rosa de los vientos pequeña que marca hacia dónde mira la ventana.
class _CompassPainter extends CustomPainter {
  _CompassPainter(this.azimuth);

  final double azimuth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = MC.card);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = MC.line,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(azimuth * 3.141592653589793 / 180);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r + 4)
        ..lineTo(r * 0.28, 0)
        ..lineTo(-r * 0.28, 0)
        ..close(),
      Paint()..color = MC.terracotta,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, r - 4)
        ..lineTo(r * 0.28, 0)
        ..lineTo(-r * 0.28, 0)
        ..close(),
      Paint()..color = MC.kitten,
    );
    canvas.restore();
    canvas.drawCircle(c, 3, Paint()..color = MC.ink);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.azimuth != azimuth;
}
