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

// widgets/item_sprite_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async'; // For Completer
import 'package:aravt/models/inventory_item.dart'; // Import the item model
import 'package:aravt/services/sprite_service.dart'; // Import the sprite service

// Helper map for placeholder icons.
const Map<EquipmentSlot, IconData> _placeholderIconMap = {
  EquipmentSlot.helmet: Icons.headset,
  EquipmentSlot.armor: Icons.shield, // Using shield as a proxy for body armor
  EquipmentSlot.gauntlets: Icons.pan_tool,
  EquipmentSlot.boots: Icons.ice_skating, // Using a boot-like icon
  EquipmentSlot.longBow: Icons.arrow_circle_up_sharp,
  EquipmentSlot.shortBow: Icons.arrow_back_sharp,
  EquipmentSlot.spear: Icons.chevron_right, // Using a sharp icon
  EquipmentSlot.melee: Icons.gavel, // Using a melee-like icon
  EquipmentSlot.mount: Icons.pets, // Using a horse-like icon
  EquipmentSlot.necklace: Icons.watch, // Using a circular item
  EquipmentSlot.ring: Icons.circle,
  EquipmentSlot.undergarments: Icons.checkroom,
  EquipmentSlot.shield: Icons.shield_outlined, // Added shield placeholder
};

/// A widget that loads and displays a specific sprite from a spritesheet.
class ItemSpriteWidget extends StatefulWidget {
  final InventoryItem item;
  final Size size;

  final BoxFit fit;

  const ItemSpriteWidget({
    super.key,
    required this.item,
    this.size = const Size(40, 40),
    this.fit = BoxFit.contain, // Default to contain to preserve aspect ratio
  });

  @override
  _ItemSpriteWidgetState createState() => _ItemSpriteWidgetState();
}

class _ItemSpriteWidgetState extends State<ItemSpriteWidget> {
  ui.Image? _spritesheetImage;
  Rect? _spriteRect;
  bool _isLoading = true;

  Size _spriteSourceSize = Size(64, 64); // Default, will be updated

  @override
  void initState() {
    super.initState();
    _loadSpriteData();
  }

  @override
  void didUpdateWidget(covariant ItemSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if the item (and thus sprite/quality) changes
    if (widget.item.id != oldWidget.item.id ||
        widget.item.quality != oldWidget.item.quality) {
      _loadSpriteData();
    }
  }

  /// This cache is now local to the widget's state to avoid service-level errors.
  /// A better solution would be a proper singleton service, but this will work.
  static final Map<String, ui.Image> _imageCache = {};

  Future<ui.Image> _loadSpritesheet(String assetPath) async {
    if (_imageCache.containsKey(assetPath)) {
      return _imageCache[assetPath]!;
    }
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      _imageCache[assetPath] = frameInfo.image;
      return frameInfo.image;
    } catch (e) {
      print("Error loading spritesheet $assetPath: $e");
      rethrow;
    }
  }

  Future<void> _loadSpriteData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final spriteInfo = SpriteService.getSpriteInfo(widget.item.itemType);
    if (spriteInfo == null) {
      print("Warning: No sprite info for ${widget.item.itemType}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _spritesheetImage = null;
          _spriteRect = null;
        });
      }
      return;
    }

    _spriteSourceSize = Size(
        spriteInfo.spriteWidth.toDouble(), spriteInfo.spriteHeight.toDouble());

    final int spriteIndex = SpriteService.getSpriteIndexForQuality(
        widget.item.itemType, widget.item.quality);

    final rect =
        SpriteService.calculateSpriteRect(widget.item.itemType, spriteIndex);

    if (rect == null) {
      print("Warning: Could not calculate sprite rect for ${widget.item.name}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _spritesheetImage = null;
          _spriteRect = null;
        });
      }
      return;
    }

    try {
      final ui.Image image = await _loadSpritesheet(spriteInfo.assetPath);

      if (mounted) {
        setState(() {
          _spritesheetImage = image;
          _spriteRect = rect;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading sprite for ${widget.item.name}: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _spritesheetImage = null;
          _spriteRect = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Colors.white30,
          ),
        ),
      );
    }

    if (_spritesheetImage == null || _spriteRect == null) {
      // Fallback to placeholder icon
      return SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: Icon(
          _placeholderIconMap[widget.item.equippableSlot] ??
              Icons.inventory_2_outlined,
          color: Colors.grey[700],
          size: widget.size.width * 0.8,
        ),
      );
    }

    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: CustomPaint(
        painter: SpritePainter(
          image: _spritesheetImage!,
          srcRect: _spriteRect!,
          fit: widget.fit,
          // Pass the sprite's native size
          spriteSourceSize: _spriteSourceSize,
        ),
      ),
    );
  }
}

/// CustomPainter to draw a specific part of a larger image (spritesheet).
class SpritePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect; // The source rectangle (from the spritesheet)

  final BoxFit fit;
  final Size spriteSourceSize;

  SpritePainter({
    required this.image,
    required this.srcRect,
    this.fit = BoxFit.contain,
    required this.spriteSourceSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // This applies BoxFit.contain or BoxFit.cover, preserving aspect ratio
    final FittedSizes fittedSizes = applyBoxFit(fit, spriteSourceSize, size);
    final Rect dstRect = Alignment.center.inscribe(
        fittedSizes.destination, Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw the specified part of the image onto the canvas
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant SpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.srcRect != srcRect ||
        oldDelegate.fit != fit ||
        oldDelegate.spriteSourceSize != spriteSourceSize;
  }
}
