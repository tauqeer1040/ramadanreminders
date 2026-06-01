import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidProviderName = 'StreakWidgetProvider';

  static Future<void> updateStreakWidget(int streak) async {
    await HomeWidget.saveWidgetData('streak', streak.toString());
    await HomeWidget.updateWidget(
      androidName: _androidProviderName,
      name: _androidProviderName,
    );
  }
}
