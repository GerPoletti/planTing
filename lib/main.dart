import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/strings.dart';
import 'data/content.dart';
import 'data/store.dart';
import 'services/weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.open();
  final content = await Content.load();
  final strings = await AppStrings.loadAll();
  final docs = await getApplicationDocumentsDirectory();
  final weather = WeatherService(File('${docs.path}/weather.json'));

  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWith((ref) => store),
      contentProvider.overrideWithValue(content),
      allStringsProvider.overrideWithValue(strings),
      weatherServiceProvider.overrideWithValue(weather),
    ],
    child: const MirasolApp(),
  ));
}
