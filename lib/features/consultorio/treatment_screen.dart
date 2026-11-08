import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/strings.dart';
import '../../data/content.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Un tratamiento: avance, tareas con sus fechas y cierre con la revisión final.
class TreatmentScreen extends ConsumerWidget {
  const TreatmentScreen({super.key, required this.treatmentId});

  final String treatmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);

    Treatment? treatment;
    for (final t in store.treatments) {
      if (t.id == treatmentId) treatment = t;
    }
    final pest = treatment == null ? null : content.pestById(treatment.pestId);
    if (treatment == null || pest == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final plant = store.plantById(treatment.plantId);
    final total = treatment.tasks.length;
    final done = treatment.doneCount;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return PageScaffold(
      title: pest.name(s.lang),
      subtitle: plant == null ? null : plantName(plant, content, s.lang),
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  Text(
                    s.t('treatment.progress', {'done': done, 'total': total}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    s.t('treatment.started', {'when': s.dayMonth(treatment.startedAt)}),
                    style: const TextStyle(color: MC.muted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SlimProgress(total == 0 ? 0 : done / total),
            ],
          ),
        ),
        if (!treatment.active) ...[
          const SizedBox(height: 10),
          AppCard(
            color: treatment.outcome == 'resolved' ? MC.sage : MC.sunLight,
            child: Text(
              treatment.outcome == 'resolved'
                  ? s.t('treatment.ended_resolved')
                  : s.t('treatment.ended_repeat'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          RomuSays(s.t('treatment.keep_isolated')),
        ],
        const SizedBox(height: 14),
        for (final task in treatment.tasks)
          _TaskTile(
            s: s,
            store: store,
            pest: pest,
            treatment: treatment,
            task: task,
            today: today,
          ),
        const SizedBox(height: 10),
        AppCard(
          color: MC.terraLight,
          child: Text(pest.petNote(s.lang), style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
        const SizedBox(height: 8),
        Text(s.t('pests.draft'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.s,
    required this.store,
    required this.pest,
    required this.treatment,
    required this.task,
    required this.today,
  });

  final AppStrings s;
  final AppStore store;
  final Pest pest;
  final Treatment treatment;
  final TreatmentTask task;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final pestTasks = pest.tasks;
    if (task.index >= pestTasks.length) return const SizedBox.shrink();
    final text = pestTasks[task.index];
    final due = treatment.dueOf(task);
    final isDone = task.doneAt != null;
    final canComplete = treatment.active && !isDone && !due.isAfter(today);
    final isFinal = task.index == treatment.tasks.length - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        borderColor: canComplete ? MC.olive : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusDot(isDone, canComplete),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFinal)
                        Text(
                          s.t('treatment.final'),
                          style: const TextStyle(color: MC.terraDark, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      Text(
                        text.text(s.lang),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: isDone ? MC.muted : MC.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDone
                            ? s.date(task.doneAt!)
                            : '${s.t('pests.day', {'n': task.dayOffset})} · ${s.relativeDay(due)}',
                        style: const TextStyle(color: MC.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canComplete) ...[
              const SizedBox(height: 10),
              if (isFinal)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => store.completeTask(treatment, task.index, outcome: 'resolved'),
                        child: Text(s.t('treatment.resolved')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => store.completeTask(
                          treatment,
                          task.index,
                          outcome: 'repeat',
                          repeatOffsets: pest.taskOffsets,
                        ),
                        child: Text(s.t('treatment.repeat'), textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: () => store.completeTask(treatment, task.index),
                  child: Text(s.t('common.done')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusDot(bool done, bool due) {
    if (done) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: MC.olive,
        child: Icon(Icons.check, size: 15, color: MC.card),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: due ? MC.sun : Colors.transparent,
        border: Border.all(color: due ? MC.ink : MC.line, width: 2),
      ),
    );
  }
}
