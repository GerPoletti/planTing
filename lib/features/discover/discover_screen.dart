import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Descubrir: Consultorio, catálogo de plagas y colección de especies.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final unlocked = store.plants.map((p) => p.speciesId).toSet().length;

    Widget entry(IconData icon, Color bubble, Color color, String title, String sub, String route) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: () => context.push(route),
          child: Row(
            children: [
              IconBubble(background: bubble, size: 52, child: Icon(icon, color: color, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: displayStyle(19)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }

    return PageScaffold(
      title: s.t('discover.title'),
      children: [
        entry(Icons.healing_outlined, MC.sage, MC.olive, s.t('discover.consultorio'),
            s.t('discover.consultorio_sub'), '/consultorio'),
        entry(Icons.bug_report_outlined, MC.terraLight, MC.terraDark, s.t('discover.pests'),
            s.t('discover.pests_sub'), '/pests'),
        entry(Icons.collections_bookmark_outlined, MC.sunLight, MC.ink, s.t('discover.collection'),
            '${s.t('discover.collection_sub')} · ${s.t('collection.progress', {'n': unlocked, 'total': content.species.length})}',
            '/collection'),
      ],
    );
  }
}
