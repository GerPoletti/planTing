// Flujos de la segunda auditoría QA. Algunos usan tiempo real (sesión de 5 s):
// se corren aparte con `flutter test test_extra`.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plantapp/app/providers.dart';
import 'package:plantapp/app/router.dart';
import 'package:plantapp/app/strings.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/features/discover/species_screen.dart';
import 'package:plantapp/features/garden/garden_screen.dart';
import 'package:plantapp/features/measure/measure_screen.dart';
import 'package:plantapp/features/placement/where_screen.dart';
import 'package:plantapp/ui/theme.dart';

void main(){
  late Content content;late Map<String,Map<String,String>> strings;
  late AppStore store;late Directory dir;late String id;late AppStrings s;
  bool sensorStarted=false;
  setUpAll(()async{
    Map<String,dynamic> read(String f)=>jsonDecode(File('assets/data/$f.json').readAsStringSync()) as Map<String,dynamic>;
    content=Content.fromJson(species:read('species'),pests:read('pests'),consultorio:read('consultorio'));
    strings={for(final lang in ['es','es_AR','it'])lang:(jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String,dynamic>).map((k,v)=>MapEntry(k,v as String))};
    s=AppStrings.forLocale(const Locale('es','ES'),strings);await initializeDateFormatting('es');
  });
  Future<void> prepare(WidgetTester tester)async{
    dir=Directory.systemTemp.createTempSync('mirasol_flow_');store=(await tester.runAsync(()=>AppStore.open(directory:dir)))!;
    final room=store.addRoom(name:'Habitacion',exterior:false,w:5,h:4);store.addWindow(room);
    id=store.addPlant(speciesId:'monstera_deliciosa',nickname:'Primera',x:2,y:1).id;
    store.updateSettings((st){st.onboardingDone=true;st.latitude=89;st.longitude=0;st.languageCode='es_ES';});
    await tester.runAsync(()=>store.flush());await tester.binding.setSurfaceSize(const Size(390,844));
  }
  Widget scope(Widget app)=>ProviderScope(overrides:[storeProvider.overrideWith((ref)=>store),contentProvider.overrideWithValue(content),allStringsProvider.overrideWithValue(strings),weatherProvider.overrideWith((ref)async=>null)],child:app);
  Widget app(Widget child)=>scope(MaterialApp(theme:buildTheme(),locale:const Locale('es','ES'),supportedLocales:supportedAppLocales,localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],home:child));
  Future<void> cleanup(WidgetTester tester)async{
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(()async{if(dir.existsSync())await dir.delete(recursive:true);});
    await tester.binding.setSurfaceSize(null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('mirasol_light/method'),null);
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(const EventChannel('mirasol_light/lux'),null);
  }
  void mockSensor(WidgetTester tester){
    sensorStarted=false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('mirasol_light/method'),(call)async{
      if(call.method=='sensorInfo')return {'available':true,'maxRange':100000.0};return null;
    });
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(const EventChannel('mirasol_light/lux'),MockStreamHandler.inline(onListen:(arguments,events){sensorStarted=true;events.success(5000.0);events.success(5000.0);events.success(5000.0);}));
  }
  Future<void> startMeasure(WidgetTester tester)async{
    await tester.ensureVisible(find.text(s.t('measure.or_tap',{'s':5})));
    await tester.pump();
    await tester.tap(find.text(s.t('measure.or_tap',{'s':5})));await tester.pump();await tester.pump(const Duration(milliseconds:100));
    expect(find.text(s.t('measure.measuring')),findsOneWidget);
    await tester.pump();
    expect(sensorStarted,isTrue,reason:'se activo el flujo de sensor simulado');
  }
  Future<void> finishMeasure(WidgetTester tester)async{
    // MeasureSession calcula progreso con DateTime.now: avanzar solo el reloj
    // simulado del test no hace pasar esos cinco segundos de reloj real.
    await tester.runAsync(()=>Future<void>.delayed(const Duration(seconds:6)));
    await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();
    final scroll=tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    for(var i=0;i<8;i++){scroll.jumpTo(scroll.maxScrollExtent);await tester.pumpAndSettle();}
  }
  testWidgets('FLOW01 fallo de guardado sigue visible al abrir ficha',(tester)async{
    await prepare(tester);store.saveFailed=true;final router=buildRouter(store);
    try{
      await tester.pumpWidget(scope(MaterialApp.router(theme:buildTheme(),locale:const Locale('es','ES'),supportedLocales:supportedAppLocales,localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],routerConfig:router)));await tester.pumpAndSettle();
      expect(find.text(s.t('save.failed_banner')),findsOneWidget);
      router.push('/plant/$id');await tester.pumpAndSettle();
      expect(find.text(s.t('save.failed_banner')).hitTestable(),findsOneWidget);
    }finally{await cleanup(tester);router.dispose();}
  });
  testWidgets('FLOW02 desconocida no muestra rango numerico inventado',(tester)async{
    await prepare(tester);store.updatePlant(store.plantById(id)!, (p)=>p.speciesId='desconocida');
    await tester.runAsync(()=>store.flush());
    try{
      await tester.pumpWidget(app(WhereScreen(plantId:id)));await tester.pumpAndSettle();
      expect(find.text(s.t('where.needs',{'min':s.number(4,digits:0),'max':s.number(15,digits:0)})),findsNothing);
    }finally{await cleanup(tester);}
  });
  testWidgets('FLOW03 planta aerea no muestra frecuencia generica de tierra',(tester)async{
    await prepare(tester);
    try{
      await tester.pumpWidget(app(const SpeciesScreen(speciesId:'tillandsia')));await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first,const Offset(0,-400));await tester.pumpAndSettle();
      final days=content.speciesById('tillandsia')!.waterDays;
      expect(find.text(s.t('species.water_value',{'n':days})),findsNothing);
    }finally{await cleanup(tester);}
  });
  testWidgets('FLOW04 lectura solar con dia polar sin sol no aconseja luz',(tester)async{
    await prepare(tester);mockSensor(tester);
    try{
      await tester.pumpWidget(app(MeasureScreen(plantId:id)));await tester.pumpAndSettle();await startMeasure(tester);
      await finishMeasure(tester);
      expect(find.text(s.t('measure.save')),findsOneWidget,reason:'se obtuvo resultado de la sesion simulada');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);await tester.pumpAndSettle();
      final verdicts=['low','ok','high'].map((v)=>s.t('measure.verdict.$v',{'name':'Primera'}));
      for(final text in verdicts){expect(find.text(text),findsNothing);}
    }finally{await cleanup(tester);}
  });
  testWidgets('FLOW05 cambiar de planta durante medicion exige nueva sesion',(tester)async{
    await prepare(tester);store.addPlant(speciesId:'monstera_deliciosa',nickname:'Segunda',x:3,y:2);mockSensor(tester);
    await tester.runAsync(()=>store.flush());
    try{
      await tester.pumpWidget(app(MeasureScreen(plantId:id)));await tester.pumpAndSettle();await startMeasure(tester);
      await tester.ensureVisible(find.byType(ActionChip).first);await tester.pump();
      await tester.tap(find.byType(ActionChip).first);await tester.pump();await tester.pump(const Duration(milliseconds:300));
      await tester.tap(find.text('Segunda'));await tester.pump();await tester.pump(const Duration(milliseconds:300));
      await finishMeasure(tester);
      expect(find.text(s.t('measure.save')),findsNothing,reason:'resultado de Primera no debe ofrecerse para Segunda');
    }finally{await cleanup(tester);}
  });
  testWidgets('FLOW06 buscador encuentra apodo sin acento en coleccion de 20',(tester)async{
    await prepare(tester);
    for(var i=0;i<19;i++){store.addPlant(speciesId:'monstera_deliciosa',nickname:i==0?'Árbol especial':'Ejemplar $i',x:2,y:1);}
    await tester.runAsync(()=>store.flush());
    try{
      await tester.pumpWidget(app(const GardenScreen()));await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first,'arbol');await tester.pumpAndSettle();
      expect(find.text('Árbol especial'),findsOneWidget);expect(find.text('Primera'),findsNothing);expect(tester.takeException(),isNull);
    }finally{await cleanup(tester);}
  });
}
