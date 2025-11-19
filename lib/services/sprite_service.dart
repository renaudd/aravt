// services/sprite_service.dart

import 'package:flutter/material.dart'; // For Rect
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui; // For ui.Image
import 'dart:typed_data';
import 'dart:async'; // For Completer
import '../models/inventory_item.dart'; // To access ItemType

// Simple class to hold spritesheet details
class SpriteInfo {
  final String assetPath;
  final int spriteWidth;
  final int spriteHeight;
  final int spriteCount;

  const SpriteInfo({
    required this.assetPath,
    required this.spriteWidth,
    required this.spriteHeight,
    required this.spriteCount,
  });
}

class SpriteService {
  // --- NEW: A static cache for loaded spritesheet images ---
  static final Map<String, ui.Image> _imageCache = {};
  // --- END NEW ---

  // Define quality tiers - maps quality string to an index level
  static const List<String> qualityTiers = [
    'Worn', // Index 0
    'Humble', // Index 1
    'Good', // Index 2
    'Excellent', // Index 3
    'Masterwork', // Index 4 (Add more as needed)
    'Legendary', // Index 5
  ];

  // Map ItemType to its corresponding spritesheet info
  static const Map<ItemType, SpriteInfo> _spriteSheetData = {
    ItemType.necklace: SpriteInfo(
      assetPath: 'assets/images/items/necklaces_items.png',
      spriteWidth: 250,
      spriteHeight: 250,
      spriteCount: 13,
    ),
    ItemType.ring: SpriteInfo(
      assetPath: 'assets/images/items/rings_items.png',
      spriteWidth: 200,
      spriteHeight: 200,
      spriteCount: 12,
    ),
    ItemType.gauntlets: SpriteInfo(
      assetPath: 'assets/images/items/gauntlets_items.png',
      spriteWidth: 250,
      spriteHeight: 250,
      spriteCount: 8,
    ),
    ItemType.boots: SpriteInfo(
      assetPath: 'assets/images/items/boots_items.png',
      spriteWidth: 200,
      spriteHeight: 220,
      spriteCount: 5,
    ),
    ItemType.armor: SpriteInfo(
      assetPath: 'assets/images/items/armor_items.png',
      spriteWidth: 250,
      spriteHeight: 300,
      spriteCount: 4,
    ),
    ItemType.undergarments: SpriteInfo(
      assetPath: 'assets/images/items/undergarments_items.png',
      spriteWidth: 200,
      spriteHeight: 250,
      spriteCount: 4,
    ),
    ItemType.helmet: SpriteInfo(
      assetPath: 'assets/images/items/helmets_items.png',
      spriteWidth: 250,
      spriteHeight: 300,
      spriteCount: 12,
    ),
    ItemType.spear: SpriteInfo(
      assetPath: 'assets/images/items/lance_spears_items.png', 
      spriteWidth: 150,
      spriteHeight: 350,
      spriteCount: 4, 
    ),
    // --- NEW: Added specific entry for throwingSpear ---
    ItemType.throwingSpear: SpriteInfo(
      assetPath: 'assets/images/items/throwing_spears_items.png',
      spriteWidth: 150, // Assuming same dims, update if needed
      spriteHeight: 350,
      spriteCount: 4, 
    ),
    // --- END NEW ---
    ItemType.shield: SpriteInfo(
      assetPath: 'assets/images/items/shields_items.png',
      spriteWidth: 200,
      spriteHeight: 250,
      spriteCount: 16,
    ),
    ItemType.bow: SpriteInfo(
      assetPath: 'assets/images/items/bows_items.png',
      spriteWidth: 100,
      spriteHeight: 500,
      spriteCount: 6,
    ),
    ItemType.sword: SpriteInfo(
      assetPath: 'assets/images/items/swords_items.png',
      spriteWidth: 100,
      spriteHeight: 500,
      spriteCount: 6,
    ),
    ItemType.ammunition: SpriteInfo(
      assetPath: 'assets/images/items/arrows_items.png',
      spriteWidth: 200,
      spriteHeight: 450,
      spriteCount: 6,
    ),
    ItemType.mount: SpriteInfo(
      assetPath: 'assets/images/items/horses_spritesheet.png', // Placeholder
      spriteWidth: 200,
      spriteHeight: 200,
      spriteCount: 5, 
    ),
    ItemType.consumable: SpriteInfo(
      assetPath: 'assets/images/items/consumables_spritesheet.png', // Placeholder
      spriteWidth: 50,
      spriteHeight: 50,
      spriteCount: 10, 
    ),
    ItemType.misc: SpriteInfo(
        assetPath: 'assets/images/items/placeholder_spritesheet.png', 
        spriteWidth: 50,
        spriteHeight: 50,
        spriteCount: 1),
  };

  /// Gets the SpriteInfo for a given ItemType.
  static SpriteInfo? getSpriteInfo(ItemType itemType) {
    // --- NEW: Handle specific throwing spear ---
    if (itemType == ItemType.throwingSpear) {
      return _spriteSheetData[ItemType.throwingSpear];
    }
    // --- END NEW ---
    return _spriteSheetData[itemType];
  }

  // --- NEW: Caching Image Loader ---
  /// Loads a spritesheet image from assets and caches it.
  static Future<ui.Image> loadSpritesheet(String assetPath) async {
    // 1. Check cache
    if (_imageCache.containsKey(assetPath)) {
      return _imageCache[assetPath]!;
    }

    // 2. Load from assets
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      // 3. Store in cache and return
      _imageCache[assetPath] = frameInfo.image;
      return frameInfo.image;
    } catch (e) {
      print("Error loading spritesheet $assetPath: $e");
      rethrow;
    }
  }
  // --- END NEW ---

  /// Calculates the sprite index based on quality.
  static int getSpriteIndexForQuality(ItemType itemType, String? quality) {
    final info = getSpriteInfo(itemType);
    if (info == null || quality == null) {
      return 0; // Default to the first sprite
    }

    int qualityIndex = qualityTiers.indexOf(quality);
    if (qualityIndex == -1) {
      qualityIndex = 1; // Default to "Humble"
      print("Warning: Quality '$quality' not found in qualityTiers. Defaulting index.");
    }

    return qualityIndex.clamp(0, info.spriteCount - 1);
  }

  /// Calculates the actual Rect for the sprite.
  static Rect? calculateSpriteRect(ItemType itemType, int spriteIndex) {
    final info = getSpriteInfo(itemType);
    if (info == null) return null;

    final index = spriteIndex.clamp(0, info.spriteCount - 1);
    final double left = (index * info.spriteWidth).toDouble();
    const double top = 0.0; // Spritesheets are horizontal

    return Rect.fromLTWH(
        left, top, info.spriteWidth.toDouble(), info.spriteHeight.toDouble());
  }
}

