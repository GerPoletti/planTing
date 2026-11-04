import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../../engine/light_map.dart';
import '../../ui/dialogs.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Edita un ambiente del plano: nombre, tamaño, clima y ventanas.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  late final TextEditingController _name;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _temp;
  late final TextEditingController _hum;
  bool _exterior = false;

  @override
  void initState() {
    super.initState();
    final room = ref.read(storeProvider).roomById(widget.roomId);
    _name = TextEditingController(text: room?.name ?? '');
    _x = TextEditingController(text: plainNum(room?.x ?? 0));
    _y = TextEditingController(text: plainNum(room?.y ?? 0));
    _w = TextEditingController(text: plainNum(room?.w ?? 4));
    _h = TextEditingController(text: plainNum(room?.h ?? 3));
    _temp = TextEditingController(text: room?.temperature == null ? '' : plainNum(room!.temperature!));
    _hum = TextEditingController(text: room?.humidity == null ? '' : plainNum(room!.humidity!));
    _exterior = room?.exterior ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _x, _y, _w, _h, _temp, _hum]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final store = ref.read(storeProvider);
    final room = store.roomById(widget.roomId);
    if (room == null) return;
    final s = ref.read(stringsProvider);

    store.updateRoom(room, (r) {
      final name = _name.text.trim();
      if (name.isNotEmpty) r.name = name;
      r.exterior = _exterior;
      r.x = parseNum(_x.text) ?? r.x;
      r.y = parseNum(_y.text) ?? r.y;
      r.w = math.max(1.0, parseNum(_w.text) ?? r.w);
      r.h = math.max(1.0, parseNum(_h.text) ?? r.h);
    });
    final t = parseNum(_temp.text);
    final h = parseNum(_hum.text);
    if (t != null && (t != room.temperature || h != room.humidity)) {
      store.saveClimate(room, temperature: t, humidity: h);
    }
    // Las plantas se reubican según el nuevo tamaño y posición.
    store.replaceAllPlants();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('room.saved'))));
    context.pop();
  }

  Future<void> _delete(Room room) async {
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(
      context,
      title: s.t('room.delete'),
      body: s.t('room.delete_confirm', {'name': room.name}),
      confirmLabel: s.t('common.delete'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    ref.read(storeProvider).removeRoom(room.id);
    context.pop();
  }

  void _addWindow(Room room) {
    final s = ref.read(stringsProvider);
    final store = ref.read(storeProvider);
    final window = store.addWindow(room, name: '${s.t('window.title')} ${room.windows.length + 1}');
    store.replaceAllPlants();
    context.push('/window/${window.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final room = store.roomById(widget.roomId);
    if (room == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    return PageScaffold(
      title: s.t('room.title'),
      showBack: true,
      bottom: FilledButton(onPressed: _save, child: Text(s.t('common.save'))),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: s.t('room.name')),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.t('room.exterior')),
          value: _exterior,
          onChanged: (v) => setState(() => _exterior = v),
        ),
        SectionTitle(s.t('room.position')),
        Row(
          children: [
            Expanded(child: _numberField(_x, s.t('room.x'))),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_y, s.t('room.y'))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _numberField(_w, s.t('room.w'))),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_h, s.t('room.h'))),
          ],
        ),
        SectionTitle(s.t('room.climate')),
        Row(
          children: [
            Expanded(child: _numberField(_temp, s.t('room.temp'))),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_hum, s.t('room.humidity'))),
          ],
        ),
        if (room.climateAt != null && room.temperature != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              s.t('room.climate_saved', {
                't': s.number(room.temperature!),
                'h': room.humidity == null ? '–' : s.number(room.humidity!, digits: 0),
                'when': s.date(room.climateAt!),
              }),
              style: const TextStyle(color: MC.muted, fontSize: 13),
            ),
          ),
        SectionTitle(s.t('room.windows')),
        for (final w in room.windows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => context.push('/window/${w.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.window_outlined, color: MC.olive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          s.t('window.faces', {
                            'dir': directionName(s, windowAzimuth(w, store.settings.northOffset)),
                            'deg': windowAzimuth(w, store.settings.northOffset).round(),
                          }),
                          style: const TextStyle(color: MC.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _addWindow(room),
          icon: const Icon(Icons.add),
          label: Text(s.t('room.add_window')),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => _delete(room),
          icon: const Icon(Icons.delete_outline, color: MC.terraDark),
          label: Text(s.t('room.delete'), style: const TextStyle(color: MC.terraDark)),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: InputDecoration(labelText: label),
    );
  }
}
