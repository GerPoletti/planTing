// Escala de la segunda auditoría QA. Las mediciones son de 2025: se fija `now`
// para que sigan vigentes (las de más de un año no calibran).
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/engine/light_map.dart';
import 'package:plantapp/engine/placement.dart';

void main(){
  final species=Species({'id':'qa','scientific':'QA','names':{'es':['QA'],'it':['QA']},'place':'both','dliMin':4,'dliMax':30,'waterDays':7,'tempMin':12,'humidityMin':40});
  for(final dimensions in [(4.0,3.0),(12.0,8.0),(30.0,20.0),(100.0,100.0)]){
    test('PERF ubicaciones jardin ${dimensions.$1}x${dimensions.$2}',(){
      final r=Room(id:'r',name:'Jardin',kind:RoomKind.garden,w:dimensions.$1,h:dimensions.$2);
      final watch=Stopwatch()..start();final map=LightMap(rooms:[r],readings:[],northOffset:180,latitude:45,dayOfYear:172);
      final result=PlacementEngine.suggest(map:map,species:species);watch.stop();
      expect(result.options,isNotEmpty);
      print('QA_PERF ${jsonEncode({'scenario':'garden','width_m':dimensions.$1,'height_m':dimensions.$2,'elapsed_ms':watch.elapsedMicroseconds/1000,'candidate_cells':(dimensions.$1*dimensions.$2*4).round()})}');
    });
  }
  for(final n in [100,1000,5000]){
    test('PERF calibracion con $n observaciones historicas',(){
      final r=Room(id:'r',name:'Jardin',kind:RoomKind.garden,w:4,h:3);
      final readings=[for(var i=0;i<n;i++)Reading(id:'$i',plantId:'p',at:DateTime(2025,1,1).add(Duration(minutes:31*i)),lux:5000,source:'sun',ppfd:92.5,dli:5,peakPpfd:92.5,sunFraction:1,x:2,y:1)];
      final watch=Stopwatch()..start();final map=LightMap(rooms:[r],readings:readings,northOffset:180,latitude:45,dayOfYear:172,now:DateTime(2025,6,1));watch.stop();
      expect(map.readingsIn('r'),n);
      print('QA_PERF ${jsonEncode({'scenario':'calibration','readings':n,'elapsed_ms':watch.elapsedMicroseconds/1000})}');
    });
  }
}
