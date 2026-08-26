import 'package:home_widget/home_widget.dart' deferred as hw;

class WidgetService {
  static const _androidPortrait = 'StreakWidgetProvider';
  static const _androidLandscape = 'StreakWidgetLandscapeProvider';

  static List<String> get _providers => [_androidPortrait, _androidLandscape];

  static Future<void> updateStreakWidget(int streak) async {
    await hw.loadLibrary();
    await hw.HomeWidget.saveWidgetData('streak', streak.toString());
    for (final name in _providers) {
      await hw.HomeWidget.updateWidget(
        androidName: name,
        name: name,
      );
    }
  }

  static Future<void> refreshWidgetBackground() async {
    await hw.loadLibrary();
    for (final name in _providers) {
      await hw.HomeWidget.updateWidget(
        androidName: name,
        name: name,
      );
    }
  }
}
