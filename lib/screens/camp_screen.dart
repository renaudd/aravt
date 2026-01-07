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
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';

import '../providers/game_state.dart';
import '../models/soldier_data.dart' as SoldierData;

import '../models/yurt_data.dart';
import 'yurt_detail_screen.dart';
import 'stockade_screen.dart';
import 'infirmary_screen.dart';
import '../widgets/persistent_menu_widget.dart';
import '../services/tutorial_service.dart';
import '../models/inventory_item.dart';

class CampScreen extends StatefulWidget {
  const CampScreen({super.key});

  @override
  State<CampScreen> createState() => _CampScreenState();
}

class _CampScreenState extends State<CampScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ui.Image? _soldierSpriteSheet;
  ui.Image? _horseImage;
  // Offset? _stockadePosition; // Removed, using GameState.campLayout
  // Offset? _infirmaryPosition; // Removed, using GameState.campLayout
  final List<AnimatedSoldier> _soldiers = [];
  final math.Random _random = math.Random();

  static const int spriteCols = 5;
  static const int totalFrames = 35;
  static const double frameWidth = 360;
  static const double frameHeight = 640;

  static const double spriteFps = 12.0;
  static const double minSoldierSpeed = 1.0; // Slowest at the top
  static const double maxSoldierSpeed = 4.0; // Fastest at the bottom
  static const double minSoldierScale = 0.03; // Smaller in background
  static const double maxSoldierScale = 0.15;

  // Camp bounds (normalized coordinates)
  static const double minX = 0.1;
  static const double maxX = 0.9;
  static const double minY = 0.50;
  static const double maxY = 0.90;
  static const double boundaryBuffer = 0.01;

  static const double fixedDeltaTime =
      1.0 / 60.0; // Assuming 60 FPS for movement updates

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateScene);

    // Defer initialization to after context is available, or use a post-frame callback
    // But we can check GameState here if we have context? No, safest is later.
    // _initSoldiers is async anyway.
    
    // We'll initialize positions in didChangeDependencies or use a flag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initBuildingPositions();
        _initSoldiers(); // Load sprites
        
        final gameState = context.read<GameState>();
        final tutorialService = context.read<TutorialService>();
        tutorialService.startTutorial(context, gameState);
      }
    });
  }

  void _initBuildingPositions() {
    final gameState = context.read<GameState>();

    // Check if layout exists
    if (gameState.campLayout.isEmpty) {
      // Generate new layout
      final stockadePos = Offset(
        _random.nextDouble() * 0.3 + 0.1,
        _random.nextDouble() * 0.15 + 0.70,
      );
      final infirmaryPos = Offset(
        _random.nextDouble() * 0.3 + 0.6,
        _random.nextDouble() * 0.15 + 0.70,
      );
      
      gameState.campLayout['Stockade'] = {
        'x': stockadePos.dx,
        'y': stockadePos.dy
      };
      gameState.campLayout['Infirmary'] = {
        'x': infirmaryPos.dx,
        'y': infirmaryPos.dy
      };

      // Save? GameState updates are usually auto-saved or manual.
      // We modified the map in memory.
    }
  }

  Future<void> _initSoldiers() async {
    try {
      final image = await _loadImage('assets/images/mongol_walk_sheet.png');
      final horseImg = await _loadImage('assets/images/horses.png');
      if (!mounted) return;

      final gameState = context.read<GameState>();
      final List<SoldierData.Soldier> hordeMembers = gameState.horde;

      setState(() {
        _soldierSpriteSheet = image;
        _horseImage = horseImg;
        _soldiers.clear();
        for (var dataSoldier in hordeMembers) {
          _soldiers.add(AnimatedSoldier(
            position: _getRandomCampPosition(),
            target: _getRandomCampPosition(),
            dataSoldier: dataSoldier,
          ));
        }
      });

      if (mounted && !_controller.isAnimating) {
        _controller.repeat();
      }
    } catch (e) {
      print('Error loading soldier spritesheet: $e');
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final provider = AssetImage(assetPath);
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
    }, onError: (exception, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    });
    stream.addListener(listener);
    return completer.future.whenComplete(() => stream.removeListener(listener));
  }

  Offset _getRandomCampPosition() {
    return Offset(
      _random.nextDouble() * (maxX - minX) + minX,
      _random.nextDouble() * (maxY - minY) + minY,
    );
  }

  double _calculateScale(double yPosition) {
    final t = ((yPosition - minY) / (maxY - minY)).clamp(0.0, 1.0);
    return ui.lerpDouble(minSoldierScale, maxSoldierScale, t) ??
        minSoldierScale;
  }

  double _calculateSpeed(double yPosition) {
    final t = ((yPosition - minY) / (maxY - minY)).clamp(0.0, 1.0);
    return ui.lerpDouble(minSoldierSpeed, maxSoldierSpeed, t) ??
        minSoldierSpeed;
  }

  void _updateScene() {
    if (!mounted || _soldierSpriteSheet == null) return;

    final double deltaTime = fixedDeltaTime;
    final screenSize = MediaQuery.of(context).size;

    setState(() {
      for (var soldier in _soldiers) {
        soldier.scale = _calculateScale(soldier.position.dy);

        if (soldier.state == SoldierState.walking) {
          final double dx = soldier.target.dx - soldier.position.dx;
          if (dx > 0.0001) {
            soldier.isMovingRight = true;
          } else if (dx < -0.0001) {
            soldier.isMovingRight = false;
          }

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
                _random.nextDouble() * 60.0 + 30.0;
          } else {
            final double currentSpeed = _calculateSpeed(soldier.position.dy);
            final pixelsToMove = currentSpeed * deltaTime;
            final moveVectorNormalized = directionVector / distance;
            final moveVector = moveVectorNormalized * pixelsToMove;

            soldier.position += Offset(moveVector.dx / screenSize.width,
                moveVector.dy / screenSize.height);

            soldier.position = Offset(
                soldier.position.dx
                    .clamp(minX + boundaryBuffer, maxX - boundaryBuffer),
                soldier.position.dy
                    .clamp(minY + boundaryBuffer, maxY - boundaryBuffer));
          }
        } else {
          soldier.waitTimer -= deltaTime;
          if (soldier.waitTimer <= 0) {
            soldier.state = SoldierState.walking;
            soldier.target = _getRandomCampPosition();
            final double dx = soldier.target.dx - soldier.position.dx;
            soldier.isMovingRight = dx > 0;
          }
        }

        if (soldier.state == SoldierState.walking) {
          soldier.animationTime += deltaTime;
          final double totalAnimationTime = soldier.animationTime;
          soldier.currentFrame =
              (totalAnimationTime * spriteFps).floor() % totalFrames;
        } else {
          soldier.currentFrame = 0;
          soldier.animationTime = 0;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // Z-Sorted Rendering Helper Classes
  // We need to store everything as a RenderItem
  
  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final Size screenSize = MediaQuery.of(context).size;
    final List<Yurt> yurts = gameState.yurts;
    
    // --- Collect Renderable Items ---
    List<_RenderItem> renderItems = [];

    // 1. Yurts
    const double baseYurtWidth = 820.0;
    for (var yurt in yurts) {
      final position = yurt.position ?? const Offset(0.5, 0.6);
      final scale = yurt.scale ?? 0.1;
      double currentYurtWidth = baseYurtWidth * scale;
      double currentYurtHeight =
          currentYurtWidth * (yurt.imagePath.contains('nice') ? 0.65 : 0.6);

      // Bottom Y coordinate determines depth (roughly).
      // For buildings, the "feet" are at top + height.
      // But we position Top/Left. So y = top + height.
      double topPos = position.dy * screenSize.height - currentYurtHeight;
      double sortY = topPos + currentYurtHeight; 

      renderItems.add(_RenderItem(
        y: sortY,
        builder: () {
          double leftPos =
              position.dx * screenSize.width - (currentYurtWidth / 2);
            return Positioned(
              left: leftPos,
              top: topPos,
              child: Tooltip(
                message: yurt.occupantIds.isEmpty
                    ? 'Empty Yurt'
                    : 'Occupants: ${yurt.occupantIds.map((id) {
                        final soldier = gameState.horde.firstWhere(
                            (s) => s.id == id,
                            orElse: () => gameState.horde.first);
                        return soldier.name;
                      }).join(", ")}',
                child: GestureDetector(
                  onTap: () {
                    if (_controller.isAnimating) _controller.stop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => YurtDetailScreen(yurtId: yurt.id),
                      ),
                    ).then((_) {
                      if (mounted && !_controller.isAnimating) {
                        _controller.repeat();
                      }
                    });
                  },
                child: Image.asset(
                  yurt.imagePath,
                  width: currentYurtWidth,
                  height: currentYurtHeight,
                ),
              ),
            ),
          );
        },
      ));

      // Add Yurt Horses separately so they Z-sort correctly too?
      // Actually horses are usually "around" the yurt.
      // If we want horses BEHIND or IN FRONT based on Y, we should treat them as individual entities.
      // But they are attached to the yurt logic currently.
      // For now, let's keep horses attached to the yurt logic BUT we could split them if we want perfect sorting.
      // The user asked "horses and soldiers always appear behind the buildings".
      // Usually "behind" means "blocked by". If the horse is "in front" (lower Y) it should be on top.
      // If the horse is "behind" (higher Y/smaller Y value, wait. Y increases downwards).
      // Higher Y = Lower on screen = Closer to camera = On Top.
      // Lower Y = Higher on screen = Further from camera = Behind.
      // So sorting by Y (ascending) paints Top->Bottom (Back->Front).

      // Let's split horses out!
      if (_horseImage != null) {
        int horseCount = 0;
        for (var occupantId in yurt.occupantIds) {
          final soldier = gameState.horde.firstWhere((s) => s.id == occupantId,
              orElse: () => gameState.horde.first);

          int horses = soldier.personalInventory
              .where((i) => i.itemType == ItemType.mount)
              .length;
          if (soldier.equippedItems.values
              .any((i) => i.itemType == ItemType.mount)) {
            horses++;
          }

          for (int i = 0; i < horses; i++) {
            if (horseCount >= 10) break;

            final int seed = occupantId.hashCode + i;
            final math.Random stableRandom = math.Random(seed);

            double angle = (horseCount / 10.0) * math.pi + math.pi;
            double distance =
                currentYurtWidth * 0.4 + (stableRandom.nextDouble()) * 10;
            // Center of yurt
            double cx = position.dx * screenSize.width;
            double cy = topPos + (currentYurtHeight / 2);

            double hx = cx + math.cos(angle) * distance;
            double hy =
                cy + math.sin(angle) * distance * 0.5; // Flattened circle

            // Sort Y is the horse's feet (hy + 15 approx for size 30)
            double horseSize = 30.0; // Increased size (was 20)

            renderItems.add(_RenderItem(
              y: hy + horseSize,
              builder: () => Positioned(
                left: hx - (horseSize / 2),
                top: hy - (horseSize / 2),
                child: CustomPaint(
                  painter: _HorseSpritePainter(
                    spriteSheet: _horseImage!,
                    spriteIndex: stableRandom.nextInt(16),
                  ),
                  size: Size(horseSize, horseSize),
                ),
              ),
            ));
            horseCount++;
          }
          if (horseCount >= 10) break;
        }
      }
    }

    // 2. Buildings (Stockade, Infirmary)
    final stockadeData = gameState.campLayout['Stockade'];
    final stockadePos = stockadeData != null
        ? Offset(stockadeData['x']!, stockadeData['y']!)
        : const Offset(0.15, 0.7);

    _addBuilding(renderItems, screenSize, stockadePos,
        'assets/images/stockade.png', 'Stockade', () {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const StockadeScreen()));
    });

    final infirmaryData = gameState.campLayout['Infirmary'];
    final infirmaryPos = infirmaryData != null
        ? Offset(infirmaryData['x']!, infirmaryData['y']!)
        : const Offset(0.85, 0.7);

    _addBuilding(renderItems, screenSize, infirmaryPos,
        'assets/images/infirmary.png', 'Infirmary', () {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const InfirmaryScreen()));
    });

    // 3. Soldiers
    if (_soldierSpriteSheet != null) {
      for (var soldier in _soldiers) {
        double displayWidth = frameWidth * soldier.scale;
        double displayHeight = frameHeight * soldier.scale;
        // Feet position
        double feetY = soldier.position.dy * screenSize.height;

        renderItems.add(_RenderItem(
          y: feetY,
          builder: () => Positioned(
            left: soldier.position.dx * screenSize.width - (displayWidth / 2),
            top: feetY - displayHeight,
                child: SoldierSprite(
                  spriteSheet: _soldierSpriteSheet!,
                  frame: soldier.currentFrame,
              frameWidth: frameWidth,
              frameHeight: frameHeight,
                  scale: soldier.scale,
              cols: spriteCols,
                  isMovingRight: soldier.isMovingRight,
                ),
          ),
        ));
      }
    }

    // Sort items by Y (back to front)
    renderItems.sort((a, b) => a.y.compareTo(b.y));

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/camp_background.png',
                fit: BoxFit.cover),
          ),
          // Render sorted items
          ...renderItems.map((item) => item.builder()),
          
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
  
  void _addBuilding(List<_RenderItem> items, Size screenSize, Offset position,
      String imagePath, String label, VoidCallback onTap) {
    double scale = 0.7 + (position.dy * 0.6);
    const double baseWidth = 400.0;
    double width = baseWidth * scale * 0.25;
    double height = width;
      
    double top = position.dy * screenSize.height - height;
    double bottom = top + height;

    items.add(_RenderItem(
      y: bottom, // Sort by bottom
      builder: () => Positioned(
        left: position.dx * screenSize.width - (width / 2),
        top: top,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            onTap: onTap,
            child: Image.asset(
              imagePath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: height,
                  color: Colors.red,
                  child: const Icon(Icons.error, color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildTopUI() {
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

class _RenderItem {
  final double y;
  final Widget Function() builder;
  _RenderItem({required this.y, required this.builder});
}

class SoldierSprite extends StatelessWidget {
  final ui.Image spriteSheet;
  final int frame;
  final double frameWidth;
  final double frameHeight;
  final double scale;
  final int cols;
  final bool isMovingRight;

  const SoldierSprite({
    super.key,
    required this.spriteSheet,
    required this.frame,
    required this.frameWidth,
    required this.frameHeight,
    required this.scale,
    required this.cols,
    required this.isMovingRight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpritePainter(
        spriteSheet: spriteSheet,
        frame: frame,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        cols: cols,
        isMovingRight: isMovingRight,
      ),
      size: Size(
        frameWidth * scale,
        frameHeight * scale,
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frame;
  final double frameWidth;
  final double frameHeight;
  final int cols;
  final bool isMovingRight;

  _SpritePainter({
    required this.spriteSheet,
    required this.frame,
    required this.frameWidth,
    required this.frameHeight,
    required this.cols,
    required this.isMovingRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int row = frame ~/ cols;
    final int col = frame % cols;
    final double srcX = col * frameWidth;
    final double srcY = row * frameHeight;

    final srcRect = Rect.fromLTWH(srcX, srcY, frameWidth, frameHeight);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.save();
    if (!isMovingRight) {
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }
    canvas.drawImageRect(
        spriteSheet,
        srcRect,
        dstRect,
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.spriteSheet != spriteSheet ||
        oldDelegate.isMovingRight != isMovingRight;
  }
}

class _HorseSpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int spriteIndex;
  static const double spriteWidth = 250.0;
  static const double spriteHeight = 250.0;

  _HorseSpritePainter({
    required this.spriteSheet,
    required this.spriteIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double srcX = spriteIndex * spriteWidth;
    final double srcY = 0; // Assuming single row for horses

    final srcRect = Rect.fromLTWH(srcX, srcY, spriteWidth, spriteHeight);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
        spriteSheet,
        srcRect,
        dstRect,
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_HorseSpritePainter oldDelegate) {
    return oldDelegate.spriteIndex != spriteIndex ||
        oldDelegate.spriteSheet != spriteSheet;
  }
}

enum SoldierState { walking, waiting }

class AnimatedSoldier {
  Offset position;
  Offset target;
  SoldierData.Soldier dataSoldier;
  SoldierState state = SoldierState.walking;
  int currentFrame = 0;
  double waitTimer = 0;
  double scale = 0.1;
  double animationTime = 0;
  bool isMovingRight = true;

  AnimatedSoldier({
    required this.position,
    required this.target,
    required this.dataSoldier,
  });
}
