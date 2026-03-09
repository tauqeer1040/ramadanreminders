import 'package:flutter/material.dart';
import 'lib/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.showInstantNotification("Test", "This is a test notification!");
}
