import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../engine/light_model.dart';
import '../../engine/sun_engine.dart';
import '../../services/light_meter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/primer_screen.dart';
import 'dial.dart';

enum _Phase { idle, measuring, result, saturated, failed }

/// Medidor de luz: dial, medición de 5 segundos, resultado y guardado.
class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key, this.plantId, this.probeX, this.probeY, this.probeHeightCm});

  final String? plantId;

  /// Si se indica un punto del plano, es una medición de prueba en otro lugar:
  /// sirve para el mapa de luz pero no cambia la luz actual de la planta.
  final double? probeX;
  final double? probeY;

  /// Altura del punto de prueba, en cm desde el piso.
  final double? probeHeightCm;

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> {
  static const double _seconds = 5;

  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _plantId;
  LightSource _source = LightSource.sun;
  double _lux = 0;
  bool _saturated = false;
  bool _manual = false;
  bool _showNumbers = false;
  bool _holding = false;
  MeasureError? _error;
  MeasureSession? _session;

  /// Instante en que se tomó la medición que está en pantalla. El resultado se
  /// calcula y se guarda con esta hora, no con la hora de guardar.
  DateTime? _capturedAt;

  bool get _probe => widget.probeX != null && widget.probeY != null;

  @override
  void initState() {
    super.initState();
    final plants = ref.read(storeProvider).plants;
    _plantId = widget.plantId ?? (plants.isNotEmpty ? plants.first.id : null);
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ medición

  Future<void> _start({required bool hold}) async {
    if (_phase == _Phase.measuring) return;
    final store = ref.read(storeProvider);

    if (Platform.isIOS && !store.settings.primersShown.contains(PrimerKind.camera.name)) {
      final go = await showPrimer(context, PrimerKind.camera);
      if (!mounted) return;
      if (!go) {
        setState(() {
          _phase = _Phase.failed;
          _error = MeasureError.noPermission;
        });
        return;
      }
    }

    final session = MeasureSession(
      seconds: _seconds,
      cameraCalibration: store.settings.cameraCalibration,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    setState(() {
      _phase = _Phase.measuring;
      _progress = 0;
      _holding = hold;
      _showNumbers = false;
      _session = session;
    });

    final outcome = await session.run();
    if (!mounted || _session != session) return; // se canceló o empezó otra
    _session = null;

    final m = outcome.value;
    if (m == null) {
      setState(() {
        _phase = _Phase.failed;
        _error = outcome.error ?? MeasureError.failed;
      });
      return;
    }
    setState(() {
      _capturedAt = DateTime.now();
      _lux = m.lux;
      _saturated = m.saturated;
      _manual = false;
      _phase = m.saturated ? _Phase.saturated : _Phase.result;
    });
  }

  void _onHoldEnd() {
    if (_phase == _Phase.measuring && _holding) {
      _session?.cancel();
      _session = null;
      setState(() => _phase = _Phase.idle);
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('measure.released'))));
    }
  }

  void _setManual(LightCategory category) {
    setState(() {
      _capturedAt = DateTime.now();
      _lux = LightModel.manualLux(category);
      _saturated = false;
      _manual = true;
      _phase = _Phase.result;
    });
  }

  void _reset() => setState(() {
        _phase = _Phase.idle;
        _error = null;
        _showNumbers = false;
      });

  DliEstimate _estimate() {
    final store = ref.read(storeProvider);
    final st = store.settings;
    final now = _capturedAt ?? DateTime.now();
    final lon = st.longitude;
    final solar = lon != null
        ? SunEngine.solarHour(now.toUtc(), lon)
        : now.hour + now.minute / 60;
    final plant = store.plantById(_plantId);
    return LightModel.estimate(
      lux: _lux,
      source: _source,
      latitude: st.latitude ?? 40,
      dayOfYear: SunEngine.dayOfYear(now),
      solarHour: solar,
      earlierPeaksToday: _plantId == null || _manual || _probe
          ? const []
          : store.peaksOfDay(_plantId!, now),
      artificialHours: (plant?.lampHours ?? 12).toDouble(),
    );
  }

  void _save() {
    final plantId = _plantId;
    final store = ref.read(storeProvider);
    final plant = store.plantById(plantId);
    if (plantId == null || plant == null) return;
    final e = _estimate();
    store.addReading(Reading(
      id: newId(),
      plantId: plantId,
      at: _capturedAt ?? DateTime.now(),
      lux: _lux,
      source: _source.name,
      ppfd: e.ppfd,
      dli: e.dli,
      // Se guarda el pico de esta medición sola; el promedio del día se
      // vuelve a calcular con peaksOfDay.
      peakPpfd: e.measurementPeak,
      sunFraction: e.sunFraction,
      x: _probe ? widget.probeX : plant.x,
      y: _probe ? widget.probeY : plant.y,
      saturated: _saturated,
      manual: _manual,
      probe: _probe,
      heightCm: _probe ? (widget.probeHeightCm ?? plant.heightCm) : plant.heightCm,
    ));
    final s = ref.read(stringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('measure.saved'))));
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _pickPlant() async {
    final store = ref.read(storeProvider);
    final content = ref.read(contentProvider);
    final s = ref.read(stringsProvider);
    final picked = await showModalBottomSheet<String>(
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
                selected: p.id == _plantId,
                onTap: () => Navigator.of(ctx).pop(p.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _plantId || !mounted) return;
    if (_phase == _Phase.measuring) {
      // La sesión en curso pertenece a la planta anterior: se corta y hay que
      // empezar otra en el lugar de la nueva.
      _session?.cancel();
      _session = null;
      setState(() {
        _plantId = picked;
        _phase = _Phase.idle;
        _capturedAt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('measure.plant_changed'))));
      return;
    }
    final hadResult = _phase == _Phase.result || _phase == _Phase.saturated;
    setState(() {
      _plantId = picked;
      // Una medición pertenece al lugar donde se tomó: con otra planta hay que
      // volver a medir.
      if (hadResult) {
        _phase = _Phase.idle;
        _capturedAt = null;
        _showNumbers = false;
      }
    });
    if (hadResult) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('measure.plant_changed'))));
    }
  }

  Future<void> _askLocation() async {
    final saved = await askLocation(context, ref);
    if (saved && mounted) setState(() {});
  }

  // ------------------------------------------------------------ pantalla

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final plant = store.plantById(_plantId);
    final hasResult = _phase == _Phase.result || _phase == _Phase.saturated;
    final category = LightModel.category(_lux);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('measure.title'), style: displayStyle(24)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: s.t('common.close'),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            _plantChip(s, store, content, plant),
            if (_probe)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppCard(
                  color: MC.sage,
                  child: Text(s.t('measure.probe_note'), style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ),
            const SizedBox(height: 14),
            LightDial(
              fraction: _phase == _Phase.saturated
                  ? 1
                  : (_phase == _Phase.result ? LightModel.dialFraction(_lux) : 0),
              labels: [
                s.t('measure.cat.shade'),
                s.t('measure.zone.low'),
                s.t('measure.zone.bright'),
                s.t('measure.cat.direct'),
              ],
              highlight: hasResult ? category.index : null,
              semanticsLabel: hasResult ? s.t(_catKey(category)) : s.t('measure.idle'),
            ),
            const SizedBox(height: 12),
            ..._phaseBody(s, store, content, plant, category),
          ],
        ),
      ),
    );
  }

  String _catKey(LightCategory c) {
    switch (c) {
      case LightCategory.shade:
        return 'measure.cat.shade';
      case LightCategory.lowIndirect:
        return 'measure.cat.low';
      case LightCategory.brightIndirect:
        return 'measure.cat.bright';
      case LightCategory.direct:
        return 'measure.cat.direct';
    }
  }

  String _subKey(LightCategory c) {
    switch (c) {
      case LightCategory.shade:
        return 'measure.sub.shade';
      case LightCategory.lowIndirect:
        return 'measure.sub.low';
      case LightCategory.brightIndirect:
        return 'measure.sub.bright';
      case LightCategory.direct:
        return 'measure.sub.direct';
    }
  }

  Widget _plantChip(AppStrings s, AppStore store, Content content, PlantItem? plant) {
    if (plant == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('measure.no_plants'), style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => context.push('/plants/add'),
              child: Text(s.t('measure.add_plant')),
            ),
          ],
        ),
      );
    }
    final room = store.roomById(plant.roomId);
    final label = plantName(plant, content, s.lang) + (room == null ? '' : ' · ${room.name}');
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const LeafGlyph(size: 20),
        label: Text(label),
        onPressed: _pickPlant,
        backgroundColor: MC.card,
        side: const BorderSide(color: MC.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }

  List<Widget> _phaseBody(
    AppStrings s,
    AppStore store,
    Content content,
    PlantItem? plant,
    LightCategory category,
  ) {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.measuring:
        return _idleBody(s);
      case _Phase.result:
        return _resultBody(s, store, content, plant, category);
      case _Phase.saturated:
        return _saturatedBody(s, plant);
      case _Phase.failed:
        return _failedBody(s);
    }
  }

  // ---- esperando o midiendo

  List<Widget> _idleBody(AppStrings s) {
    final measuring = _phase == _Phase.measuring;
    return [
      Center(
        child: Text(
          measuring ? s.t('measure.measuring') : s.t('measure.idle'),
          style: displayStyle(26),
        ),
      ),
      const SizedBox(height: 16),
      if (!measuring) ...[
        Text(s.t('measure.source'), style: const TextStyle(color: MC.muted, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final src in LightSource.values)
              ChoiceChip(
                label: Text(s.t('measure.src.${src.name}')),
                selected: _source == src,
                selectedColor: MC.sage,
                backgroundColor: MC.card,
                onSelected: (_) => setState(() => _source = src),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
      _holdButton(s, measuring),
    ];
  }

  Widget _holdButton(AppStrings s, bool measuring) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: s.t('measure.hold'),
          onTap: () => _start(hold: false),
          child: GestureDetector(
            onLongPressStart: (_) => _start(hold: true),
            onLongPressEnd: (_) => _onHoldEnd(),
            child: SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: MC.card,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x2226302A), blurRadius: 14, offset: Offset(0, 6))],
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: CircularProgressIndicator(
                      value: measuring ? _progress : 0,
                      strokeWidth: 6,
                      backgroundColor: MC.sand,
                      valueColor: const AlwaysStoppedAnimation<Color>(MC.olive),
                    ),
                  ),
                  const Icon(Icons.wb_sunny_outlined, size: 34, color: MC.ink),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.t('measure.hold'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          s.t('measure.hold_hint', {'s': _seconds.toInt()}),
          style: const TextStyle(color: MC.muted, fontSize: 12),
        ),
        if (!measuring) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _start(hold: false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: const BorderSide(color: MC.line, width: 1.5),
            ),
            child: Text(s.t('measure.or_tap', {'s': _seconds.toInt()})),
          ),
        ],
      ],
    );
  }

  // ---- resultado

  List<Widget> _resultBody(
    AppStrings s,
    AppStore store,
    Content content,
    PlantItem? plant,
    LightCategory category,
  ) {
    final e = _estimate();
    final species = plant == null ? null : content.speciesById(plant.speciesId);
    final hasLocation = store.settings.latitude != null;

    String? verdictText;
    // Solo hay veredicto si la lectura permite estimar el día: con el sol muy
    // bajo (o de noche) la proyección no es confiable.
    if (species != null &&
        !species.isUnknown &&
        plant != null &&
        !_saturated &&
        !_manual &&
        e.measuredAtGoodTime) {
      final v = LightModel.verdict(e.dli, species.dliMin, species.dliMax);
      final key = v == LightVerdict.low
          ? 'measure.verdict.low'
          : (v == LightVerdict.ok ? 'measure.verdict.ok' : 'measure.verdict.high');
      verdictText = s.t(key, {'name': plantName(plant, content, s.lang)});
    }

    final hoursText = e.artificial
        ? s.t('measure.photoperiod', {'h': s.number(e.equivalentHours, digits: 0)})
        : s.t('measure.hours_eq', {'h': s.number(e.equivalentHours)});
    final confKey = switch (e.confidence) {
      Confidence.low => 'measure.conf.low',
      Confidence.medium => 'measure.conf.medium',
      Confidence.high => 'measure.conf.high',
    };

    return [
      Center(child: Text(s.t(_catKey(category)), style: displayStyle(28), textAlign: TextAlign.center)),
      const SizedBox(height: 2),
      Center(
        child: Text(
          _manual ? '${s.t(_subKey(category))} · ${s.t('measure.manual_note')}' : s.t(_subKey(category)),
          style: const TextStyle(color: MC.muted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 16),
      if (verdictText != null && species != null)
        AppCard(
          child: Row(
            children: [
              const RomuFace(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictText,
                      style: displayStyle(18).copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.t('measure.range', {
                        'min': s.number(species.dliMin, digits: 0),
                        'max': s.number(species.dliMax, digits: 0),
                      }),
                      style: const TextStyle(color: MC.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Tag(hoursText),
        Tag(s.t(confKey), background: MC.sage),
      ]),
      const SizedBox(height: 8),
      if (!e.artificial)
        Text(s.t('measure.day_length', {'h': s.number(e.dayLength)}),
            style: const TextStyle(color: MC.muted, fontSize: 13)),
      if (!e.measuredAtGoodTime)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(s.t('measure.best_time'), style: const TextStyle(color: MC.terraDark, fontSize: 13)),
        ),
      if (!hasLocation)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(s.t('measure.no_location'), style: const TextStyle(color: MC.muted, fontSize: 13)),
              ),
              TextButton(onPressed: _askLocation, child: Text(s.t('measure.set_location'))),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: () => setState(() => _showNumbers = !_showNumbers),
        icon: Icon(_showNumbers ? Icons.expand_less : Icons.expand_more),
        label: Text(_showNumbers ? s.t('measure.numbers_hide') : s.t('measure.numbers_show')),
      ),
      if (_showNumbers)
        Row(
          children: [
            _stat(s.t('measure.lux'), s.number(_lux, digits: 0)),
            const SizedBox(width: 8),
            _stat('PPFD', s.number(e.ppfd, digits: 0)),
            const SizedBox(width: 8),
            _stat('DLI', s.number(e.dli)),
          ],
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: plant == null ? null : _save,
        child: Text(s.t('measure.save')),
      ),
      const SizedBox(height: 6),
      TextButton(onPressed: _reset, child: Text(s.t('measure.again'))),
    ];
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: MC.sand.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: MC.muted, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ---- sensor al máximo

  List<Widget> _saturatedBody(AppStrings s, PlantItem? plant) {
    return [
      Center(child: Text(s.t('measure.sat.title'), style: displayStyle(26), textAlign: TextAlign.center)),
      const SizedBox(height: 4),
      Center(
        child: Text(
          s.t('measure.sat.body'),
          style: const TextStyle(color: MC.muted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 16),
      AppCard(child: Text(s.t('measure.sat.tip'), style: const TextStyle(fontSize: 14, height: 1.4))),
      const SizedBox(height: 14),
      const RomuFace(size: 38),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: plant == null ? null : _save,
        child: Text(s.t('measure.sat.save')),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _reset, child: Text(s.t('measure.sat.retry'))),
    ];
  }

  // ---- no se pudo medir

  List<Widget> _failedBody(AppStrings s) {
    final noSensor = _error == MeasureError.noSensor;
    final noPermission = _error == MeasureError.noPermission;
    final body = noSensor
        ? s.t('measure.fail.nosensor')
        : (noPermission ? s.t('measure.fail.nopermission') : s.t('measure.fail.body'));
    final categories = [
      (LightCategory.shade, 'measure.cat.shade'),
      (LightCategory.lowIndirect, 'measure.cat.low'),
      (LightCategory.brightIndirect, 'measure.cat.bright'),
      (LightCategory.direct, 'measure.cat.direct'),
    ];
    return [
      Center(child: Text(s.t('measure.fail.title'), style: displayStyle(26), textAlign: TextAlign.center)),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF3A453E))),
      if (!noSensor && !noPermission) ...[
        const SizedBox(height: 12),
        for (final (i, key) in ['measure.fail.tip1', 'measure.fail.tip2', 'measure.fail.tip3'].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: MC.olive,
                    child: Text('${i + 1}', style: const TextStyle(color: MC.card, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.t(key), style: const TextStyle(fontSize: 14, height: 1.35))),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: 10),
      Text(s.t('measure.fail.manual'), style: const TextStyle(color: MC.muted, fontSize: 14)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
        children: [
          for (final (category, key) in categories)
            OutlinedButton(
              onPressed: () => _setManual(category),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: MC.line, width: 1.5)),
              child: Text(s.t(key), textAlign: TextAlign.center),
            ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _reset, child: Text(s.t('common.retry'))),
    ];
  }
}
