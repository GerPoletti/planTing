// Casos de la segunda auditoría QA (límites, integridad y contexto de la evidencia).
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/backup.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/engine/light_assessment.dart';
import 'package:plantapp/engine/light_map.dart';
import 'package:plantapp/engine/placement.dart';

Species species()=>Species({'id':'qa','scientific':'QA','names':{'es':['QA'],'it':['QA']},'place':'both','dliMin':1,'dliMax':30,'waterDays':7,'tempMin':12,'humidityMin':40});
Reading reading(String id,String plant,{DateTime? at,double fraction=1,double? x=2,double? y=1,double height=75,double dli=5})=>Reading(id:id,plantId:plant,at:at??DateTime.now(),lux:5000,source:'sun',ppfd:92.5,dli:dli,peakPpfd:92.5,sunFraction:fraction,x:x,y:y,heightCm:height);
void main(){
  late AppStore store;late Directory dir;
  setUp(()async{dir=await Directory.systemTemp.createTemp('mirasol_qa2_');store=await AppStore.open(directory:dir);});
  tearDown(()async{await store.flush();store.dispose();if(dir.existsSync())await dir.delete(recursive:true);});
  Room home(){final r=store.addRoom(name:'Sala',exterior:false,w:5,h:4);store.addWindow(r);return r;}
  LightMap map()=>LightMap(rooms:store.rooms,readings:store.readings,northOffset:180,latitude:45,dayOfYear:172);
  Map<String,dynamic> data()=>jsonDecode(jsonEncode(store.toJson())) as Map<String,dynamic>;
  void rejects(Map<String,dynamic> d)=>expect(()=>store.validateJson(d),throwsFormatException);

  test('R201 lectura futura no se considera evidencia actual',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(reading('m',p.id,at:DateTime.now().add(const Duration(days:30))));
    expect(assessPlantLight(store:store,map:map(),species:species(),plant:p).verdict,isNull);
  });
  test('R202 lectura solar con fraccion nocturna no da veredicto',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(reading('m',p.id,fraction:0));
    expect(assessPlantLight(store:store,map:map(),species:species(),plant:p).verdict,isNull);
  });
  test('R203 lectura antigua sin coordenadas no prueba un lugar nuevo',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(reading('m',p.id,x:null,y:null));store.movePlant(p,4,3);
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('R204 calibracion de hace anos no habilita ubicaciones actuales',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(reading('m',p.id,at:DateTime(2020,6,21)));
    expect(PlacementEngine.suggest(map:map(),species:species()).options.where((o)=>o.actionable),isEmpty);
  });
  test('R205 alturas diferentes conservan dos observaciones independientes',(){
    final time=DateTime.now();final a=reading('a','p',at:time,height:0);final b=reading('b','p',at:time,height:190);
    expect(LightMap.independentReadings([a,b]).length,2);
  });
  test('R206 version fraccionaria no se trunca para aceptarla',(){final d=data();d['version']=1.9;rejects(d);});
  test('R207 referencia a ambiente inexistente se rechaza',(){
    store.addPlant(speciesId:'qa');final d=data();(d['plants'] as List).first['roomId']='no-existe';rejects(d);
  });
  test('R208 ventana con ancho negativo se rechaza',(){
    home();final d=data();(d['rooms'] as List).first['windows'][0]['widthCm']=-100;rejects(d);
  });
  test('R209 fecha de lectura ilegible no se reemplaza por hoy',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(reading('a',p.id));final d=data();(d['readings'] as List).first['at']='fecha rota';rejects(d);
  });
  test('R210 indice negativo de tarea se rechaza',(){
    final p=store.addPlant(speciesId:'qa');store.startTreatment(p.id,'trips',[0,7]);final d=data();(d['treatments'] as List).first['tasks'][0]['index']=-1;rejects(d);
  });
  test('R211 indices repetidos de tareas se rechazan',(){
    final p=store.addPlant(speciesId:'qa');store.startTreatment(p.id,'trips',[0,7]);final d=data();(d['treatments'] as List).first['tasks'][1]['index']=0;rejects(d);
  });
  test('R212 DLI negativo se rechaza',(){
    home();final p=store.addPlant(speciesId:'qa');store.addReading(reading('a',p.id));final d=data();(d['readings'] as List).first['dli']=-1;rejects(d);
  });
  test('R213 fuente de luz desconocida se rechaza',(){
    final p=store.addPlant(speciesId:'qa');store.addReading(reading('a',p.id));final d=data();(d['readings'] as List).first['source']='desconocido';rejects(d);
  });
  test('R214 restaurar foto con mismo nombre conserva la del respaldo',()async{
    final p=store.addPlant(speciesId:'qa');final f=File('${store.photosDir.path}/foto.jpg')..writeAsBytesSync([1,2,3]);store.addEvent(p.id,CareType.photo,photoPath:f.path);
    final zip=Backup.build(store);f.writeAsBytesSync([9,8,7]);await Backup.restore(store,zip);
    expect(File(store.plants.single.photoPath!).readAsBytesSync(),[1,2,3]);
  });
  test('R215 ZIP sin foto referenciada no informa restauracion completa',()async{
    final p=store.addPlant(speciesId:'qa');store.addEvent(p.id,CareType.photo,photoPath:'photos/falta.jpg');
    final archive=Archive();final b=utf8.encode(store.exportJson());archive.addFile(ArchiveFile('mirasol.json',b.length,b));
    await expectLater(Backup.restore(store,ZipEncoder().encode(archive)!),throwsFormatException);
  });
  test('R216 migracion recalcula riego si cache es anterior al evento',(){
    final p=store.addPlant(speciesId:'qa',wateredAt:DateTime(2026,10,1));store.addEvent(p.id,CareType.water,at:DateTime(2026,10,10));
    final d=data();(d['plants'] as List).first['wateredAt']='2026-10-01T00:00:00.000';store.loadFromJson(d);
    expect(store.plants.single.wateredAt,DateTime(2026,10,10));
  });
  test('R217 calibracion de camara cero se rechaza',(){final d=data();(d['settings'] as Map)['cameraCalibration']=0;rejects(d);});
  test('R218 obstruccion fuera del control de interfaz se rechaza',(){
    final r=store.addRoom(name:'Jardin',exterior:true,kind:RoomKind.garden);final d=data();(d['rooms'] as List).first['skyObstruction']=100;expect(r.exterior,isTrue);rejects(d);
  });
  test('R219 altura imposible de planta se rechaza',(){
    store.addPlant(speciesId:'qa');final d=data();(d['plants'] as List).first['heightCm']=99999;rejects(d);
  });
  test('R220 respaldo sin listas de historia no elimina historia silenciosamente',()async{
    final p=store.addPlant(speciesId:'qa');store.addEvent(p.id,CareType.note,note:'historia');final d=data();d.remove('events');
    await expectLater(Backup.restore(store,utf8.encode(jsonEncode(d))),throwsFormatException);
  });
  test('R221 observacion junto a pared no silencia ambiente vecino',(){
    final aRoom=store.addRoom(name:'A',exterior:false,x:0,y:0,w:2,h:3);store.addWindow(aRoom);
    final bRoom=store.addRoom(name:'B',exterior:false,x:2,y:0,w:2,h:3);store.addWindow(bRoom);
    final time=DateTime.now();final a=reading('a','p',at:time,x:1.9,y:1);final b=reading('b','q',at:time,x:2.1,y:1);
    store.addReading(a);store.addReading(b);
    expect(map().readingsIn(bRoom.id),1);
  });
  test('R223 encoger ambiente no convierte medicion de otra posicion en actual',(){
    final room=home();final p=store.addPlant(speciesId:'qa',x:4.5,y:1);store.addReading(reading('a',p.id,x:4.5,y:1));store.moveRoom(room,x:0,y:0,w:2,h:4);
    expect(store.lastPlantReading(p.id),isNull);
  });
  test('CONTROL2A luz sin mediciones no produce veredicto',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);expect(assessPlantLight(store:store,map:map(),species:species(),plant:p).verdict,isNull);
  });
  test('CONTROL2B lectura manual queda historica sin veredicto',(){
    home();final p=store.addPlant(speciesId:'qa',x:2,y:1);store.addReading(Reading(id:'m',plantId:p.id,at:DateTime.now(),lux:5000,source:'sun',ppfd:92.5,dli:5,peakPpfd:92.5,sunFraction:1,x:2,y:1,manual:true));
    expect(store.lastPlantReading(p.id),isNull);expect(store.readings.length,1);
  });
  test('CONTROL2C respaldo normal conserva datos y fotos',()async{
    final p=store.addPlant(speciesId:'qa',nickname:'Árbol 🌱');final f=File('${store.photosDir.path}/foto.jpg')..writeAsBytesSync([1,2,3]);store.addEvent(p.id,CareType.photo,photoPath:f.path);
    await Backup.restore(store,Backup.build(store));expect(store.plants.single.nickname,'Árbol 🌱');expect(File(store.plants.single.photoPath!).readAsBytesSync(),[1,2,3]);
  });
}
