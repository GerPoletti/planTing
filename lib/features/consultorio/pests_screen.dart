import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/treatments.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Catálogo de plagas con buscador.
class PestsScreen extends ConsumerStatefulWidget {
  const PestsScreen({super.key});

  @override
  ConsumerState<PestsScreen> createState() => _PestsScreenState();
}

class _PestsScreenState extends ConsumerState<PestsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final results = content.searchPests(_query, s.lang);

    return PageScaffold(
      title: s.t('pests.title'),
      showBack: true,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: MC.muted),
            hintText: s.t('pests.search'),
          ),
        ),
        const SizedBox(height: 12),
        for (final pest in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => context.push('/pest/${pest.id}'),
              child: Row(
                children: [
                  const IconBubble(background: MC.terraLight, child: Icon(Icons.bug_report_outlined, color: MC.terraDark)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pest.name(s.lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          pest.signs(s.lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Una plaga: cómo reconocerla, el plan de tratamiento y cómo prevenirla.
class PestScreen extends ConsumerStatefulWidget {
  const PestScreen({super.key, required this.pestId, this.plantId});

  final String pestId;
  final String? plantId;

  @override
  ConsumerState<PestScreen> createState() => _PestScreenState();
}

class _PestScreenState extends ConsumerState<PestScreen> {
  String? _plantId;

  @override
  void initState() {
    super.initState();
    final plants = ref.read(storeProvider).plants;
    _plantId = widget.plantId ?? (plants.isNotEmpty ? plants.first.id : null);
  }

  void _start() {
    final store = ref.read(storeProvider);
    final content = ref.read(contentProvider);
    final s = ref.read(stringsProvider);
    final id = _plantId;
    if (id == null) return;
    final t = startPestTreatment(store, content, id, widget.pestId);
    if (t == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('treatment.started_snack'))));
    context.push('/treatment/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final pest = content.pestById(widget.pestId);
    if (pest == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());

    return PageScaffold(
      title: pest.name(s.lang),
      showBack: true,
      children: [
        AppCard(
          color: MC.leaf,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('pests.recognize'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(pest.signs(s.lang), style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        ),
        SectionTitle(s.t('pests.schedule')),
        for (final task in pest.tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      s.t('pests.day', {'n': task.day}),
                      style: const TextStyle(color: MC.olive, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Text(task.text(s.lang), style: const TextStyle(fontSize: 14, height: 1.35))),
                ],
              ),
            ),
          ),
        SectionTitle(s.t('pests.prevention')),
        Text(pest.prevention(s.lang), style: const TextStyle(fontSize: 14, height: 1.45)),
        const SizedBox(height: 12),
        AppCard(
          color: MC.terraLight,
          child: Text(pest.petNote(s.lang), style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
        const SizedBox(height: 8),
        Text(s.t('pests.draft'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
        const SizedBox(height: 20),
        if (store.plants.isEmpty)
          Text(s.t('pests.no_plants'), style: const TextStyle(color: MC.muted, fontSize: 14))
        else ...[
          Text(s.t('pests.treat_in'), style: const TextStyle(color: MC.muted, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _plantId,
            items: [
              for (final p in store.plants)
                DropdownMenuItem(value: p.id, child: Text(plantName(p, content, s.lang))),
            ],
            onChanged: (v) => setState(() => _plantId = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _plantId == null ? null : _start, child: Text(s.t('pests.start'))),
        ],
      ],
    );
  }
}
