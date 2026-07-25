import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidPortrait = 'StreakWidgetProvider';
  static const _androidLandscape = 'StreakWidgetLandscapeProvider';

  static List<String> get _providers => [_androidPortrait, _androidLandscape];

  static Future<void> updateStreakWidget(int streak) async {
    await HomeWidget.saveWidgetData('streak', streak.toString());
    for (final name in _providers) {
      await HomeWidget.updateWidget(
        androidName: name,
        name: name,
      );
    }
  }

  static Future<void> refreshWidgetBackground() async {
    for (final name in _providers) {
      await HomeWidget.updateWidget(
        androidName: name,
        name: name,
      );
    }
  }
}
