import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/advice.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../engine/light_assessment.dart';
import '../../services/photo_service.dart';
import '../../ui/dialogs.dart';
import '../../ui/theme.dart';
import '../../ui/verdict.dart';
import '../../ui/widgets.dart';
import '../consultorio/treatment_widgets.dart';
import '../onboarding/species_picker.dart';
import 'moisture_card.dart';

/// Ficha de una planta.
class PlantScreen extends ConsumerStatefulWidget {
  const PlantScreen({super.key, required this.plantId});

  final String plantId;

  @override
  ConsumerState<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends ConsumerState<PlantScreen> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _logEvent(String type) {
    ref.read(storeProvider).addEvent(widget.plantId, type);
  }

  void _addNote() {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    ref.read(storeProvider).addEvent(widget.plantId, CareType.note, note: text);
    _note.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _addPhoto() async {
    final s = ref.read(stringsProvider);
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.t('plant.photo_camera')),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.t('plant.photo_gallery')),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    final store = ref.read(storeProvider);
    final path = await PhotoService.pick(store, camera: camera);
    if (path == null) return;
    store.addEvent(widget.plantId, CareType.photo, photoPath: path, note: _note.text.trim());
    _note.clear();
  }

  Future<void> _deleteEvent(String eventId) async {
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(
      context,
      title: s.t('plant.event_delete'),
      body: s.t('plant.event_delete_body'),
      confirmLabel: s.t('common.delete'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    ref.read(storeProvider).removeEvent(eventId);
  }

  Future<void> _edit(PlantItem plant) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(plant: plant),
    );
  }

  Future<void> _delete(PlantItem plant) async {
    final s = ref.read(stringsProvider);
    final content = ref.read(contentProvider);
    final ok = await confirmDialog(
      context,
      title: s.t('plant.delete'),
      body: s.t('plant.delete_confirm', {'name': plantName(plant, content, s.lang)}),
      confirmLabel: s.t('common.delete'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    ref.read(storeProvider).removePlant(plant.id);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final plant = store.plantById(widget.plantId);
    if (plant == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final species = content.speciesById(plant.speciesId);
    final room = store.roomById(plant.roomId);
    final window = store.windowById(plant.windowId);
    final light = assessPlantLight(store: store, map: ref.watch(lightMapProvider), species: species, plant: plant);
    final advice = wateringAdviceFor(ref, plant);
    final treatments = store.treatmentsFor(plant.id, onlyActive: true);

    final lightValue = assessmentTag(s, light);

    return PageScaffold(
      title: plantName(plant, content, s.lang),
      subtitle: (species == null || species.isUnknown) ? null : species.scientific,
      showBack: true,
      actions: [
        IconButton(
          tooltip: s.t('plant.edit'),
          onPressed: () => _edit(plant),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      children: [
        Row(
          children: [
            const Icon(Icons.place_outlined, size: 18, color: MC.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [room?.name ?? s.t('garden.unplaced'), if (window != null) window.name].join(' · '),
                style: const TextStyle(color: MC.muted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(
                label: s.t('plant.light'),
                value: lightValue,
                detail: assessmentDetail(s, light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: s.t('plant.water'),
                value: Text(
                  advice == null ? '–' : s.relativeDay(advice.due),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: s.t('plant.pets'),
                value: (species == null || species.isUnknown)
                    ? const Text('–')
                    : (species.toxicToPets
                        ? Tag(s.t('plant.toxic_short'), color: MC.terraDark, background: MC.terraLight)
                        : Tag(s.t('plant.safe_short'), color: MC.olive, background: MC.sage)),
                detail: species == null
                    ? null
                    : species.isUnknown
                        ? s.t('species.toxic_unknown')
                        : (species.toxicToPets ? s.t('species.toxic') : s.t('species.safe')),
              ),
            ),
          ],
        ),
        if (species != null && species.isDraft)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(s.t('plant.draft_note'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
          ),
        const SizedBox(height: 14),
        if (species?.medium == 'air')
          AppCard(child: Text(s.t('plant.air_note'), style: const TextStyle(fontSize: 14, height: 1.4)))
        else
          MoistureCard(plant: plant),
        if (treatments.isNotEmpty) ...[
          SectionTitle(s.t('plant.treatments')),
          for (final t in treatments) TreatmentSummaryTile(treatment: t),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/measure?plant=${plant.id}'),
                icon: const Icon(Icons.wb_sunny_outlined),
                label: Text(s.t('plant.measure')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/consultorio?plant=${plant.id}'),
                icon: const Icon(Icons.healing_outlined),
                label: Text(s.t('plant.consult'), textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/where?plant=${plant.id}'),
          icon: const Icon(Icons.place_outlined),
          label: Text(s.t('where.from_plant')),
        ),
        SectionTitle(s.t('plant.history')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final type in [CareType.water, CareType.fertilize, CareType.repot, CareType.prune])
              ActionChip(
                label: Text(s.t('plant.event.$type')),
                onPressed: () => _logEvent(type),
                backgroundColor: MC.card,
                side: const BorderSide(color: MC.line, width: 1.5),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: s.t('plant.note_hint')),
                onSubmitted: (_) => _addNote(),
              ),
            ),
            IconButton(
              tooltip: s.t('plant.log'),
              onPressed: _addNote,
              icon: const Icon(Icons.send_outlined),
            ),
            IconButton(
              tooltip: s.t('plant.add_photo'),
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._timeline(s, store, content, plant),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => _delete(plant),
          icon: const Icon(Icons.delete_outline, color: MC.terraDark),
          label: Text(s.t('plant.delete'), style: const TextStyle(color: MC.terraDark)),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- historia

  List<Widget> _timeline(AppStrings s, AppStore store, Content content, PlantItem plant) {
    final entries = <_Entry>[];

    for (final e in store.eventsFor(plant.id)) {
      var title = s.t('plant.event.${e.type}');
      var detail = e.note;
      IconData icon;
      switch (e.type) {
        case CareType.water:
          icon = Icons.water_drop_outlined;
          if (e.note == AppStore.initialWaterNote) detail = s.t('plant.event.initial_water');
        case CareType.fertilize:
          icon = Icons.science_outlined;
        case CareType.repot:
          icon = Icons.yard_outlined;
        case CareType.prune:
          icon = Icons.content_cut;
        case CareType.photo:
          icon = Icons.photo_camera_outlined;
        case CareType.problem:
          icon = Icons.healing_outlined;
        case CareType.treatment:
          icon = Icons.bug_report_outlined;
          final parts = e.note.split(':');
          final pest = parts.length == 2 ? content.pestById(parts[1]) : null;
          final name = pest?.name(s.lang) ?? '';
          switch (parts.first) {
            case 'start':
              detail = s.t('plant.treatment.start', {'pest': name});
            case 'resolved':
              detail = s.t('plant.treatment.resolved', {'pest': name});
            case 'repeat':
              detail = s.t('plant.treatment.repeat', {'pest': name});
          }
        default:
          icon = Icons.notes;
      }
      entries.add(_Entry(e.at, icon, title, detail, e.photoPath, eventId: e.id));
    }
    for (final r in store.readingsFor(plant.id)) {
      entries.add(_Entry(
        r.at,
        Icons.wb_sunny_outlined,
        s.t('plant.event.reading'),
        s.t('plant.event.reading_detail', {'lux': s.number(r.lux, digits: 0), 'dli': s.number(r.dli)}) +
            (r.probe ? ' · ${s.t('plant.event.probe')}' : ''),
        null,
      ));
    }
    for (final m in store.moistureFor(plant.id)) {
      entries.add(_Entry(
        m.at,
        Icons.opacity_outlined,
        s.t('plant.event.moisture'),
        s.t('moisture.level.${m.level.name}'),
        null,
      ));
    }
    entries.sort((a, b) => b.at.compareTo(a.at));

    if (entries.isEmpty) {
      return [Text(s.t('plant.history_empty'), style: const TextStyle(color: MC.muted, fontSize: 14))];
    }
    return [
      for (final e in entries.take(60))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(e.icon, size: 20, color: MC.olive),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(s.dayMonth(e.at), style: const TextStyle(color: MC.muted, fontSize: 12)),
                    if (e.eventId != null)
                      IconButton(
                        tooltip: s.t('plant.event_delete'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteEvent(e.eventId!),
                        icon: const Icon(Icons.close, size: 18, color: MC.muted),
                      ),
                  ],
                ),
                if (e.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 30),
                    child: Text(e.detail, style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.35)),
                  ),
                if (e.photo != null && File(e.photo!).existsSync())
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(e.photo!), height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _Entry {
  const _Entry(this.at, this.icon, this.title, this.detail, this.photo, {this.eventId});

  /// Solo los eventos de la historia se pueden borrar.
  final String? eventId;

  final DateTime at;
  final IconData icon;
  final String title;
  final String detail;
  final String? photo;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.detail});

  final String label;
  final Widget value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: MC.muted, fontSize: 12)),
          const SizedBox(height: 4),
          value,
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: const TextStyle(color: MC.muted, fontSize: 11, height: 1.25)),
          ],
        ],
      ),
    );
  }
}

/// Hoja para cambiar el apodo y el intervalo de riego.
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.plant});

  final PlantItem plant;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final TextEditingController _nickname;
  late final TextEditingController _interval;
  late final TextEditingController _lamp;
  late final TextEditingController _height;
  late String _speciesId;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.plant.nickname);
    _interval = TextEditingController(
      text: widget.plant.careIntervalDays == null ? '' : '${widget.plant.careIntervalDays}',
    );
    _lamp = TextEditingController(
      text: widget.plant.lampHours == null ? '' : '${widget.plant.lampHours}',
    );
    _speciesId = widget.plant.speciesId;
    _height = TextEditingController(
      text: widget.plant.heightCm == null ? '' : plainNum(widget.plant.heightCm!),
    );
  }

  @override
  void dispose() {
    _nickname.dispose();
    _interval.dispose();
    _lamp.dispose();
    _height.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_interval.text.trim());
    final lamp = int.tryParse(_lamp.text.trim());
    final height = parseNum(_height.text);
    ref.read(storeProvider).updatePlant(widget.plant, (p) {
      p.nickname = _nickname.text.trim();
      p.careIntervalDays = (value == null || value < 1) ? null : value;
      p.lampHours = (lamp == null || lamp < 1 || lamp > 24) ? null : lamp;
      p.speciesId = _speciesId;
      p.heightCm = height?.clamp(0, 400).toDouble();
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final species = content.speciesById(_speciesId);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('plant.edit'), style: displayStyle(22)),
            const SizedBox(height: 14),
            TextField(
              controller: _nickname,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.t('plant.nickname')),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('plant.species')),
              subtitle: Text(species?.name(s.lang) ?? _speciesId),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showModalBottomSheet<Species>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SpeciesPicker(onSelected: (sp) => Navigator.of(ctx).pop(sp)),
                      ),
                    ),
                  );
                  if (picked != null && mounted) setState(() => _speciesId = picked.id);
                },
                child: Text(s.t('plant.species_change')),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.t('plant.interval')),
            ),
            const SizedBox(height: 6),
            Text(s.t('plant.interval_help'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35)),
            const SizedBox(height: 12),
            Text(s.t('plant.height'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final l in PlantLevel.values)
                  ChoiceChip(
                    label: Text('${s.t('level.${l.name}')} · ${l.cm.round()} cm'),
                    selected: parseNum(_height.text) == l.cm,
                    selectedColor: MC.sage,
                    backgroundColor: MC.card,
                    onSelected: (_) => setState(() => _height.text = plainNum(l.cm)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.t('plant.height_cm')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(s.t('plant.height_help'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35)),
            const SizedBox(height: 12),
            TextField(
              controller: _lamp,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.t('plant.lamp_hours')),
            ),
            const SizedBox(height: 6),
            Text(s.t('plant.lamp_help'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(s.t('common.save'))),
          ],
        ),
      ),
    );
  }
}
