import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../services/export_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../ui/dialogs.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/primer_screen.dart';

const String appVersion = '1.0.0';

/// Ajustes de la app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _toggleReminders(bool on) async {
    final store = ref.read(storeProvider);
    final s = ref.read(stringsProvider);
    if (!on) {
      store.updateSettings((st) => st.reminderEnabled = false);
      await NotificationService.instance.cancelAll();
      return;
    }
    final go = await showPrimer(context, PrimerKind.notifications);
    if (!go || !mounted) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('settings.reminders_denied'))));
      return;
    }
    store.updateSettings((st) => st.reminderEnabled = true);
  }

  Future<void> _pickTime() async {
    final store = ref.read(storeProvider);
    final st = store.settings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: st.reminderHour, minute: st.reminderMinute),
    );
    if (picked == null) return;
    store.updateSettings((x) {
      x.reminderHour = picked.hour;
      x.reminderMinute = picked.minute;
    });
  }

  Future<void> _pickTravel() async {
    final store = ref.read(storeProvider);
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) store.updateSettings((x) => x.travelUntil = picked);
  }

  Future<void> _wipe() async {
    final s = ref.read(stringsProvider);
    final store = ref.read(storeProvider);
    final ok = await confirmDialog(
      context,
      title: s.t('settings.wipe'),
      body: s.t('settings.wipe_confirm'),
      confirmLabel: s.t('common.delete'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    await NotificationService.instance.cancelAll();
    await store.wipe();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('settings.wiped'))));
  }

  Future<void> _restore() async {
    final s = ref.read(stringsProvider);
    final store = ref.read(storeProvider);
    final bytes = await ExportService.pickBackup();
    if (bytes == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: s.t('settings.restore'),
      body: s.t('settings.restore_confirm'),
      confirmLabel: s.t('settings.restore_go'),
      cancelLabel: s.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    try {
      await Backup.restore(store, bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('settings.restored'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('settings.restore_failed'))));
    }
  }

  Future<void> _useLocation() async {
    await askLocation(context, ref);
  }

  Future<void> _searchCity() async {
    await showCitySheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(storeProvider);
    final st = store.settings;
    final time = TimeOfDay(hour: st.reminderHour, minute: st.reminderMinute).format(context);
    final travel = st.travelUntil;
    final traveling = st.travelingOn(DateTime.now());

    return PageScaffold(
      title: s.t('settings.title'),
      showBack: true,
      children: [
        SectionTitle(s.t('settings.language')),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final entry in <(String?, String)>[
                (null, s.t('settings.language.system')),
                ('es_ES', s.t('settings.language.es_ES')),
                ('es_AR', s.t('settings.language.es_AR')),
                ('it', s.t('settings.language.it')),
              ])
                RadioListTile<String?>(
                  value: entry.$1,
                  groupValue: st.languageCode,
                  title: Text(entry.$2),
                  onChanged: (v) => store.updateSettings((x) => x.languageCode = v),
                ),
            ],
          ),
        ),
        SectionTitle(s.t('settings.reminders')),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: Text(s.t('settings.reminders_on')),
                value: st.reminderEnabled,
                onChanged: _toggleReminders,
              ),
              ListTile(
                enabled: st.reminderEnabled,
                title: Text(s.t('settings.reminders_time')),
                trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: st.reminderEnabled ? _pickTime : null,
              ),
            ],
          ),
        ),
        SectionTitle(s.t('settings.travel')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                traveling ? s.t('settings.travel_until', {'date': s.date(travel!)}) : s.t('settings.travel_off'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickTravel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(s.t('settings.travel_pick')),
                  ),
                  if (traveling)
                    TextButton(
                      onPressed: () => store.updateSettings((x) => x.travelUntil = null),
                      child: Text(s.t('settings.travel_clear')),
                    ),
                ],
              ),
            ],
          ),
        ),
        SectionTitle(s.t('settings.location')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: MC.olive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      st.latitude == null
                          ? s.t('settings.location_none')
                          : (st.placeName ?? s.t('onb.loc.approx')),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: _useLocation,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(s.t('settings.location_use')),
                  ),
                  OutlinedButton(
                    onPressed: _searchCity,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(s.t('settings.location_city')),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('settings.weather')),
                value: st.weatherEnabled,
                onChanged: (v) => store.updateSettings((x) => x.weatherEnabled = v),
              ),
              Text(
                s.t('settings.weather_note'),
                style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        if (Platform.isIOS) ...[
          SectionTitle(s.t('settings.camera')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('×${s.number(st.cameraCalibration, digits: 2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: st.cameraCalibration.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  onChanged: (v) => store.updateSettings(
                    (x) => x.cameraCalibration = (v * 100).round() / 100,
                  ),
                ),
                Text(
                  s.t('settings.camera_help'),
                  style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
        SectionTitle(s.t('settings.data')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('settings.data_note'), style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 10),
              if (store.saveFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    color: MC.terraLight,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: MC.terraDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.t('settings.save_failed'), style: const TextStyle(fontSize: 13, height: 1.4)),
                        ),
                        TextButton(onPressed: store.flush, child: Text(s.t('settings.save_retry'))),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => ExportService.share(store),
                icon: const Icon(Icons.ios_share),
                label: Text(s.t('settings.export')),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore),
                label: Text(s.t('settings.restore')),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _wipe,
                icon: const Icon(Icons.delete_outline, color: MC.terraDark),
                label: Text(s.t('settings.wipe'), style: const TextStyle(color: MC.terraDark)),
              ),
            ],
          ),
        ),
        SectionTitle(s.t('settings.about')),
        Text(s.t('settings.version', {'v': appVersion}), style: const TextStyle(color: MC.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Text(s.t('settings.credits'), style: const TextStyle(color: MC.muted, fontSize: 12, height: 1.4)),
      ],
    );
  }
}

/// Hoja para buscar una ciudad y usarla como ubicación.
/// Abre la búsqueda de ciudad para cargar la ubicación a mano.
Future<void> showCitySheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CitySheet(),
    );

/// Búsqueda de ciudad: alternativa a dar permiso de ubicación.
class CitySheet extends ConsumerStatefulWidget {
  const CitySheet({super.key});

  @override
  ConsumerState<CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends ConsumerState<CitySheet> {
  final TextEditingController _controller = TextEditingController();
  List<ApproxLocation> _results = [];
  bool _busy = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    final r = await LocationService.searchPlace(_controller.text, s.lang);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _searched = true;
      _results = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('settings.location_city'), style: displayStyle(22)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(hintText: s.t('onb.loc.city_hint')),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _search,
                  style: FilledButton.styleFrom(minimumSize: const Size(80, 52)),
                  child: Text(s.t('onb.loc.search')),
                ),
              ],
            ),
            if (_searched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(s.t('onb.loc.none'), style: const TextStyle(color: MC.muted, fontSize: 14)),
              ),
            for (final r in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(r.name ?? ''),
                onTap: () {
                  saveLocation(ref, r);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
