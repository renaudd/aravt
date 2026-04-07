// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../services/tutorial_service.dart';
import '../widgets/grid_portrait_widget.dart';
import '../widgets/paper_panel.dart';

/// Width reserved on the right for the persistent navigation widget.
/// (Kept as reference — no longer used directly in layout.)
// ignore: unused_element
const double _kNavWidgetReservedWidth = 230.0;

/// Width of the captain bust portrait shown in the bottom-left.
/// Kept at original size — the portrait was never the problem.
const double _kPortraitSize = 110.0;

/// Max width of the speech bubble (wide enough to read comfortably, short enough
/// to never reach the nav widget even on a small iPhone in landscape).
const double _kBubbleMaxWidth = 420.0;

class TutorialOverlayWidget extends StatefulWidget {
  const TutorialOverlayWidget({super.key});

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  /// Whether the dialogue bubble is in its expanded (full-text) state.
  bool _isExpanded = false;

  /// Track previous step index so we can collapse on step change synchronously.
  int _prevStepIndex = -1;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(begin: 0, end: 15).animate(
        CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TutorialService, GameState>(
      builder: (context, tutorial, gameState, child) {
        if (!tutorial.isActive || tutorial.currentStep == null) {
          final currentTurn = gameState.turn.turnNumber;
          if (!gameState.tutorialCompleted &&
              !gameState.tutorialPermanentlyDismissed &&
              gameState.player != null &&
              gameState.tutorialStepIndex > 0 &&
              currentTurn > tutorial.lastTurnStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              tutorial.startTutorial(context, gameState);
            });
          }
          return const SizedBox.shrink();
        }

        final captain = tutorial.getTutorialCaptain(gameState);
        final step = tutorial.currentStep!;
        final isAnnoyed = gameState.tutorialDismissalCount > 0;

        // Collapse bubble synchronously when step changes (no postframe flicker).
        final currentStepIndex = gameState.tutorialStepIndex;
        if (currentStepIndex != _prevStepIndex) {
          _prevStepIndex = currentStepIndex;
          if (_isExpanded) {
            // Schedule during build is not ideal, but we avoid setState-in-build
            // by using a zero-duration future.
            Future.microtask(() {
              if (mounted) setState(() => _isExpanded = false);
            });
          }
        }


        return Stack(
          children: [
            // --- Bottom HUD Row: [Portrait (fixed left)] [Bubble (compact, right of portrait)] ---
            // Rendered FIRST so the arrow is drawn on top of it.
            // The portrait is anchored bottom-left at its full 110px size.
            // The bubble floats to its right — fixed width, never overlapping the nav widget.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 1. Captain bust portrait — full original size, bottom-left
                  SizedBox(
                    width: _kPortraitSize,
                    child: GridPortraitWidget(
                      key: ValueKey(
                          'portrait_${tutorial.captainPortraitIndex}_${tutorial.isShowingAngryPortrait}'),
                      imagePath: tutorial.getCaptainPortraitPath(),
                      gridIndex: tutorial.captainPortraitIndex,
                      size: _kPortraitSize,
                    ),
                  ),

                  // Horizontal spacer between portrait and bubble (do NOT use Expanded —
                  // the bubble must stay within its own fixed width so it never reaches
                  // the nav widget on the right).
                  const SizedBox(width: 4),

                  // 2. Speech bubble — fixed max width.
                  //    Compact (2 lines) by default; tapping body or chevron expands.
                  //    Uses AnimatedSize so the height actually animates.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kBubbleMaxWidth),
                    child: PaperPanel(
                      backgroundColor: isAnnoyed
                          ? const Color(0xFF2D1A1A).withValues(alpha: 0.96)
                          : const Color(0xFF1A1A1A).withValues(alpha: 0.96),
                      borderColor: isAnnoyed
                          ? Colors.red.shade900
                          : const Color(0xFFE0D5C1).withValues(alpha: 0.4),
                      borderWidth: 2.0,
                      irregularity: 3.5,
                      elevation: 8,
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Speaker name + expand chevron ──────────────────
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  captain?.name ?? "Aravt Captain",
                                  style: GoogleFonts.cinzel(
                                      color: isAnnoyed
                                          ? Colors.red.shade300
                                          : const Color(0xFFE0D5C1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Use TextPainter to check if the text would overflow 2 lines
                                  final textPainter = TextPainter(
                                    text: TextSpan(
                                      text: step.text,
                                      style: GoogleFonts.inter(fontSize: 11, height: 1.25),
                                    ),
                                    maxLines: 2,
                                    textDirection: TextDirection.ltr,
                                  )..layout(maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : _kBubbleMaxWidth - 20);
                                  
                                  if (!textPainter.didExceedMaxLines) {
                                    return const SizedBox.shrink();
                                  }

                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _isExpanded = !_isExpanded),
                                    child: Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_up,
                                      color: Colors.white38,
                                      size: 14,
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // ── Dialogue body — AnimatedSize makes height animate ──
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isExpanded = !_isExpanded),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topLeft,
                              child: _isExpanded
                                  ? Text(
                                      step.text,
                                      style: GoogleFonts.inter(
                                          color: Colors.white
                                              .withValues(alpha: 0.92),
                                          fontSize: 11,
                                          height: 1.35),
                                    )
                                  : Text(
                                      step.text,
                                      style: GoogleFonts.inter(
                                          color: Colors.white
                                              .withValues(alpha: 0.92),
                                          fontSize: 11,
                                          height: 1.25),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // ── Action buttons ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!step.isConclude)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      tutorial.dismiss(context, gameState),
                                  child: Text("Dismiss",
                                      style: GoogleFonts.cinzel(
                                          color: Colors.white38,
                                          fontSize: 10)),
                                ),
                              if (step.isConclude) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFE0D5C1),
                                      foregroundColor: Colors.black,
                                      elevation: 3,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  onPressed: () => tutorial.complete(
                                      gameState,
                                      success: true),
                                  child: Text("Conclude",
                                      style: GoogleFonts.cinzel(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                              ] else if (step.highlightKey == null) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFE0D5C1),
                                      foregroundColor: Colors.black,
                                      elevation: 3,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  onPressed: () =>
                                      tutorial.advance(context, gameState),
                                  child: Text("Continue",
                                      style: GoogleFonts.cinzel(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Global Bobbing Red Arrow ---
            // Rendered LAST so it always appears on top of the HUD dialog —
            // critical on small iPhone screens where the HUD covers the bottom half.
            // screenAnchor steps use known screen-fraction positions (reliable
            // for buttons inside Transform.scale); otherwise uses the widget rect
            // reported by TutorialHighlighter.
            Builder(builder: (arrowCtx) {
              final arrowStep = tutorial.currentStep;
              final screenSize = MediaQuery.of(arrowCtx).size;

              Offset? arrowTarget;
              if (arrowStep?.screenAnchor != null) {
                final anchor = arrowStep!.screenAnchor!;
                arrowTarget = Offset(
                  (anchor.x + 1) / 2 * screenSize.width,
                  (anchor.y + 1) / 2 * screenSize.height,
                );
              } else if (tutorial.highlightPosition != null) {
                arrowTarget = Offset(
                  tutorial.highlightPosition!.center.dx,
                  tutorial.highlightPosition!.top,
                );
              }

              if (arrowTarget == null) return const SizedBox.shrink();

              // Clamp so the 50×50 arrow widget never goes off-screen on any device.
              final double arrowL =
                  (arrowTarget.dx - 25).clamp(0.0, screenSize.width - 50);
              final double arrowT =
                  (arrowTarget.dy - 65).clamp(0.0, screenSize.height - 50);

              // Hide arrow if it would be pushed off or sit strangely above a
              // target that is already off-screen (e.g. scrolled up).
              // We only do this for widget-tracking arrows, not screen anchors.
              if (arrowStep?.screenAnchor == null &&
                  (arrowTarget.dy < 20 || arrowTarget.dy > screenSize.height)) {
                return const SizedBox.shrink();
              }

              return Positioned(
                left: arrowL,
                top: arrowT,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _arrowAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _arrowAnimation.value),
                        child: Transform.rotate(
                          angle: arrowStep?.arrowRotation ?? 0.0,
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: CustomPaint(
                              painter: _RedArrowPainter(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _RedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade900
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.05, size.height * 0.45);
    path.lineTo(size.width * 0.3, size.height * 0.45);
    path.lineTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.7, size.height * 0.45);
    path.lineTo(size.width * 0.95, size.height * 0.45);
    path.close();

    canvas.drawPath(path.shift(const Offset(2, 3)), shadowPaint);
    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
