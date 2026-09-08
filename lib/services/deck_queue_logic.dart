// Pure deck-queue decision logic (no Flutter/plugin dependencies).
//
// Extracted from QuranPage so the queue-behind rules are unit-testable:
//  - 1 deck/day, server is source of truth
//  - never yank cards mid-scratch
//  - full reveal advances tomorrow (server-side), never same-day
// ignore_for_file: avoid_classes_with_only_static_members

/// What QuranPage should do with a background-revalidated deck.
enum DeckSwapAction {
  /// Keep showing the current deck untouched.
  keep,

  /// Same deck, same cards: refresh metadata (queue depth) without flicker.
  refreshMetadata,

  /// Replace the displayed deck with the fetched one.
  swap,
}

/// Decides whether a freshly fetched deck replaces the displayed one.
///
/// Swap when: nothing displayed yet, same deck with changed card identity
/// (edit-regenerate), current deck untouched (no reveals yet), or current
/// deck fully revealed. Otherwise keep (user is mid-scratch).
DeckSwapAction deckSwapAction({
  required String? fetchedDeckId,
  required Set<String> fetchedCardIds,
  required String? currentDeckId,
  required Set<String> currentCardIds,
  required Set<String> revealedCardIds,
}) {
  if (currentCardIds.isEmpty) return DeckSwapAction.swap;

  final sameDeck = fetchedDeckId != null && fetchedDeckId == currentDeckId;
  if (sameDeck) {
    final idsChanged = fetchedCardIds.length != currentCardIds.length ||
        !fetchedCardIds.every(currentCardIds.contains);
    return idsChanged ? DeckSwapAction.swap : DeckSwapAction.refreshMetadata;
  }

  final untouched = currentCardIds.every((id) => !revealedCardIds.contains(id));
  if (untouched) return DeckSwapAction.swap;

  if (isDeckFullyRevealed(currentCardIds, revealedCardIds)) {
    return DeckSwapAction.swap;
  }
  return DeckSwapAction.keep;
}

/// True when every card id has been scratched (non-empty deck required).
bool isDeckFullyRevealed(Set<String> cardIds, Set<String> revealedCardIds) {
  return cardIds.isNotEmpty && cardIds.every(revealedCardIds.contains);
}
