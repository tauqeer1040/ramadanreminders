import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
void main() async {
  final prefs = await SharedPreferences.getInstance();
  print('prefs runtime type: ${prefs.runtimeType}');
}
