import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import '../../../services/dhikr_service.dart';
import '../model/dhikr_item.dart';

export '../model/dhikr_item.dart';

/// Encapsulates all business logic for the Tasbih / Dhikr counter feature.
///
/// Extend [ChangeNotifier] so that the screen can rebuild with [ListenableBuilder]
/// whenever state changes — no third-party state management needed.
class TasbihController extends ChangeNotifier {
  TasbihController() {
    _load();
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final DhikrService _service = DhikrService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  List<DhikrItem> _dhikrList = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _totalCount = 0;

  // Expose callbacks so the screen can react to business-logic events.
  VoidCallback? onTargetReached;

  /// Called ~800 ms after the target is reached, if a next dhikr exists.
  /// The screen uses this to animate the carousel to the next card.
  VoidCallback? onAutoAdvance;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------
  List<DhikrItem> get dhikrList => List.unmodifiable(_dhikrList);
  bool get isLoading => _isLoading;
  int get currentIndex => _currentIndex;
  int get totalCount => _totalCount;
  DhikrItem? get currentItem =>
      _dhikrList.isEmpty || _currentIndex >= _dhikrList.length
      ? null
      : _dhikrList[_currentIndex];

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------
  Future<void> _load() async {
    final loaded = await _service.loadDhikrs();
    _totalCount = await _service.loadTotalDhikrCount();
    _dhikrList = loaded != null && loaded.isNotEmpty
        ? loaded
        : _defaultDhikrs();
    if (loaded == null || loaded.isEmpty) _service.saveDhikrs(_dhikrList);
    _isLoading = false;
    notifyListeners();
  }

  static List<DhikrItem> _defaultDhikrs() => [
    DhikrItem(
      id: 'subhan',
      name: 'SubhanAllah',
      arabic: 'سُبْحَانَ اللّٰهِ',
      target: 33,
    ),
    DhikrItem(
      id: 'alhamd',
      name: 'Alhamdulillah',
      arabic: 'الْحَمْدُ لِلّٰهِ',
      target: 33,
    ),
    DhikrItem(
      id: 'allahu',
      name: 'Allahu Akbar',
      arabic: 'اللّٰهُ أَكْبَرُ',
      target: 34,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Update which carousel item is currently centred.
  void setCurrentIndex(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  DateTime? _lastIncrement;

  /// Increment the counter for the currently active dhikr.
  void increment() {
    final item = currentItem;
    if (item == null) return;

    final now = DateTime.now();

    // Throttle taps when counting past the target to discourage over-counting
    // and give the auto-advance animation time to play.
    if (item.count >= item.target) {
      if (_lastIncrement != null &&
          now.difference(_lastIncrement!) <
              const Duration(milliseconds: 1500)) {
        return; // Ignore rapid taps past target
      }
    }
    _lastIncrement = now;

    HapticFeedback.lightImpact();
    item.count++;

    if (item.count == item.target) {
      HapticFeedback.heavyImpact();
      onTargetReached?.call();

      // Auto-advance to the next dhikr (or the Add card if at the end)
      if (_currentIndex < _dhikrList.length) {
        Future.delayed(const Duration(milliseconds: 100), () {
          onAutoAdvance?.call();
        });
      }
    } else if (item.count > item.target) {
      // User tapped past the target. Immediately advance.
      if (_currentIndex < _dhikrList.length) {
        onAutoAdvance?.call();
      }
    }

    _service.saveDhikrs(_dhikrList);
    notifyListeners();
  }

  /// Reset the counter for the currently active dhikr to zero,
  /// adding its count to the global total.
  void resetCurrent() {
    final item = currentItem;
    if (item == null || item.count == 0) return;

    HapticFeedback.mediumImpact();
    // Add to total tracking
    _totalCount += item.count;
    _service.saveTotalDhikrCount(_totalCount);

    item.count = 0;
    _service.saveDhikrs(_dhikrList);
    notifyListeners();
  }

  /// Move focus to the next dhikr in the list, or the Add Card.
  void advanceToNext() {
    if (_currentIndex < _dhikrList.length) {
      _currentIndex++;
      notifyListeners();
    }
  }

  /// Add a new dhikr to the list.
  Future<void> addDhikr(String name, int target) async {
    final arabicText = await _translateToArabic(name);
    _dhikrList.add(
      DhikrItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        arabic: arabicText,
        target: target,
      ),
    );
    _service.saveDhikrs(_dhikrList);
    notifyListeners();
  }

  /// Edit an existing dhikr at [index].
  Future<void> editDhikr(int index, String name, int target) async {
    final existing = _dhikrList[index];
    final arabicText = existing.name == name
        ? existing.arabic
        : await _translateToArabic(name);

    _dhikrList[index] = DhikrItem(
      id: existing.id,
      name: name,
      arabic: arabicText,
      target: target,
      count: existing.count > target ? target : existing.count,
    );
    _service.saveDhikrs(_dhikrList);
    notifyListeners();
  }

  /// Permanently remove the dhikr at [index].
  void deleteDhikr(int index) {
    HapticFeedback.mediumImpact();
    _dhikrList.removeAt(index);
    if (_currentIndex > 0 && _currentIndex >= _dhikrList.length) {
      _currentIndex = _dhikrList.length - 1;
    }
    _service.saveDhikrs(_dhikrList);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<String> _translateToArabic(String text) async {
    try {
      final translation = await GoogleTranslator().translate(text, to: 'ar');
      return translation.text;
    } catch (_) {
      return text; // graceful fallback
    }
  }
}
