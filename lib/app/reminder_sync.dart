import '../data/content.dart';
import '../data/store.dart';
import '../services/notification_service.dart';
import '../services/reminders.dart';
import 'strings.dart';

/// Reprograma los avisos según lo que hay pendiente. Un solo aviso por día,
/// solo los días con algo para hacer y nunca durante el modo viaje.
Future<void> syncReminders(AppStore store, Content content, AppStrings s) async {
  final service = NotificationService.instance;
  final settings = store.settings;
  if (!settings.reminderEnabled) {
    await service.cancelAll();
    return;
  }
  final plan = planReminders(store, content);
  final reminders = <ScheduledReminder>[];
  var id = 100;
  for (final day in plan) {
    final when = DateTime(
      day.day.year,
      day.day.month,
      day.day.day,
      settings.reminderHour,
      settings.reminderMinute,
    );
    final parts = <String>[
      if (day.waterings > 0) s.plural('notify.waterings', day.waterings),
      if (day.tasks > 0) s.plural('notify.tasks', day.tasks),
    ];
    reminders.add(ScheduledReminder(
      id: id++,
      when: when,
      title: s.t('notify.title'),
      body: parts.join(' · '),
    ));
  }
  await service.apply(
    reminders,
    channelName: s.t('notify.channel'),
    channelDescription: s.t('notify.channel_desc'),
  );
}
