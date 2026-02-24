/// Backwards-compatibility shim.
///
/// The Tasbih feature has been moved to `lib/features/tasbih/`.
/// This file exists only so that existing imports of
/// `components/tesbihpage.dart` continue to compile without changes.
///
/// Prefer importing directly from the feature folder in new code:
///   import 'package:ramadan_app/features/tasbih/tasbih_screen.dart';
library;

export '../features/tasbih/tasbih_screen.dart';
export '../features/tasbih/model/dhikr_item.dart';
