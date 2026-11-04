import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_service.dart';
import '../ui/theme.dart';
import 'providers.dart';
import 'reminder_sync.dart';
import 'router.dart';
import 'strings.dart';

/// Raíz de la app: tema, idioma, rutas y reprogramación de avisos.
class MirasolApp extends ConsumerStatefulWidget {
  const MirasolApp({super.key});

  @override
  ConsumerState<MirasolApp> createState() => _MirasolAppState();
}

class _MirasolAppState extends ConsumerState<MirasolApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final store = ref.read(storeProvider);
    _router = buildRouter(store);
    store.addListener(_scheduleSync);
    NotificationService.instance.init().then((_) => _scheduleSync());
    // El idioma del sistema se lee una vez que el árbol de widgets está listo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(systemLocaleProvider.notifier).state = ui.PlatformDispatcher.instance.locale;
    });
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.read(systemLocaleProvider.notifier).state = ui.PlatformDispatcher.instance.locale;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleSync();
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      syncReminders(
        ref.read(storeProvider),
        ref.read(contentProvider),
        ref.read(stringsProvider),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    ref.read(storeProvider).removeListener(_scheduleSync);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    return MaterialApp.router(
      title: s.t('app.name'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
