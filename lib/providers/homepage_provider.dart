import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomepageState {
  final int streakCount;
  final int totalStars;
  final bool showStreak;
  final String? mascotMessage;

  const HomepageState({
    this.streakCount = 1,
    this.totalStars = 0,
    this.showStreak = true,
    this.mascotMessage,
  });

  HomepageState copyWith({
    int? streakCount,
    int? totalStars,
    bool? showStreak,
    String? mascotMessage,
  }) {
    return HomepageState(
      streakCount: streakCount ?? this.streakCount,
      totalStars: totalStars ?? this.totalStars,
      showStreak: showStreak ?? this.showStreak,
      mascotMessage: mascotMessage ?? this.mascotMessage,
    );
  }
}

class HomepageNotifier extends StateNotifier<HomepageState> {
  HomepageNotifier() : super(const HomepageState());

  void setStreak(int count) => state = state.copyWith(streakCount: count);
  void setStars(int stars) => state = state.copyWith(totalStars: stars);
  void toggleStreak() => state = state.copyWith(showStreak: !state.showStreak);
  void setMascotMessage(String? msg) => state = state.copyWith(mascotMessage: msg);
  void animateStars() => state = state.copyWith(totalStars: state.totalStars + 0);
}

final homepageProvider = StateNotifierProvider<HomepageNotifier, HomepageState>((ref) {
  return HomepageNotifier();
});
