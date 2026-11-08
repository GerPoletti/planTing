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
import '../../engine/light_map.dart';
import '../../engine/watering.dart';
import '../../services/weather_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../garden/moisture_card.dart';

/// Hoy: lo que conviene hacer ahora, sin presión.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final content = ref.watch(contentProvider);
    final weather = ref.watch(weatherProvider).valueOrNull;
    final now = DateTime.now();

    final tasks = store.pendingTasks(withinDays: 0);

    final careTiles = <Widget>[];
    for (final plant in store.plants) {
      final advice = wateringAdviceFor(ref, plant);
      if (advice == null) continue;
      final name = plantName(plant, content, s.lang);
      final why = s.t('advice.why.${advice.reason.name}');
      if (advice.action == WateringAction.waterNow) {
        careTiles.add(_Ritual(
          icon: Icons.water_drop_outlined,
          title: s.t('today.water', {'name': name}),
          detail: why,
          button: s.t('moisture.water_now'),
          onPressed: () {
            store.addEvent(plant.id, CareType.water);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('moisture.watered'))));
          },
        ));
      } else if (advice.action == WateringAction.waterSoon || advice.action == WateringAction.check) {
        careTiles.add(_Ritual(
          icon: Icons.opacity_outlined,
          title: s.t('today.check_soil', {'name': name}),
          detail: why,
          button: s.t('moisture.check'),
          onPressed: () => showMoistureSheet(context, plant),
        ));
      }
    }
    final suggestion = measureSuggestions(store, limit: 1);
    if (suggestion.isNotEmpty && suggestion.first.plantId != null) {
      final plant = store.plantById(suggestion.first.plantId);
      if (plant != null) {
        careTiles.add(_Ritual(
          icon: Icons.wb_sunny_outlined,
          title: s.t('today.measure', {'name': plantName(plant, content, s.lang)}),
          detail: suggestion.first.kind == SuggestionKind.neverMeasured ? s.t('today.measure_never') : null,
          button: s.t('suggest.measure'),
          onPressed: () => context.push('/measure?plant=${plant.id}'),
        ));
      }
    }

    final count = tasks.length + careTiles.length;
    final travel = store.settings.travelUntil;
    final traveling = store.settings.travelingOn(now);

    return PageScaffold(
      title: s.t('today.title'),
      subtitle: '${s.weekday(now)} · ${s.dayMonth(now)}',
      actions: null,
      children: [
        Row(
          children: [
            Expanded(
              child: RomuSays(
                count == 0 ? s.t('today.romu_free') : s.t('today.romu_busy', {'n': count}),
              ),
            ),
            IconButton(
              tooltip: s.t('today.settings'),
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        if (traveling)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppCard(
              color: MC.sunLight,
              child: Row(
                children: [
                  const Icon(Icons.luggage_outlined, color: MC.ink),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.t('today.travel', {'date': s.date(travel!)}), style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          ),
        if (tasks.isNotEmpty) ...[
          SectionTitle(s.t('today.treatments')),
          for (final task in tasks) _taskTile(context, s, store, content, task),
        ],
        SectionTitle(s.t('today.care')),
        if (careTiles.isEmpty && tasks.isEmpty)
          Text(s.t('today.done_all'), style: const TextStyle(color: MC.muted, fontSize: 14)),
        ...careTiles,
        SectionTitle(s.t('today.weather')),
        _weatherCard(s, store.settings, weather),
      ],
    );
  }

  Widget _taskTile(BuildContext context, AppStrings s, AppStore store, Content content, PendingTask task) {
    final treatment = task.treatment;
    final pest = content.pestById(treatment.pestId);
    final plant = store.plantById(treatment.plantId);
    if (pest == null || plant == null) return const SizedBox.shrink();
    final tasks = pest.tasks;
    final text = task.task.index < tasks.length ? tasks[task.task.index].text(s.lang) : '';
    final late = task.due.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    return _Ritual(
      icon: Icons.bug_report_outlined,
      title: '${plantName(plant, content, s.lang)} · ${pest.name(s.lang)}',
      detail: late ? '$text · ${s.relativeDay(task.due)}' : text,
      alert: late,
      button: task.isFinal ? s.t('treatment.final') : s.t('common.done'),
      onPressed: () {
        if (task.isFinal) {
          context.push('/treatment/${treatment.id}');
        } else {
          store.completeTask(treatment, task.task.index);
        }
      },
    );
  }

  Widget _weatherCard(AppStrings s, Settings settings, WeatherSnapshot? weather) {
    if (settings.latitude == null || !settings.weatherEnabled || weather == null) {
      return AppCard(
        child: Text(s.t('today.weather_off'), style: const TextStyle(color: MC.muted, fontSize: 14, height: 1.4)),
      );
    }
    final today = weather.dayOf(DateTime.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weather.currentTemp != null)
            Text(
              s.t('today.weather_now', {
                't': s.number(weather.currentTemp!, digits: 0),
                'h': s.number(weather.currentHumidity ?? 0, digits: 0),
              }),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (today != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.t('today.weather_range', {
                  'min': s.number(today.min, digits: 0),
                  'max': s.number(today.max, digits: 0),
                }),
                style: const TextStyle(color: MC.muted, fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.t('today.weather_updated', {'when': s.dayMonthTime(weather.fetchedAt)}),
              style: const TextStyle(color: MC.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Weather data by Open-Meteo.com', style: TextStyle(color: MC.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Ritual extends StatelessWidget {
  const _Ritual({
    required this.icon,
    required this.title,
    required this.button,
    required this.onPressed,
    this.detail,
    this.alert = false,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String button;
  final VoidCallback onPressed;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        borderColor: alert ? MC.terracotta : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBubble(
                  background: alert ? MC.terraLight : MC.sage,
                  child: Icon(icon, color: alert ? MC.terraDark : MC.olive),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (detail != null)
                        Text(detail!, style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // El botón va debajo del texto para que nunca le quite ancho.
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
