import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';

import 'package:flutter_animate/flutter_animate.dart';

import 'controller/tasbih_controller.dart';
import 'widgets/dhikr_card.dart';
import 'widgets/add_dhikr_card.dart';
import 'widgets/tasbih_watermark.dart';
import 'widgets/dhikr_dialog.dart';

/// The main Tasbih / Dhikr counter screen.
///
/// All business logic lives in [TasbihController]; this file is purely UI.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  late final TasbihController _controller;
  late final ConfettiController _confettiController;
  late final CarouselController _carouselScrollController;

  /// Cached card height from LayoutBuilder — needed by _advanceCarousel.
  double _cardH = 300;

  @override
  void initState() {
    super.initState();
    _carouselScrollController = CarouselController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _controller = TasbihController()
      ..onTargetReached = _confettiController.play
      ..onAutoAdvance = _advanceCarousel;
  }

  @override
  void dispose() {
    _carouselScrollController.dispose();
    _confettiController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Carousel auto-advance
  // ---------------------------------------------------------------------------

  void _advanceCarousel() {
    if (!mounted) return;
    final nextIndex = _controller.currentIndex + 1;
    final targetOffset = nextIndex * _cardH;

    // Animate the scroll, then update the controller index so the
    // NotificationListener's next tick picks it up too.
    if (_carouselScrollController.hasClients) {
      _carouselScrollController
          .animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubicEmphasized,
          )
          .then((_) => _controller.advanceToNext());
    } else {
      _controller.advanceToNext();
    }
  }

  void _advanceCarouselOnSwipe(int direction) {
    if (!mounted) return;
    final nextIndex = _controller.currentIndex + direction;
    if (nextIndex < 0 || nextIndex > _controller.dhikrList.length) return;

    final targetOffset = nextIndex * _cardH;

    if (_carouselScrollController.hasClients) {
      _carouselScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubicEmphasized,
      );
      _controller.setCurrentIndex(nextIndex);
    } else {
      _controller.setCurrentIndex(nextIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog / sheet helpers
  // ---------------------------------------------------------------------------

  Future<void> _openAddDialog() async {
    final result = await showDhikrDialog(context);
    if (result != null) await _controller.addDhikr(result.name, result.target);
  }

  Future<void> _openEditDialog(int index) async {
    final result = await showDhikrDialog(
      context,
      existing: _controller.dhikrList[index],
    );
    if (result != null) {
      await _controller.editDhikr(index, result.name, result.target);
    }
  }

  void _showDeleteConfirm(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tasbih'),
        content: const Text('Are you sure you want to delete this Tasbih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.deleteDhikr(index);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(int index) {
    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;
    final dhikr = _controller.dhikrList[index];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Dhikr name header
                  Text(
                    dhikr.arabic,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontFamily: 'Amiri',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dhikr.name,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Edit tile
                  _SheetTile(
                    icon: Icons.edit_rounded,
                    label: 'Edit Tasbih',
                    bgColor: const Color(0xFF1565C0), // deep blue
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      _openEditDialog(index);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Reset tile
                  _SheetTile(
                    icon: Icons.refresh_rounded,
                    label: 'Reset Counter',
                    bgColor: const Color(0xFFE65100), // deep orange
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      _controller.resetCurrent();
                    },
                  ),

                  const SizedBox(height: 10),

                  // Delete tile
                  _SheetTile(
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    bgColor: cs.error,
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(ctx);
                      _showDeleteConfirm(index);
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        final currentIndex = _controller.currentIndex;
        final dhikrList = _controller.dhikrList;

        final List<Widget> carouselChildren = [
          for (int i = 0; i < dhikrList.length; i++)
            DhikrCard(
              key: ValueKey(dhikrList[i].id),
              item: dhikrList[i],
              isActive: currentIndex == i,
              // onTap removed — handled exclusively by CarouselView.onTap
              onLongPress: () => _showOptionsSheet(i),
            ),
          AddDhikrCard(onTap: _openAddDialog),
        ];

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            // centerTitle: true,
            title: Text(
              'Tasbih',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            actions: [
              // Total Counter counting up gradually and scaling like watermark
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Center(
                  child:
                      TweenAnimationBuilder<int>(
                            key: ValueKey(
                              _controller.totalCount,
                            ), // Forces scale animation when changed
                            tween: IntTween(
                              begin: (_controller.totalCount > 0
                                  ? _controller.totalCount -
                                        (currentIndex < dhikrList.length
                                            ? dhikrList[currentIndex].count
                                            : 0)
                                  : 0),
                              end: _controller.totalCount,
                            ),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutQuart,
                            builder: (context, val, child) {
                              return Text(
                                val.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.secondary,
                                ),
                              );
                            },
                          )
                          .animate(key: ValueKey(_controller.totalCount))
                          .scale(
                            begin: const Offset(1.3, 1.3),
                            end: const Offset(1.0, 1.0),
                            duration: 400.ms,
                            curve: Curves.elasticOut,
                          ),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (currentIndex < dhikrList.length) {
                _controller.increment();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -300) {
                  // Swipe up -> Next item
                  _advanceCarouselOnSwipe(1);
                } else if (details.primaryVelocity! > 300) {
                  // Swipe down -> Previous item
                  _advanceCarouselOnSwipe(-1);
                }
              }
            },
            child: SafeArea(
              child: Stack(
                children: [
                  // ----------------------------------------------------------------
                  // Layout: carousel (65%) on top, action area (35%) below
                  // ----------------------------------------------------------------
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalH = constraints.maxHeight;
                      final carouselH = totalH * 0.55;
                      // For CarouselView.weighted with flexWeights: [5, 2, 1],
                      // the main card takes 5/8ths of the visible height.
                      // The available height is `carouselH` minus the 24px top padding.
                      final cardH = (carouselH - 24.0) * (5.0 / 8.0);
                      // Cache for use by _advanceCarousel outside LayoutBuilder.
                      _cardH = cardH;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          //
                          // const SizedBox(height: 34),

                          // --------------------------------------------------------
                          // 1. Carousel — max 65% height, each card = 50% height
                          // --------------------------------------------------------
                          SizedBox(
                            height: carouselH,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  // Recalculate which card is centred after
                                  // every scroll so the FAB always increments
                                  // the visible card, not a stale index.
                                  if (notification is ScrollEndNotification ||
                                      notification
                                          is ScrollUpdateNotification) {
                                    final offset = notification.metrics.pixels;
                                    final idx = (offset / cardH).round().clamp(
                                      0,
                                      carouselChildren.length - 1,
                                    );
                                    _controller.setCurrentIndex(idx);
                                  }
                                  return false;
                                },
                                child: CarouselView.weighted(
                                  controller: _carouselScrollController,
                                  scrollDirection: Axis.vertical,
                                  flexWeights: const <int>[5, 2, 1],
                                  itemSnapping: true,

                                  // Smart tap handler:
                                  // • tapped "Add" card → open dialog
                                  // • already focused  → increment
                                  // • not yet focused  → just navigate (scroll snaps)
                                  onTap: (tappedIndex) {
                                    if (tappedIndex == dhikrList.length) {
                                      _openAddDialog();
                                    } else if (tappedIndex ==
                                        _controller.currentIndex) {
                                      _controller.increment();
                                    } else {
                                      if (_carouselScrollController
                                          .hasClients) {
                                        final targetOffset =
                                            tappedIndex * _cardH;
                                        _carouselScrollController.animateTo(
                                          targetOffset,
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          curve:
                                              Curves.easeInOutCubicEmphasized,
                                        );
                                      }
                                      _controller.setCurrentIndex(tappedIndex);
                                    }
                                  },
                                  children: carouselChildren,
                                ),
                              ),
                            ),
                          ),

                          // --------------------------------------------------------
                          // 2. Remaining 35% — watermark + premium button
                          // --------------------------------------------------------
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Tap-to-reset watermark — bottom-left
                                if (dhikrList.isNotEmpty &&
                                    currentIndex < dhikrList.length)
                                  Positioned(
                                    bottom: 0,
                                    left: 20,
                                    child: TapToResetWatermark(
                                      count: dhikrList[currentIndex].count,
                                      onReset: (_) {
                                        _controller.resetCurrent();
                                        _confettiController.play();
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // ----------------------------------------------------------------
                  // Confetti — full-screen overlay, fires from top-centre
                  // ----------------------------------------------------------------
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                        colorScheme.tertiary,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A vibrant, pill-shaped action tile for the options bottom sheet.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
