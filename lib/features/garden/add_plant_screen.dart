import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content.dart';
import '../../ui/pickers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/species_picker.dart';

/// Agrega una planta: especie, ambiente y apodo.
class AddPlantScreen extends ConsumerStatefulWidget {
  const AddPlantScreen({super.key, this.speciesId});

  final String? speciesId;

  @override
  ConsumerState<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends ConsumerState<AddPlantScreen> {
  Species? _species;
  String? _roomId;
  WateredWhen _watered = WateredWhen.unknown;
  final TextEditingController _nickname = TextEditingController();

  @override
  void initState() {
    super.initState();
    _species = ref.read(contentProvider).speciesById(widget.speciesId);
    final rooms = ref.read(storeProvider).rooms;
    if (rooms.isNotEmpty) _roomId = rooms.first.id;
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _create() {
    final store = ref.read(storeProvider);
    final room = store.roomById(_roomId);
    final species = _species;
    if (room == null || species == null) return;
    final spot = store.freeSpot(room);
    final plant = store.addPlant(
      speciesId: species.id,
      nickname: _nickname.text.trim(),
      x: spot.dx,
      y: spot.dy,
      wateredAt: wateredAtFor(_watered),
    );
    context.pushReplacement('/plant/${plant.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);

    return PageScaffold(
      title: s.t('add.title'),
      showBack: true,
      bottom: FilledButton(
        onPressed: (_species == null || _roomId == null) ? null : _create,
        child: Text(s.t('common.add')),
      ),
      children: [
        Text(s.t('add.pick'), style: const TextStyle(color: MC.muted, fontSize: 13)),
        const SizedBox(height: 8),
        SpeciesPicker(
          selectedId: _species?.id,
          onSelected: (sp) => setState(() => _species = sp),
        ),
        SectionTitle(s.t('add.room')),
        if (store.rooms.isEmpty)
          Text(s.t('add.no_rooms'), style: const TextStyle(color: MC.muted, fontSize: 14))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in store.rooms)
                ChoiceChip(
                  label: Text(r.name),
                  selected: _roomId == r.id,
                  selectedColor: MC.sage,
                  backgroundColor: MC.card,
                  onSelected: (_) => setState(() => _roomId = r.id),
                ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _nickname,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: s.t('onb.name.field')),
        ),
        SectionTitle(s.t('watered.title')),
        WateredWhenChips(value: _watered, onChanged: (w) => setState(() => _watered = w)),
      ],
    );
  }
}
