// screens/camp_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/game_state.dart';

// --- Imports from your project ---
import '../models/soldier_data.dart' as SoldierData; // Using prefix
import '../models/yurt_data.dart'; // To get Yurt data
import '../screens/yurt_detail_screen.dart'; // To navigate to the yurt detail
import '../widgets/persistent_menu_widget.dart'; // For persistent menu
import '../services/tutorial_service.dart'; // [GEMINI-NEW] Import TutorialService

// --- Configuration ---
const double MAX_SOLDIER_SPEED = 2.5;
const double MIN_SOLDIER_SPEED = 0.2;
const double SPRITE_FRAME_WIDTH = 150.0;
const double SPRITE_FRAME_HEIGHT = 260.0;
const int SPRITE_FPS = 24;

enum SoldierState { walking, waiting }

enum WalkingDirection { up, down, left, right }

class AnimatedSoldier {
  final SoldierData.Soldier dataSoldier;
  Offset position;
  Offset target;
  int currentFrame = 0;
  WalkingDirection direction = WalkingDirection.down;
  SoldierState state = SoldierState.walking;
  double waitTimer = 0.5;
  double scale = 0.1;

  AnimatedSoldier({
    required this.position,
    required this.target,
    required this.dataSoldier,
  });
}

class CampScreen extends StatefulWidget {
  const CampScreen({super.key});

  @override
  State<CampScreen> createState() => _CampScreenState();
}

