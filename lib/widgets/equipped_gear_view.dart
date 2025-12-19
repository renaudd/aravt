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
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/widgets/item_sprite_widget.dart';

class EquippedGearView extends StatelessWidget {
  final Soldier soldier;
  final bool isInteractive;

  const EquippedGearView({
    super.key,
    required this.soldier,
    this.isInteractive = false,
  });

  static const Map<EquipmentSlot, Size> _kSlotDimensions = {
    EquipmentSlot.helmet: Size(64, 64),
    EquipmentSlot.armor: Size(64, 80),
    EquipmentSlot.gauntlets: Size(48, 48),
    EquipmentSlot.boots: Size(48, 48),
    EquipmentSlot.longBow: Size(48, 128),
    EquipmentSlot.shortBow: Size(48, 96),
    EquipmentSlot.spear: Size(32, 128),
    EquipmentSlot.melee: Size(48, 96),
    EquipmentSlot.mount: Size(80, 80),
    EquipmentSlot.necklace: Size(32, 32),
    EquipmentSlot.ring: Size(32, 32),
    EquipmentSlot.undergarments: Size(64, 64),
    EquipmentSlot.shield: Size(64, 64),
    EquipmentSlot.trophy: Size(48, 48),
  };

  // Helper maps for placeholder icons
  static const Map<EquipmentSlot, IconData> _placeholderIcons = {
    EquipmentSlot.helmet: Icons.headset,
    EquipmentSlot.armor: Icons.shield,
    EquipmentSlot.gauntlets: Icons.pan_tool,
    EquipmentSlot.boots: Icons.ice_skating,
    EquipmentSlot.longBow: Icons.arrow_upward,
    EquipmentSlot.shortBow: Icons.arrow_back,
    EquipmentSlot.spear: Icons.north_east,
    EquipmentSlot.melee: Icons.gavel,
    EquipmentSlot.mount: Icons.pets,
    EquipmentSlot.necklace: Icons.donut_small,
    EquipmentSlot.ring: Icons.circle_outlined,
    EquipmentSlot.undergarments: Icons.accessibility,
    EquipmentSlot.shield: Icons.shield_outlined,
    EquipmentSlot.trophy: Icons.emoji_events,
  };

  @override
  Widget build(BuildContext context) {
    const double panelWidth = 320;
    const double silhouetteHeight = 400;
    const double silhouetteWidth = 150;
    const double centerOfSilhouette = panelWidth / 2;

    return Container(
      width: panelWidth,
      height: silhouetteHeight + 50, // Slightly taller for bottom slots
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D5C1).withOpacity(0.3)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Silhouette
          Positioned(
            top: 20,
            left: (panelWidth - silhouetteWidth) / 2,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/mongol_silhouette.png',
                width: silhouetteWidth,
                height: silhouetteHeight,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),

          // --- SLOTS ---
          // Center Column
          _buildSlot(context, EquipmentSlot.helmet,
              top: 8, left: centerOfSilhouette - 30),
          _buildSlot(context, EquipmentSlot.necklace,
              top: 75, left: centerOfSilhouette - 16),
          _buildSlot(context, EquipmentSlot.armor,
              top: 110, left: centerOfSilhouette - 30),
          _buildSlot(context, EquipmentSlot.undergarments,
              top: 200, left: centerOfSilhouette - 30),
          _buildSlot(context, EquipmentSlot.boots,
              top: 360, left: centerOfSilhouette - 24),

          // Left Column (Weapons)
          _buildSlot(context, EquipmentSlot.longBow, top: 8, left: 8),
          _buildSlot(context, EquipmentSlot.shortBow, top: 145, left: 8),
          _buildSlot(context, EquipmentSlot.spear, top: 250, left: 8),

          // Inner Left (Melee)
          _buildSlot(context, EquipmentSlot.melee, top: 160, left: 70),

          // Right Column (Off-hand/Accessories)
          _buildSlot(context, EquipmentSlot.gauntlets, top: 115, right: 60),
          _buildSlot(context, EquipmentSlot.shield, top: 172, right: 40),
          _buildSlot(context, EquipmentSlot.ring, top: 242, right: 70),
          _buildSlot(context, EquipmentSlot.trophy, top: 8, right: 8),

          // Bottom (Mount)
          _buildSlot(context, EquipmentSlot.mount, bottom: 8, right: 8),
        ],
      ),
    );
  }

  Widget _buildSlot(BuildContext context, EquipmentSlot slot,
      {double? top, double? bottom, double? left, double? right}) {
    final item = soldier.equippedItems[slot];
    final size = _kSlotDimensions[slot]!;

    Widget slotWidget = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(
            color:
                item != null ? Colors.amber.withOpacity(0.6) : Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: item != null
          ? Tooltip(
              message: "${item.name}\n${item.description}",
              child: ItemSpriteWidget(item: item, size: size),
            )
          : Icon(
              _placeholderIcons[slot],
              color: Colors.white10,
              size: size.width * 0.5,
            ),
    );

    if (isInteractive) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: DragTarget<InventoryItem>(
          onWillAccept: (data) => data?.equippableSlot == slot,
          onAccept: (data) {
            Provider.of<GameState>(context, listen: false).equipItem(data);
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                border: candidateData.isNotEmpty
                    ? Border.all(color: Colors.greenAccent, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: item != null
                  ? Draggable<InventoryItem>(
                      data: item,
                      feedback: Material(
                        color: Colors.transparent,
                        child: ItemSpriteWidget(item: item, size: size * 1.1),
                      ),
                      childWhenDragging:
                          Opacity(opacity: 0.3, child: slotWidget),
                      child: slotWidget,
                    )
                  : slotWidget,
            );
          },
        ),
      );
    } else {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: slotWidget,
      );
    }
  }
}
