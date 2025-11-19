// lib/widgets/aravt_map_icon.dart

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

class AravtMapIcon extends StatefulWidget {
  final String color; // e.g., 'blue', 'red'
  final double scale; // 0.5 for region, 0.75 for world
  final bool isMovingRight;

  const AravtMapIcon({
    Key? key,
    required this.color,
    this.scale = 0.5,
    this.isMovingRight = true,
  }) : super(key: key);

  @override
  _AravtMapIconState createState() => _AravtMapIconState();
}

class _AravtMapIconState extends State<AravtMapIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  ui.Image? _spritesheet;
  bool _isLoading = true;

  // Spritesheet properties from combat_screen.dart
  static const int frameWidth = 250;
  static const int frameHeight = 250;
  static const int frameCount = 17;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // 17 frames over 1 second
    )..repeat(); // Let it loop continuously for animation

    _loadSprite();
  }

  Future<void> _loadSprite() async {
    final String sheetName =
        '${widget.color}_horse_archer_spritesheet${widget.isMovingRight ? "_right" : ""}.png';
    try {
      final ui.Image img = await _loadImage('assets/images/sprites/$sheetName');
      if (mounted) {
        setState(() {
          _spritesheet = img;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading map icon sprite '$sheetName': $e");
      // Fallback or error icon
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _spritesheet == null) {
      // Return a simple placeholder icon while loading
      return Icon(
        Icons.directions_run,
        color: Colors.blue.shade300,
        size: 40 * widget.scale, // Apply scale to placeholder
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: _AravtIconPainter(
            spritesheet: _spritesheet!,
            animationValue: _animationController.value,
          ),
          // Set the size based on the desired render size
          size: Size(40 * widget.scale, 40 * widget.scale),
        );
      },
    );
  }
}

class _AravtIconPainter extends CustomPainter {
  final ui.Image spritesheet;
  final double animationValue;

  _AravtIconPainter({
    required this.spritesheet,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.low;
    final int frame =
        (animationValue * _AravtMapIconState.frameCount).floor() %
            _AravtMapIconState.frameCount;

    final double srcLeft =
        (frame * _AravtMapIconState.frameWidth).toDouble();
    final Rect srcRect = Rect.fromLTWH(
      srcLeft,
      0,
      _AravtMapIconState.frameWidth.toDouble(),
      _AravtMapIconState.frameHeight.toDouble(),
    );
    
    // Draw centered in the widget's Size
    final Rect dstRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    canvas.drawImageRect(spritesheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _AravtIconPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.spritesheet != spritesheet;
  }
}

