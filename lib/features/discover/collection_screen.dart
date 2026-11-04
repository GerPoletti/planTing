import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Colección: un álbum de especies que se desbloquean al sumar una planta.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final owned = store.plants.map((p) => p.speciesId).toSet();
    final all = List<Species>.of(content.species)
      ..sort((a, b) {
        final ua = owned.contains(a.id) ? 0 : 1;
        final ub = owned.contains(b.id) ? 0 : 1;
        if (ua != ub) return ua.compareTo(ub);
        return a.name(s.lang).compareTo(b.name(s.lang));
      });
    final count = all.where((sp) => owned.contains(sp.id)).length;

    return PageScaffold(
      title: s.t('collection.title'),
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('collection.progress', {'n': count, 'total': all.length}),
                style: displayStyle(17),
              ),
              const SizedBox(height: 8),
              SlimProgress(all.isEmpty ? 0 : count / all.length),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
          children: [
            for (final sp in all)
              _Tile(
                species: sp,
                unlocked: owned.contains(sp.id),
                lang: s.lang,
                lockedText: s.t('collection.locked'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(s.t('collection.hint'), style: const TextStyle(color: MC.muted, fontSize: 13, height: 1.4)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.species,
    required this.unlocked,
    required this.lang,
    required this.lockedText,
  });

  final Species species;
  final bool unlocked;
  final String lang;
  final String lockedText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: unlocked ? MC.card : MC.cream,
      borderColor: unlocked ? null : MC.line,
      padding: const EdgeInsets.all(8),
      onTap: () {
        if (unlocked) {
          context.push('/species/${species.id}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lockedText)));
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          unlocked
              ? const LeafGlyph(size: 40)
              : const Icon(Icons.lock_outline, size: 28, color: MC.line),
          const SizedBox(height: 8),
          Text(
            species.name(lang),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unlocked ? MC.ink : MC.muted,
            ),
          ),
        ],
      ),
    );
  }
}
