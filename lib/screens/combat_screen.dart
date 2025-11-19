// lib/screens/combat_screen.dart

import 'dart:async';
import 'dart:ui' as ui;
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/screens/post_combat_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/services/combat_service.dart'
    show CombatSoldier, CombatSimulator;

class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key});

  @override
  _CombatScreenState createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _simulationTimer;
  bool _isPlaying = false;
  final Map<String, ui.Image> _spritesheets = {};
  ui.Image? _battlefieldBackground;
  bool _isLoading = true;

  static const List<String> playerColors = ['red', 'blue', 'green', 'kellygreen'];
  static const List<String> npcColors = ['pink', 'purple', 'teal', 'yellow'];

  static const int frameWidth = 250;
  static const int frameHeight = 250;
  static const int frameCount = 17;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _loadAllAssets().then((_) {
      final gameState = context.read<GameState>();
      if (!gameState.isCombatPaused) {
        _isPlaying = true;
        _startSimulationTimer();
      } else {
        _isPlaying = false;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final Size screenSize = MediaQuery.of(context).size;
        final gameState = context.read<GameState>();
        final battlefieldWidth =
            gameState.currentCombat?.battlefield.width.toDouble() ?? 1000.0;
        final battlefieldHeight =
            gameState.currentCombat?.battlefield.length.toDouble() ?? 500.0;

        if (battlefieldWidth == 0 || battlefieldHeight == 0) return;

        double fitWidthScale = screenSize.width / battlefieldWidth;
        double initialScale = (fitWidthScale * 1.5).clamp(0.2, 5.0);
        final double initialX =
            (battlefieldWidth / 2) * initialScale - (screenSize.width / 2);
        final double initialY =
            (battlefieldHeight / 2) * initialScale - (screenSize.height / 2);

        _transformationController.value = Matrix4.identity()
          ..translate(-initialX, -initialY)
          ..scale(initialScale);
      });
    });
  }

  Future<void> _loadAllAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _battlefieldBackground =
          await _loadImage('assets/images/battlefield_background.png');

      List<String> allColors = [...playerColors, ...npcColors];
      List<Future> loadingFutures = [];
      for (String color in allColors) {
        // Load Horse Archers (Existing)
        loadingFutures.add(_loadImage('assets/images/sprites/${color}_horse_archer_spritesheet.png')
            .then((img) { if (mounted) _spritesheets['${color}_horse_archer'] = img; }));
        loadingFutures.add(_loadImage('assets/images/sprites/${color}_horse_archer_spritesheet_right.png')
            .then((img) { if (mounted) _spritesheets['${color}_horse_archer_right'] = img; }));

        // [GEMINI-FIX] Load Spearmen (New) - Only for supported colors if needed, or all
        // Assuming all colors might eventually have them, but you listed specific ones.
        // We'll try loading for all to be safe, handle errors if missing.
        // Actually, let's stick to the ones you listed to avoid 404s if others don't exist yet.
        if (['red', 'blue', 'purple', 'teal'].contains(color)) {
             loadingFutures.add(_loadImage('assets/images/sprites/${color}_spearman_spritesheet.png')
                .then((img) { if (mounted) _spritesheets['${color}_spearman'] = img; })
                .catchError((e) { print("Warning: Missing spearman sprite for $color"); return null; })); // Graceful fallback
             loadingFutures.add(_loadImage('assets/images/sprites/${color}_spearman_spritesheet_right.png')
                .then((img) { if (mounted) _spritesheets['${color}_spearman_right'] = img; })
                .catchError((e) { return null; }));
        }
      }
      await Future.wait(loadingFutures);

    } catch (e) {
      print("Error loading combat assets: $e");
      if (mounted) context.read<GameState>().endCombat();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  void _startSimulationTimer() {
    _stopSimulationTimer();
    final gameState = context.read<GameState>();
    final combat = gameState.currentCombat;
    if (combat == null || gameState.isCombatPaused) {
      _isPlaying = false;
      return;
    }

    const double secondsPerTurn = 5.0;
    int actionsPerTurnEstimate = combat.allCombatSoldiers.length;
    if (actionsPerTurnEstimate == 0) actionsPerTurnEstimate = 10;

    int delayMs = (secondsPerTurn *
            1000 /
            actionsPerTurnEstimate /
            gameState.combatSpeedMultiplier)
        .round();
    delayMs = delayMs.clamp(50, 2000);
    // print("Timer Delay: $delayMs ms");

    _simulationTimer = Timer.periodic(Duration(milliseconds: delayMs), (timer) {
      final currentGameState = context.read<GameState>();
      if (currentGameState.currentCombat == null ||
          currentGameState.isCombatPaused) {
        _stopSimulationTimer();
        if (mounted) setState(() { _isPlaying = false; });
      } else {
        currentGameState.currentCombat!.processNextAction();
        if (context.read<GameState>().combatFlowState ==
            CombatFlowState.postCombat) {
          _stopSimulationTimer();
          if (mounted) setState(() { _isPlaying = false; });
        }
      }
    });
  }

  void _stopSimulationTimer() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    _stopSimulationTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final combatSimulator = gameState.currentCombat;

    if (_isLoading || combatSimulator == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final events = gameState.eventLog;
    final combatEvents = events
        .where((e) =>
            e.category == EventCategory.combat ||
            e.category == EventCategory.health)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPauseState = context.read<GameState>().isCombatPaused;
      if (currentPauseState && _isPlaying) {
        setState(() { _isPlaying = false; });
        _stopSimulationTimer();
      } else if (!currentPauseState && !_isPlaying) {
        setState(() { _isPlaying = true; });
        _startSimulationTimer();
      }
    });

    final double worldWidth = combatSimulator.battlefield.width.toDouble();
    final double worldHeight = combatSimulator.battlefield.length.toDouble();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(200.0),
              minScale: 0.2,
              maxScale: 5.0,
              child: SizedBox(
                width: worldWidth,
                height: worldHeight,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final currentCombatants =
                        context.watch<GameState>().currentCombat?.allCombatSoldiers ??
                            [];
                    return CustomPaint(
                      painter: BackgroundPainter(_battlefieldBackground, simulator: combatSimulator),
                      foregroundPainter: BattlefieldPainter(
                        combatants: currentCombatants,
                        spritesheets: _spritesheets,
                        animationValue: _animationController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // UI Overlay
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        color: Colors.white,
                        onPressed: () {
                          context.read<GameState>().toggleCombatPause();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        color: Colors.white,
                        onPressed: () {
                           final gs = context.read<GameState>();
                           if (!gs.isCombatPaused) {
                               gs.toggleCombatPause();
                           }
                           gs.currentCombat?.processNextAction();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        color: Colors.white,
                        onPressed: () {
                           final gs = context.read<GameState>();
                           if (!gs.isCombatPaused) {
                               gs.toggleCombatPause();
                           }
                           gs.advanceCombatRound();
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        child: Text('${gameState.combatSpeedMultiplier.toInt()}x',
                            style: GoogleFonts.cinzel(color: Colors.white)),
                        onPressed: () {
                           final gs = context.read<GameState>();
                           double next = (gs.combatSpeedMultiplier == 1.0) ? 2.0 : (gs.combatSpeedMultiplier == 2.0 ? 4.0 : 1.0);
                           gs.setCombatSpeed(next);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.fast_forward),
                        color: Colors.white,
                        onPressed: () => context.read<GameState>().skipCombatToEnd(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8)),
                    onPressed: () => context.read<GameState>().endCombat(),
                    child: const Text("End Combat (DEBUG)"),
                  ),
                ],
              ),
            ),
          ),
          // Combat Log
          Positioned(
            bottom: 20,
            left: 20,
            width: 400,
            height: 200,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30)),
              child: ListView.builder(
                itemCount: combatEvents.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final event = combatEvents[index];
                  Color eventColor = Colors.white;
                  if (event.severity == EventSeverity.critical) eventColor = Colors.red;
                  else if (event.severity == EventSeverity.high) eventColor = Colors.orange;
                  else if (event.severity == EventSeverity.low) eventColor = Colors.grey[400]!;
                  return Text("[${event.date.toShortString()}] ${event.message}",
                      style: GoogleFonts.cinzel(color: eventColor, fontSize: 12));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BattlefieldPainter extends CustomPainter {
  final List<CombatSoldier> combatants;
  final Map<String, ui.Image> spritesheets;
  final double animationValue;

  BattlefieldPainter({
    required this.combatants,
    required this.spritesheets,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.low;
    const double baseSpriteRenderSize = 40.0;
    final int frame = (animationValue * _CombatScreenState.frameCount).floor() %
            _CombatScreenState.frameCount;

    for (final soldier in combatants) {
      if (!soldier.isAlive && !soldier.isUnconscious) continue;
      
      bool isMovingRight = soldier.targetX > soldier.x;
      // [GEMINI-FIX] Select sprite type based on mount status
      String type = soldier.isMounted ? 'horse_archer' : 'spearman';
      String direction = isMovingRight ? '_right' : '';
      
      // Fallback to horse_archer if spearman sprite missing for this color
      String sheetKey = '${soldier.color}_${type}${direction}';
      if (!spritesheets.containsKey(sheetKey) && !soldier.isMounted) {
           // Fallback to horse archer if specific spearman color is missing
           sheetKey = '${soldier.color}_horse_archer${direction}';
      }

      final ui.Image? sheet = spritesheets[sheetKey];

      if (sheet == null) {
        paint.color = soldier.teamId == 0 ? Colors.blue : Colors.red;
        canvas.drawCircle(Offset(soldier.x, soldier.y), 5.0, paint); // Slightly larger fallback circle
        continue;
      }

      final double srcLeft = (frame * _CombatScreenState.frameWidth).toDouble();
      final Rect srcRect = Rect.fromLTWH(srcLeft, 0, _CombatScreenState.frameWidth.toDouble(), _CombatScreenState.frameHeight.toDouble());
      final Rect dstRect = Rect.fromCenter(center: Offset(soldier.x, soldier.y), width: baseSpriteRenderSize, height: baseSpriteRenderSize);
      
      if (soldier.isUnconscious) {
        paint.colorFilter = ColorFilter.mode(Colors.grey[800]!, BlendMode.modulate);
      } else {
        paint.colorFilter = null;
      }
      canvas.drawImageRect(sheet, srcRect, dstRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BattlefieldPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || !listEquals(oldDelegate.combatants, combatants);
  }
}

class BackgroundPainter extends CustomPainter {
  final ui.Image? image;
  final CombatSimulator? simulator;

  BackgroundPainter(this.image, {required this.simulator});

  @override
  void paint(Canvas canvas, Size size) {
    final double worldWidth = simulator?.battlefield.width.toDouble() ?? 1000.0;
    final double worldHeight = simulator?.battlefield.length.toDouble() ?? 500.0;

    if (image == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, worldWidth, worldHeight), Paint()..color = Colors.brown[800]!);
      return;
    }

    final Paint paint = Paint()..filterQuality = FilterQuality.medium;
    final Rect srcRect = Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
    final Rect dstRect = Rect.fromLTWH(0, 0, worldWidth, worldHeight);
    FittedSizes fittedSizes = applyBoxFit(BoxFit.cover, Size(image!.width.toDouble(), image!.height.toDouble()), Size(worldWidth, worldHeight));
    final Rect sourceSubrect = Alignment.center.inscribe(fittedSizes.source, srcRect);
    final Rect destinationSubrect = Alignment.center.inscribe(fittedSizes.destination, dstRect);
    canvas.drawImageRect(image!, sourceSubrect, destinationSubrect, paint);
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.simulator != simulator;
  }
}

extension DateTimeShortString on DateTime {
  String toShortString() {
    String month = this.month.toString().padLeft(2, '0');
    String day = this.day.toString().padLeft(2, '0');
    return "$month/$day/${this.year}";
  }
}

