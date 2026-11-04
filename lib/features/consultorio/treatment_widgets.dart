import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Resumen de un tratamiento en curso: plaga, avance y próxima tarea.
class TreatmentSummaryTile extends ConsumerWidget {
  const TreatmentSummaryTile({super.key, required this.treatment, this.showPlant = false});

  final Treatment treatment;
  final bool showPlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final pest = content.pestById(treatment.pestId);
    if (pest == null) return const SizedBox.shrink();
    final plant = store.plantById(treatment.plantId);
    final total = treatment.tasks.length;
    final done = treatment.doneCount;
    TreatmentTask? next;
    for (final t in treatment.tasks) {
      if (t.doneAt == null) {
        next = t;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        borderColor: MC.terracotta,
        onTap: () => context.push('/treatment/${treatment.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report_outlined, color: MC.terraDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    showPlant && plant != null
                        ? '${plantName(plant, content, s.lang)} · ${pest.name(s.lang)}'
                        : pest.name(s.lang),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            SlimProgress(total == 0 ? 0 : done / total),
            const SizedBox(height: 6),
            Text(
              s.t('treatment.progress', {'done': done, 'total': total}) +
                  (next == null ? '' : ' · ${s.relativeDay(treatment.dueOf(next))}'),
              style: const TextStyle(color: MC.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
