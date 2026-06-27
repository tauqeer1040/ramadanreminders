import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidProviderName = 'StreakWidgetProvider';
  static const _channel = MethodChannel('com.taucity.meowmin/widget');

  static Future<void> updateStreakWidget(int streak) async {
    await HomeWidget.saveWidgetData('streak', streak.toString());
    await HomeWidget.updateWidget(
      androidName: _androidProviderName,
      name: _androidProviderName,
    );
  }

  static Future<bool> hasWidget() async {
    try {
      final count = await _channel.invokeMethod<int>('getWidgetCount');
      return (count ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }
}