class _CampScreenState extends State<CampScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<AnimatedSoldier> _soldiers = [];
  final Random _random = Random();
  ui.Image? _soldierSpriteSheet;

  final Map<WalkingDirection, List<int>> _animationFrames = {
    WalkingDirection.up: [0, 1, 2],
    WalkingDirection.down: [10, 10, 10], // Standing still frame
    WalkingDirection.right: [3, 4, 5, 6, 7],
    WalkingDirection.left: [8, 9, 11],
  };

  @override
  void initState() {
    super.initState();
    _loadAssetsAndInitialize();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateScene);

    // [GEMINI-NEW] Start Tutorial if needed once the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tutorial = context.read<TutorialService>();
      final gameState = context.read<GameState>();
      // Only start if it's not already active.
      // The service itself checks if it has been permanently dismissed.
      if (!tutorial.isActive) {
        tutorial.startTutorial(context, gameState);
      }

      // [GEMINI-FIX] Trigger trade offer narrative when entering Camp with pending offer
      if (gameState.hasPendingTradeOffer &&
          gameState.pendingTradeCaptainId != null &&
          gameState.pendingTradeSoldierId != null) {
        gameState.startNarrativeEvent(NarrativeEvent(
          type: NarrativeEventType.day5Trade,
          instigatorId: gameState.pendingTradeCaptainId!,
          targetId: gameState.pendingTradeSoldierId!,
        ));
        // Clear the pending flag and IDs since narrative is now active
        gameState.hasPendingTradeOffer = false;
        gameState.pendingTradeCaptainId = null;
        gameState.pendingTradeSoldierId = null;
      }
    });
  }

  Future<void> _loadAssetsAndInitialize() async {
    final image =
        await _loadImage('assets/images/soldier_walk_spritesheet.png');

    if (!mounted) return; // Safety check

    final gameState = context.read<GameState>();

    // Use the horde from the provider
    final List<SoldierData.Soldier> hordeMembers = List.from(gameState.horde);

    setState(() {
      _soldierSpriteSheet = image;
      _soldiers.clear();
      for (int i = 0; i < hordeMembers.length; i++) {
        final dataSoldier = hordeMembers[i];
        _soldiers.add(AnimatedSoldier(
          position: _getRandomPosition(),
          target: _getRandomPosition(),
          dataSoldier: dataSoldier,
        ));
      }
    });

    if (mounted && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final provider = AssetImage(assetPath);
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    }));
    return completer.future;
  }

  Offset _getRandomPosition() {
    return Offset(
      _random.nextDouble() * 0.6 + 0.2, // x 20% to 80%
      _random.nextDouble() * 0.25 + 0.60, // y 60% to 85% (walking area)
    );
  }

  double _calculateSoldierScale(double yPosition) {
    const minY = 0.60;
    const maxY = 0.85;
    const minScale = 0.10;
    const maxScale = 0.30;
    final t = ((yPosition - minY) / (maxY - minY)).clamp(0.0, 1.0);
    return ui.lerpDouble(minScale, maxScale, t) ?? minScale;
  }

  void _updateScene() {
    if (!mounted || _soldierSpriteSheet == null) return;

    final double deltaTime =
        (_controller.lastElapsedDuration?.inMilliseconds ?? 16) / 1000.0;
    final screenSize = MediaQuery.of(context).size;

    setState(() {
      for (int i = 0; i < _soldiers.length; i++) {
        final soldier = _soldiers[i];

        const double minY = 0.60;
        const double maxY = 0.85;
        final double t =
            ((soldier.position.dy - minY) / (maxY - minY)).clamp(0.0, 1.0);
        final double currentSpeed =
            ui.lerpDouble(MIN_SOLDIER_SPEED, MAX_SOLDIER_SPEED, t) ??
                MIN_SOLDIER_SPEED;

        if (soldier.state == SoldierState.walking) {
          for (int j = 0; j < _soldiers.length; j++) {
            if (i == j) continue;
            final otherSoldier = _soldiers[j];
            double collisionRadius = (SPRITE_FRAME_WIDTH * soldier.scale / 4);
            if ((soldier.position - otherSoldier.position).distance *
                    screenSize.width <
                collisionRadius) {
              soldier.state = SoldierState.waiting;
              soldier.waitTimer = _random.nextDouble() * 15.0 + 8.0; // 8-23 sec
              break;
            }
          }
          if (soldier.state == SoldierState.waiting) continue;

          final Offset targetInPixels = Offset(
              soldier.target.dx * screenSize.width,
              soldier.target.dy * screenSize.height);
          final Offset positionInPixels = Offset(
              soldier.position.dx * screenSize.width,
              soldier.position.dy * screenSize.height);
          final Offset directionVector = targetInPixels - positionInPixels;
          final double distance = directionVector.distance;

          if (distance < 5.0) {
            soldier.state = SoldierState.waiting;
            soldier.waitTimer =
                _random.nextDouble() * 600.0 + 3000.0; // 5-15 min
          } else {
            if (directionVector.dx.abs() > directionVector.dy.abs()) {
              soldier.direction = directionVector.dx > 0
                  ? WalkingDirection.right
                  : WalkingDirection.left;
            } else {
              soldier.direction = directionVector.dy > 0
                  ? WalkingDirection.down
                  : WalkingDirection.up;
            }

            final pixelsToMove = currentSpeed * deltaTime;
            final moveVectorNormalized = directionVector / distance;
            final moveVector = moveVectorNormalized * pixelsToMove;

            soldier.position += Offset(moveVector.dx / screenSize.width,
                moveVector.dy / screenSize.height);

            soldier.position = Offset(soldier.position.dx.clamp(0.2, 0.8),
                soldier.position.dy.clamp(0.60, 0.85));
          }

          final List<int> currentAnim = _animationFrames[soldier.direction]!;
          final int frameIndex =
              (_controller.value * SPRITE_FPS * currentAnim.length).floor() %
                  currentAnim.length;
          soldier.currentFrame = currentAnim[frameIndex];
        } else {
          soldier.waitTimer -= deltaTime;
          soldier.currentFrame = 10;
          if (soldier.waitTimer <= 0) {
            soldier.state = SoldierState.walking;
            soldier.target = _getRandomPosition();
          }
        }
        soldier.scale = _calculateSoldierScale(soldier.position.dy);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScene);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider for state changes
    final gameState = context.watch<GameState>();

    final Size screenSize = MediaQuery.of(context).size;
    // Get yurts from the provider
    final List<Yurt> yurts = gameState.yurts;
    const double baseYurtWidth = 820.0;
    const double baseYurtHeight = 540.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/camp_background.png',
                fit: BoxFit.cover),
          ),
          ...yurts.map((yurt) {
            final position = yurt.position ?? const Offset(0.5, 0.6);
            final scale = yurt.scale ?? 0.1;
            double currentYurtWidth = baseYurtWidth * scale;
            double currentYurtHeight = baseYurtHeight * scale;
            double leftPos =
                position.dx * screenSize.width - (currentYurtWidth / 2);
            double topPos = position.dy * screenSize.height - currentYurtHeight;

            return Positioned(
              left: leftPos,
              top: topPos,
              child: GestureDetector(
                onTap: () {
                  if (_controller.isAnimating) _controller.stop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YurtDetailScreen(
                        yurtId: yurt.id,
                      ),
                    ),
                  ).then((_) {
                    if (mounted && !_controller.isAnimating)
                      _controller.repeat();
                  });
                },
                child: Image.asset(
                  yurt.imagePath,
                  width: currentYurtWidth,
                  height: currentYurtHeight,
                ),
              ),
            );
          }).toList(),
          if (_soldierSpriteSheet != null)
            ..._soldiers.map((soldier) {
              double soldierHeight = SPRITE_FRAME_HEIGHT * soldier.scale;
              return Positioned(
                left: soldier.position.dx * screenSize.width -
                    (SPRITE_FRAME_WIDTH * soldier.scale / 2),
                top: soldier.position.dy * screenSize.height - soldierHeight,
                child: SoldierSprite(
                  spriteSheet: _soldierSpriteSheet!,
                  frame: soldier.currentFrame,
                  scale: soldier.scale,
                ),
              );
            }).toList(),
          Positioned(
            top: 40,
            right: 20,
            child: _buildTopUI(),
          ),
          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildTopUI() {
    // Get player from the provider
    final player = context.read<GameState>().player;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Supplies: ${player?.suppliesWealth.toStringAsFixed(0) ?? 0} | Treasure: ${player?.treasureWealth.toStringAsFixed(0) ?? 0}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

// --- SoldierSprite and _SpritePainter classes ---
// (These are unchanged)

class SoldierSprite extends StatelessWidget {
  final ui.Image spriteSheet;
  final int frame;
  final double scale;

  const SoldierSprite({
    super.key,
    required this.spriteSheet,
    required this.frame,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpritePainter(
        spriteSheet: spriteSheet,
        frame: frame,
      ),
      size: Size(
        SPRITE_FRAME_WIDTH * scale,
        SPRITE_FRAME_HEIGHT * scale,
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frame;

  _SpritePainter({required this.spriteSheet, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final double srcX = frame * SPRITE_FRAME_WIDTH;
    final srcRect =
        Rect.fromLTWH(srcX, 0, SPRITE_FRAME_WIDTH, SPRITE_FRAME_HEIGHT);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(spriteSheet, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.spriteSheet != spriteSheet;
  }
}
