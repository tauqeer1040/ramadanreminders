/// Emotion controller.
///
/// Holds the current slider value and can be extended later for persistence,
/// undo/redo, or ChangeNotifier-based state management.
class EmotionController {
  double value;

  EmotionController({this.value = 0.35});
}
