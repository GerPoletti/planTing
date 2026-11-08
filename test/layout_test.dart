// Distribución de pantallas esenciales a 360 px, en tres idiomas y con texto
// al doble (auditoría QA del 8 de noviembre de 2026, hallazgo F22).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plantapp/app/providers.dart';
import 'package:plantapp/app/strings.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/features/onboarding/onboarding_screen.dart';
import 'package:plantapp/features/discover/species_screen.dart';
import 'package:plantapp/features/placement/where_screen.dart';
import 'package:plantapp/features/garden/plant_screen.dart';
import 'package:plantapp/features/today/today_screen.dart';
import 'package:plantapp/features/home/room_screen.dart';
import 'package:plantapp/ui/theme.dart';

void main() {
  late Content content;
  late Map<String,Map<String,String>> strings;
  setUpAll(() async {
    Map<String,dynamic> data(String f)=>jsonDecode(File('assets/data/$f.json').readAsStringSync()) as Map<String,dynamic>;
    content=Content.fromJson(species:data('species'),pests:data('pests'),consultorio:data('consultorio'));
    strings={for(final lang in ['es','es_AR','it']) lang:(jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String,dynamic>).map((k,v)=>MapEntry(k,v as String))};
    await initializeDateFormatting('es'); await initializeDateFormatting('it');
  });
  for(final locale in [const Locale('es','ES'),const Locale('es','AR'),const Locale('it')]) {
    for(final scale in [1.0,2.0]) {
      for(final page in ['onboarding','species','where','plant','today','room']) {
        testWidgets('LAYOUT $page ${locale.toString()} 360px texto x$scale', (tester) async {
          final dir=Directory.systemTemp.createTempSync('mirasol_layout_');
          final store=await tester.runAsync(()=>AppStore.open(directory:dir));
          final s=store!;
          final room=s.addRoom(name:'Habitación principal con ventana al jardín',exterior:false,w:5,h:4);
          s.addWindow(room);
          final plant=s.addPlant(speciesId:'monstera_deliciosa',nickname:'Monstera de la habitación',x:2,y:1);
          s.updateSettings((st){st.onboardingDone=true;st.latitude=45;st.languageCode=locale.languageCode=='it'?'it':'es_${locale.countryCode}';});
          // Vaciar la escritura antes de entrar al reloj simulado del render.
          await tester.runAsync(()=>s.flush());
          await tester.binding.setSurfaceSize(const Size(360,800));
          final Widget child=switch(page) {
            'onboarding'=>const OnboardingScreen(),
            'species'=>const SpeciesScreen(speciesId:'monstera_deliciosa'),
            'where'=>WhereScreen(plantId:plant.id),
            'plant'=>PlantScreen(plantId:plant.id),
            'today'=>const TodayScreen(),
            _=>RoomScreen(roomId:room.id),
          };
          try {
            await tester.pumpWidget(ProviderScope(overrides:[
              storeProvider.overrideWith((ref)=>s),
              contentProvider.overrideWithValue(content),
              allStringsProvider.overrideWithValue(strings),
              weatherProvider.overrideWith((ref) async=>null),
            ],child:MaterialApp(theme:buildTheme(),locale:locale,supportedLocales:supportedAppLocales,localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!),home:child)));
            await tester.pumpAndSettle();
            expect(tester.takeException(),isNull,reason:'render inicial');
            for(var i=0;i<4;i++) {
              await tester.drag(find.byType(Scrollable).first,const Offset(0,-450));
              await tester.pumpAndSettle();
              expect(tester.takeException(),isNull,reason:'scroll $i');
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(() async { if(dir.existsSync()) await dir.delete(recursive:true); });
            await tester.binding.setSurfaceSize(null);
          }
        });
      }
    }
  }
}
