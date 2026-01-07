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

// widgets/profile_tabs/soldier_profile_inventory_panel.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/widgets/item_sprite_widget.dart'; // Import the new sprite widget


const Map<EquipmentSlot, IconData> _placeholderIconMap = {
  EquipmentSlot.helmet: Icons.headset,
  EquipmentSlot.armor: Icons.shield,
  EquipmentSlot.shield: Icons.shield,
  EquipmentSlot.gauntlets: Icons.pan_tool,
  EquipmentSlot.boots: Icons.ice_skating,
  EquipmentSlot.longBow: Icons.arrow_back_rounded,
  EquipmentSlot.shortBow: Icons.arrow_back_sharp,
  EquipmentSlot.spear: Icons.chevron_right,
  EquipmentSlot.melee: Icons.gavel,
  EquipmentSlot.mount: Icons.pets,
  EquipmentSlot.necklace: Icons.watch,
  EquipmentSlot.ring: Icons.circle,
  EquipmentSlot.undergarments: Icons.checkroom,
};


class SoldierProfileInventoryPanel extends StatelessWidget {
  final Soldier soldier;
  const SoldierProfileInventoryPanel({super.key, required this.soldier});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Equipped Gear Panel ---
        _buildEquippedGearPanel(context, soldier.equippedItems),

        // --- Inventory Grid ---
        Expanded(
            child: _buildInventoryGrid(context, soldier.personalInventory)),
      ],
    );
  }

  Widget _buildEquippedGearPanel(
      BuildContext context, Map<EquipmentSlot, InventoryItem> equippedItems) {
    const double panelWidth = 200; // Increased width for better layout
    const double silhouetteHeight = 260;
    const double silhouetteWidth = 150;
    const double iconSize = 40;

    return Container(
      width: panelWidth,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
      child: SizedBox(
        height: silhouetteHeight + 60, // Give some padding
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/mongol_silhouette.png',
              width: silhouetteWidth,
              height: silhouetteHeight,
              fit: BoxFit.contain,
              color: Colors.grey[700],
            ),

            // --- Equipment Slots (Read-Only) ---
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.helmet,
                top: 5, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.necklace,
                top: 45, iconSize: iconSize),
            _buildEquipmentSlot(
                context, equippedItems, EquipmentSlot.undergarments,
                top: 75, left: 30, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.armor,
                top: 75, right: 30, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.gauntlets,
                top: 110, right: 15, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.shield,
                top: 110, left: 15, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.ring,
                top: 150, left: 20, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.melee,
                top: 150, right: 20, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.boots,
                bottom: 40, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.mount,
                bottom: 0, left: 20, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.longBow,
                bottom: 0, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.shortBow,
                bottom: 0, right: 50, iconSize: iconSize),
            _buildEquipmentSlot(context, equippedItems, EquipmentSlot.spear,
                bottom: 0, right: 0, iconSize: iconSize),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSlot(BuildContext context,
      Map<EquipmentSlot, InventoryItem> equippedItems, EquipmentSlot slot,
      {double? top,
      double? bottom,
      double? left,
      double? right,
      required double iconSize}) {
    final InventoryItem? item = equippedItems[slot];
    final IconData placeholderIcon =
        _placeholderIconMap[slot] ?? Icons.add_box_outlined;
    final bool hasItem = item != null;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Tooltip(
        message: hasItem ? item.name : slot.name,
        child: Container(
          width: iconSize + 8, // Add padding
          height: iconSize + 8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: hasItem
                ? ItemSpriteWidget(
                    item: item,
                    size: Size(iconSize * 0.9, iconSize * 0.9),
                  )
                : Icon(placeholderIcon,
                    color: Colors.grey, size: iconSize * 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryGrid(
      BuildContext context, List<InventoryItem> inventory) {
    return Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          children: [
            Text("Personal Items",
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Scrap: ${soldier.fungibleScrap.toStringAsFixed(0)}',
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 14)),
                Text('Rupees: ${soldier.fungibleRupees.toStringAsFixed(0)}',
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 14)),
              ],
            ),
            const Divider(color: Colors.white54),
            const SizedBox(height: 4),
            Expanded(
              child: inventory.isEmpty
                  ? Center(
                      child: Text('No personal items.',
                          style: GoogleFonts.cinzel(color: Colors.white70)),
                    )
                  : ListView.builder(
                      itemCount: inventory.length,
                      itemBuilder: (context, index) {
                        final item = inventory[index];
                        return Tooltip(
                          message: item.description,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            color: Colors.black.withOpacity(0.3),
                            child: ListTile(
                              leading: ItemSpriteWidget(
                                item: item,
                                size: Size(40, 40),
                              ),
                              title: Text(item.name,
                                  style:
                                      GoogleFonts.cinzel(color: Colors.white)),
                              subtitle: Text(
                                "Type: ${item.itemType.name} | Quality: ${item.quality ?? 'N/A'}",
                                style:
                                    GoogleFonts.cinzel(color: Colors.white70),
                              ),
                              trailing: Text(
                                "Val: ${item.baseValue.toStringAsFixed(0)} ${item.valueType.name}",
                                style: GoogleFonts.cinzel(color: Colors.amber),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ));
  }
}
