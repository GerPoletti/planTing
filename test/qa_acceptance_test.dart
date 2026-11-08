// Pruebas de aceptación de la auditoría QA del 8 de noviembre de 2026
// (casos QA01–QA26 y controles). QA15 se adaptó a la decisión tomada: sin
// mediciones se muestran lugares para probar, pero ninguno es accionable.
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/backup.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/engine/light_map.dart';
import 'package:plantapp/engine/light_model.dart';
import 'package:plantapp/engine/placement.dart';
import 'package:plantapp/engine/watering.dart';
import 'package:plantapp/engine/sun_engine.dart';
import 'package:plantapp/services/reminders.dart';

final now = DateTime(2026, 6, 21, 12);
Species species() => Species({'id':'qa','scientific':'QA','names':{'es':['QA'],'it':['QA']},'place':'both','dliMin':1,'dliMax':30,'waterDays':7,'tempMin':12,'humidityMin':40});
Reading reading(String id, String plant, {double x=2, double y=1, double fraction=1, DateTime? at, bool manual=false, bool saturated=false}) => Reading(id:id,plantId:plant,at:at??now,lux:5000,source:'sun',ppfd:92.5,dli:5,peakPpfd:92.5,sunFraction:fraction,x:x,y:y,manual:manual,saturated:saturated);
void main() {
  late Directory dir;
  late AppStore store;
  setUp(() async { dir=await Directory.systemTemp.createTemp('mirasol_qa_'); store=await AppStore.open(directory:dir); });
  tearDown(() async { await store.flush(); store.dispose(); if(dir.existsSync()) await dir.delete(recursive:true); });
  LightMap map() => LightMap(rooms:store.rooms,readings:store.readings,northOffset:180,latitude:45,dayOfYear:172,now:now);
  void home() { final r=store.addRoom(name:'QA',exterior:false,w:5,h:4); store.addWindow(r); }

  test('QA01 borrar todo no resucita datos al reabrir', () async {
    store.addPlant(speciesId:'qa'); await store.flush();
    final reopened=await AppStore.open(directory:dir); reopened.dispose(); // genera .bak
    await store.wipe();
    final after=await AppStore.open(directory:dir);
    final count=after.plants.length; after.dispose();
    expect(count,0);
  });
  test('QA02 registrar ayer no reemplaza un riego de hoy', () {
    final p=store.addPlant(speciesId:'qa');
    store.addEvent(p.id,CareType.water,at:now);
    store.addEvent(p.id,CareType.water,at:now.subtract(const Duration(days:1)));
    expect(p.wateredAt,now);
  });
  test('QA03 deshacer preserva ultimo riego inicial', () {
    final initial=now.subtract(const Duration(days:3));
    final p=store.addPlant(speciesId:'qa',wateredAt:initial);
    final e=store.addEvent(p.id,CareType.water,at:now); store.removeEvent(e.id);
    expect(p.wateredAt,initial);
  });
  test('QA04 JSON ajeno no borra la coleccion', () async {
    store.addPlant(speciesId:'qa');
    await expectLater(Backup.restore(store,utf8.encode('{"plants":[]}')),throwsFormatException);
    expect(store.plants.length,1);
  });
  test('QA05 respaldo de version futura se rechaza', () async {
    final data=store.toJson(); data['version']=999;
    await expectLater(Backup.restore(store,utf8.encode(jsonEncode(data))),throwsFormatException);
  });
  test('QA06 respaldo valida hora del recordatorio', () {
    final data=store.toJson(); (data['settings'] as Map)['reminderHour']=99;
    expect(()=>store.validateJson(data),throwsA(anything));
  });
  test('QA07 respaldo rechaza IDs duplicados', () {
    store.addPlant(speciesId:'qa'); final data=store.toJson();
    (data['plants'] as List).add((data['plants'] as List).first);
    expect(()=>store.validateJson(data),throwsA(anything));
  });
  test('QA08 fallo de escritura no informa restauracion exitosa', () async {
    final bytes=utf8.encode(store.exportJson());
    Directory('${dir.path}/mirasol.json').createSync();
    try { await expectLater(Backup.restore(store,bytes),throwsA(anything)); }
    finally { Directory('${dir.path}/mirasol.json').deleteSync(); }
  });
  test('QA09 mover planta invalida medicion de ubicacion anterior', () {
    home(); final p=store.addPlant(speciesId:'qa',x:2,y:1);
    store.addReading(reading('m',p.id)); store.movePlant(p,4,3);
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('QA10 cambiar altura exige nueva medicion', () {
    home(); final p=store.addPlant(speciesId:'qa',x:2,y:1);
    store.addReading(reading('m',p.id)); store.updatePlant(p,(p)=>p.heightCm=190);
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('QA11 picos de lugares distintos no se mezclan', () {
    home(); final p=store.addPlant(speciesId:'qa',x:2,y:1);
    store.addReading(reading('a',p.id,at:now.subtract(const Duration(hours:1))));
    store.movePlant(p,4,3); store.addReading(reading('b',p.id,x:4,y:3));
    expect(store.peaksOfDay(p.id,now).length,1);
  });
  test('QA12 mover ambiente conserva o invalida calibracion, no la pierde en silencio', () {
    home(); final p=store.addPlant(speciesId:'qa',x:2,y:1);
    store.addReading(reading('a',p.id)); final before=map().readingsIn(store.rooms.first.id);
    store.moveRoom(store.rooms.first,x:10,y:10);
    expect(map().readingsIn(store.rooms.first.id),before);
  });
  test('QA13 medicion solar nocturna no calibra ambiente', () {
    home(); store.addReading(reading('a','p',fraction:0,at:DateTime(2026,6,21,0)));
    expect(map().readingsIn(store.rooms.first.id),0);
  });
  test('QA14 repetir mismo instante no aumenta confianza del ambiente', () {
    home(); for(var i=0;i<10;i++) { store.addReading(reading('$i','p')); }
    expect(map().readingsIn(store.rooms.first.id),1);
  });
  test('QA15 sin mediciones solo hay lugares para probar, no recomendaciones', () {
    home();
    final options=PlacementEngine.suggest(map:map(),species:species()).options;
    expect(options,isNotEmpty); // candidatos para medir
    expect(options.where((o)=>o.actionable),isEmpty);
  });
  test('QA16 especie desconocida no recibe ubicaciones especificas', () {
    home(); store.addReading(reading('a','p'));
    expect(PlacementEngine.suggest(map:map(),species:Content.unknown).options,isEmpty);
  });
  test('QA17 calendario vencido pide revisar en lugar de regar', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:now.subtract(const Duration(days:20)));
    expect(WateringEngine.advise(species:species(),plant:p,now:now).action,WateringAction.check);
  });
  test('QA18 pronostico de lluvia no anula tierra seca comprobada', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:now.subtract(const Duration(days:2)));
    final a=WateringEngine.advise(species:species(),plant:p,now:now,exterior:true,rainTodayMm:8,recentMoisture:[MoistureReading(id:'m',plantId:p.id,at:now,level:MoistureLevel.dry)]);
    expect(a.action,isNot(WateringAction.skipRain));
  });
  test('QA19 humedad con fecha futura no decide consejo actual', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:now.subtract(const Duration(days:1)));
    final a=WateringEngine.advise(species:species(),plant:p,now:now,recentMoisture:[MoistureReading(id:'m',plantId:p.id,at:now.add(const Duration(days:10)),level:MoistureLevel.dry)]);
    expect(a.action,isNot(WateringAction.waterNow));
  });
  test('QA20 lectura saturada no equivale a luz actual precisa', () {
    final p=store.addPlant(speciesId:'qa'); store.addReading(reading('m',p.id,saturated:true));
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('QA21 lectura manual no equivale a luz actual precisa', () {
    final p=store.addPlant(speciesId:'qa'); store.addReading(reading('m',p.id,manual:true));
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('QA22 respaldo no incluye fotos de una planta eliminada', () {
    final p=store.addPlant(speciesId:'qa');
    final f=File('${store.photosDir.path}/eliminada.jpg')..writeAsBytesSync([1,2,3]);
    store.addEvent(p.id,CareType.photo,photoPath:f.path); store.removePlant(p.id);
    final zip=ZipDecoder().decodeBytes(Backup.build(store));
    expect(zip.files.where((f)=>f.name.startsWith('photos/')),isEmpty);
  });
  test('QA23 humedad vieja debe pedirse de nuevo antes de decidir regar', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:now.subtract(const Duration(days:20)));
    final a=WateringEngine.advise(species:species(),plant:p,now:now,recentMoisture:[MoistureReading(id:'m',plantId:p.id,at:now.subtract(const Duration(days:4)),level:MoistureLevel.wet)]);
    expect(a.action,WateringAction.check);
  });
  test('QA24 intervalo cruza cambio horario de otono sin perder dia', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:DateTime(2026,10,24));
    final due=WateringEngine.nextDue(species:species(),plant:p,latitude:45,now:DateTime(2026,10,31));
    print('Zona local: ${DateTime(2026,10,24).timeZoneName}, ${DateTime(2026,11,1).timeZoneName}; due=$due');
    expect(due,DateTime(2026,11,1));
  });
  test('QA25 intervalo cruza cambio horario de primavera sin hora residual', () {
    final p=store.addPlant(speciesId:'qa',wateredAt:DateTime(2026,3,25));
    expect(WateringEngine.nextDue(species:species(),plant:p,latitude:45,now:DateTime(2026,3,26)),DateTime(2026,4,2));
  });
  test('QA26 recordatorio no desaparece al cruzar cambio horario', () {
    final content=Content(species:[species()],pests:[],symptoms:[]);
    store.addPlant(speciesId:'qa',wateredAt:DateTime(2026,10,24));
    final plan=planReminders(store,content,now:DateTime(2026,10,31,8));
    expect(plan.any((d)=>d.day==DateTime(2026,11,1) && d.waterings==1),isTrue);
  });

  test('CONTROL01 JSON invalido mantiene datos', () async {
    store.addPlant(speciesId:'qa');
    await expectLater(Backup.restore(store,[1,2,3,4,5]),throwsFormatException);
    expect(store.plants.length,1);
  });
  test('CONTROL02 copia ZIP conserva fotos y nombres unicode', () async {
    final p=store.addPlant(speciesId:'qa',nickname:'Árbol 🌱');
    final f=File('${store.photosDir.path}/qa.jpg')..writeAsBytesSync([1,2,3]);
    store.addEvent(p.id,CareType.photo,photoPath:f.path);
    final zip=Backup.build(store); await Backup.restore(store,zip);
    expect(store.plants.single.nickname,'Árbol 🌱');
    expect(File(store.plants.single.photoPath!).readAsBytesSync(),[1,2,3]);
  });
  test('CONTROL03 1152 combinaciones solares producen valores finitos', () {
    for(final lat in [-89.0,-66.5,-34.6,0.0,40.0,45.5,66.5,89.0]) {
      for(final day in [1,60,80,172,266,355]) {
        for(var hour=0;hour<24;hour++) {
          final e=LightModel.estimate(lux:5000,source:LightSource.sun,latitude:lat,dayOfYear:day,solarHour:hour.toDouble());
          expect(e.dli.isFinite,isTrue,reason:'$lat $day $hour');
          expect(e.dli,greaterThanOrEqualTo(0));
        }
      }
    }
  });
  test('CONTROL04 96 mapas exteriores finitos y no negativos', () {
    for(final lat in [-34.6,0.0,45.5,66.5]) {
      for(final doy in [1,80,172,355]) {
        for(final kind in [RoomKind.balcony,RoomKind.terrace,RoomKind.garden]) {
          for(final height in [0.0,190.0]) {
            final r=Room(id:'r',name:'R',kind:kind,w:4,h:3);
            final m=LightMap(rooms:[r],readings:[],northOffset:180,latitude:lat,dayOfYear:doy);
            final d=m.lightAt(2,1.5,heightCm:height);
            expect(d.isFinite && d>=0,isTrue,reason:'$lat $doy $kind $height');
          }
        }
      }
    }
  });
  test('CONTROL05 hemisferios y calendario bisiesto', () {
    expect(SunEngine.dayOfYear(DateTime(2024,12,31)),366);
    expect(WateringEngine.seasonFactor(-34,7),WateringEngine.seasonFactor(45,1));
  });
}
