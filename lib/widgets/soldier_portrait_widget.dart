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

//new soldier portrait widget

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays a single, UNTINTED portrait from a soldier spritesheet
/// on a solid-colored background.
class SoldierPortrait extends StatefulWidget {
  final int index;
  final Color backgroundColor; // Changed from 'tint'
  final double size;

  const SoldierPortrait({
    Key? key,
    required this.index,
    required this.size,
    required this.backgroundColor, // Now required and no longer nullable
  }) : super(key: key);

  // --- Static cache for the loaded spritesheet ---
  static ui.Image? _spriteSheetCache;
  static bool _isLoading = false;
  static final List<Completer<void>> _loadingCompleters = [];

  // --- Spritesheet properties ---
  static const String _spritesheetPath = 'assets/images/soldier_portraits.png';
  static const double _frameWidth = 250.0;
  static const double _frameHeight = 250.0;

  @override
  _SoldierPortraitState createState() => _SoldierPortraitState();
}

class _SoldierPortraitState extends State<SoldierPortrait> {
  // This future will complete once the image is loaded.
  Future<void>? _loadingFuture;

  @override
  void initState() {
    super.initState();
    // If cache is empty, start the loading process.
    if (SoldierPortrait._spriteSheetCache == null) {
      _loadingFuture = _loadSpriteSheet();
    }
  }

  /// Loads the spritesheet image from assets and stores it in the static cache.
  /// Uses a completer system to handle concurrent requests.
  Future<void> _loadSpriteSheet() async {
    // If already loading, wait for the existing loader to finish.
    if (SoldierPortrait._isLoading) {
      final completer = Completer<void>();
      SoldierPortrait._loadingCompleters.add(completer);
      return completer.future;
    }

    // Mark as loading
    SoldierPortrait._isLoading = true;

    try {
      final ByteData data =
          await rootBundle.load(SoldierPortrait._spritesheetPath);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      // Store in cache
      SoldierPortrait._spriteSheetCache = frameInfo.image;

      // Notify all waiting widgets that loading is complete
      for (var completer in SoldierPortrait._loadingCompleters) {
        completer.complete();
      }
    } catch (e) {
      print("Error loading spritesheet: $e");
      // Complete with error to unblock waiters
      for (var completer in SoldierPortrait._loadingCompleters) {
        completer.completeError(e);
      }
    } finally {
      SoldierPortrait._loadingCompleters.clear();
      SoldierPortrait._isLoading = false;
      // Rebuild this widget once loaded
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return ClipRRect(
      // Use a circular clip for the portrait
      borderRadius: BorderRadius.circular(widget.size / 2),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: widget.backgroundColor, // Apply the zodiac color as a background
        child: _buildPortraitPainter(),
      ),
    );
  }

  /// Builds the CustomPaint or a placeholder
  Widget _buildPortraitPainter() {
    // If the image is loaded, show the CustomPaint.
    if (SoldierPortrait._spriteSheetCache != null) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _PortraitPainter(
          spriteSheet: SoldierPortrait._spriteSheetCache!,
          index: widget.index,
          frameWidth: SoldierPortrait._frameWidth,
          frameHeight: SoldierPortrait._frameHeight,
        ),
      );
    }

    // If the image is not yet loaded, show a placeholder and
    // use a FutureBuilder to rebuild when loading completes.
    return FutureBuilder(
      future: _loadingFuture,
      builder: (context, snapshot) {
        // When loading is done, this will return the CustomPaint
        if (snapshot.connectionState == ConnectionState.done &&
            SoldierPortrait._spriteSheetCache != null) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PortraitPainter(
              spriteSheet: SoldierPortrait._spriteSheetCache!,
              index: widget.index,
              frameWidth: SoldierPortrait._frameWidth,
              frameHeight: SoldierPortrait._frameHeight,
            ),
          );
        }

        // While loading, just show the background color
        return Container();
      },
    );
  }
}

/// The CustomPainter that draws the correct frame from the spritesheet.
class _PortraitPainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int index;
  final double frameWidth;
  final double frameHeight;

  _PortraitPainter({
    required this.spriteSheet,
    required this.index,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the source rectangle (the part of the spritesheet to draw)
    final double srcX = index * frameWidth;
    final srcRect = Rect.fromLTWH(srcX, 0, frameWidth, frameHeight);

    // The destination rectangle is the full size of the widget
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // --- REMOVED ALL TINTING LOGIC ---
    // We just draw the image directly onto the colored background.
    final Paint paint = Paint();

    // Draw the specified part of the image onto the canvas
    canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) {
    // Repaint only if the image or frame changes
    return oldDelegate.spriteSheet != spriteSheet || oldDelegate.index != index;
  }
}
