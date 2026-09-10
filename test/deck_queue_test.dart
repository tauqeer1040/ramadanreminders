import 'package:flutter_test/flutter_test.dart';
import 'package:ramadan_reflections/services/deck_queue_logic.dart';

void main() {
  group('isDeckFullyRevealed', () {
    test('empty deck is never fully revealed', () {
      expect(isDeckFullyRevealed({}, {'a'}), isFalse);
    });

    test('partial reveal is not full', () {
      expect(
        isDeckFullyRevealed({'a', 'b', 'c'}, {'a', 'b'}),
        isFalse,
      );
    });

    test('all ids revealed is full', () {
      expect(
        isDeckFullyRevealed({'a', 'b', 'c'}, {'a', 'b', 'c', 'stale'}),
        isTrue,
      );
    });
  });

  group('deckSwapAction', () {
    test('empty current deck always swaps (first paint)', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_x',
          fetchedCardIds: {'a'},
          currentDeckId: null,
          currentCardIds: {},
          revealedCardIds: {},
        ),
        DeckSwapAction.swap,
      );
    });

    test('same deck same cards refreshes metadata only (no flicker)', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_1',
          fetchedCardIds: {'a', 'b', 'c'},
          currentDeckId: 'deck_1',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {'a'},
        ),
        DeckSwapAction.refreshMetadata,
      );
    });

    test('same deck with changed ids swaps (edit-regenerate)', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_1',
          fetchedCardIds: {'a', 'b', 'd'},
          currentDeckId: 'deck_1',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {},
        ),
        DeckSwapAction.swap,
      );
    });

    test('untouched current deck swaps to newly served deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_2',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_1',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {},
        ),
        DeckSwapAction.swap,
      );
    });

    test('fully revealed deck swaps to next deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_2',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_1',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {'a', 'b', 'c'},
        ),
        DeckSwapAction.swap,
      );
    });

    test('mid-scratch deck is kept, never yanked', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_2',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_1',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {'a'},
        ),
        DeckSwapAction.keep,
      );
    });
  });

  group('launch drain adoption (claimed backlog deck)', () {
    // Drain rule: adopt the claimed deck iff the displayed deck is empty,
    // untouched, or fully revealed. Partial scratch always keeps.
    test('empty display adopts claimed deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_claimed',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: null,
          currentCardIds: {},
          revealedCardIds: {},
        ),
        DeckSwapAction.swap,
      );
    });

    test('untouched display adopts claimed deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_claimed',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_old',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {},
        ),
        DeckSwapAction.swap,
      );
    });

    test('partially scratched display ignores claimed deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_claimed',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_old',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {'a', 'b'},
        ),
        DeckSwapAction.keep,
      );
    });

    test('fully revealed display adopts claimed deck', () {
      expect(
        deckSwapAction(
          fetchedDeckId: 'deck_claimed',
          fetchedCardIds: {'x', 'y', 'z'},
          currentDeckId: 'deck_old',
          currentCardIds: {'a', 'b', 'c'},
          revealedCardIds: {'a', 'b', 'c'},
        ),
        DeckSwapAction.swap,
      );
    });
  });
}
