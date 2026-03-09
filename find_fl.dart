import 'dart:io';

void main() async {
  var d = Directory(Platform.environment['APPDATA']! + '/Local/Pub/Cache/hosted/pub.dev');
  if (d.existsSync()) {
    var l = d.listSync().where((e) => e.path.contains('fl_chart')).toList();
    print(l);
  } else {
    print('no appdata local pub cache?');
    var d2 = Directory(Platform.environment['LOCALAPPDATA']! + '/Pub/Cache/hosted/pub.dev');
    if (d2.existsSync()) {
      var l2 = d2.listSync().where((e) => e.path.contains('fl_chart')).toList();
      print("LocalAppData: \$l2");
    }
  }
}
