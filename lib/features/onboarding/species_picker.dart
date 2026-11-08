import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/content.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Campo de búsqueda con la lista de especies que coinciden.
class SpeciesPicker extends ConsumerStatefulWidget {
  const SpeciesPicker({super.key, required this.onSelected, this.selectedId});

  final void Function(Species species) onSelected;
  final String? selectedId;

  @override
  ConsumerState<SpeciesPicker> createState() => _SpeciesPickerState();
}

class _SpeciesPickerState extends ConsumerState<SpeciesPicker> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final results = content.searchSpecies(_query, s.lang).take(14).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: MC.muted),
            hintText: s.t('onb.plant.search'),
          ),
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(s.t('onb.plant.empty'), style: const TextStyle(color: MC.muted, fontSize: 14)),
          ),
        for (final sp in [...results, Content.unknown])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              borderColor: sp.id == widget.selectedId ? MC.olive : null,
              color: sp.id == widget.selectedId ? MC.sage : MC.card,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => widget.onSelected(sp),
              child: Row(
                children: [
                  const LeafGlyph(size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sp.name(s.lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(
                          sp.isUnknown ? s.t('species.unknown_sub') : sp.scientific,
                          style: TextStyle(
                            fontStyle: sp.isUnknown ? FontStyle.normal : FontStyle.italic,
                            color: MC.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sp.isUnknown)
                    const Icon(Icons.help_outline, size: 20, color: MC.muted)
                  else
                    Icon(
                    sp.toxicToPets ? Icons.warning_amber_rounded : Icons.pets,
                    size: 20,
                    color: sp.toxicToPets ? MC.terraDark : MC.olive,
                    semanticLabel: sp.toxicToPets ? s.t('species.toxic') : s.t('species.safe'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
