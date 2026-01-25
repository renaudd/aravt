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
import 'package:aravt/widgets/item_sprite_widget.dart';
import 'package:aravt/widgets/equipped_gear_view.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';

class SoldierProfileInventoryPanel extends StatelessWidget {
  final Soldier soldier;
  const SoldierProfileInventoryPanel({super.key, required this.soldier});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final bool isInteractive = soldier.isPlayer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Equipped Gear Panel ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              EquippedGearView(soldier: soldier, isInteractive: isInteractive),
        ),

        // --- Inventory Grid ---
        Expanded(child: _buildInventoryGrid(context, gameState, isInteractive)),
      ],
    );
  }

  Widget _buildInventoryGrid(
      BuildContext context, GameState gameState, bool isInteractive) {
    final inventory = soldier.personalInventory;

    return DragTarget<InventoryItem>(
      onWillAccept: (item) => isInteractive && item?.equippableSlot != null,
      onAccept: (item) {
        gameState.unequipItemFromSoldier(soldier, item.equippableSlot!);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isReceiving = isInteractive && candidateData.isNotEmpty;

        return Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isReceiving ? Colors.greenAccent : Colors.white30),
            ),
            child: Column(
              children: [
                Text("Personal Items",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('Scrap: ${soldier.fungibleScrap.toStringAsFixed(0)}',
                        style: GoogleFonts.cinzel(
                            color: Colors.white, fontSize: 14)),
                    Text('Rupees: ${soldier.fungibleRupees.toStringAsFixed(0)}',
                        style: GoogleFonts.cinzel(
                            color: Colors.white, fontSize: 14)),
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
                            final Widget tile = _buildItemTile(item);

                            if (isInteractive && item.equippableSlot != null) {
                              return Draggable<InventoryItem>(
                                data: item,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 300,
                                    child:
                                        _buildItemTile(item, isDragging: true),
                                  ),
                                ),
                                childWhenDragging:
                                    Opacity(opacity: 0.4, child: tile),
                                child: tile,
                              );
                            }
                            return tile;
                          },
                        ),
                ),
              ],
            ));
      },
    );
  }

  Widget _buildItemTile(InventoryItem item, {bool isDragging = false}) {
    return Tooltip(
      message: item.description,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        color: isDragging ? Colors.black54 : Colors.black.withOpacity(0.3),
        child: ListTile(
          leading: ItemSpriteWidget(
            item: item,
            size: const Size(40, 40),
          ),
          title:
              Text(item.name, style: GoogleFonts.cinzel(color: Colors.white)),
          subtitle: Text(
            "Type: ${item.itemType.name} | Quality: ${item.quality ?? 'Standard'}",
            style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12),
          ),
          trailing: Text(
            "Val: ${item.baseValue.toStringAsFixed(0)} ${item.valueType.name}",
            style: GoogleFonts.cinzel(color: Colors.amber, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
