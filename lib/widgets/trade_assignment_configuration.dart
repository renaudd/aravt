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
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/inventory_item.dart';
import '../providers/game_state.dart';
import '../widgets/item_sprite_widget.dart';

class TradeAssignmentConfiguration extends StatefulWidget {
  final Function(String?) onOptionsChanged;
  final List<String> selectedAravtIds;

  const TradeAssignmentConfiguration({
    super.key,
    required this.onOptionsChanged,
    required this.selectedAravtIds,
  });

  @override
  State<TradeAssignmentConfiguration> createState() =>
      _TradeAssignmentConfigurationState();
}

class _TradeAssignmentConfigurationState
    extends State<TradeAssignmentConfiguration> {
  // Selected IDs
  final Set<String> _selectedItemIds = {};
  final Set<String> _selectedHorseIds = {};
  final Map<String, double> _selectedResources = {};

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final stash = gameState.communalStash;
    final herd = gameState.communalHerd;

    // Calculate Stats
    double totalWeight = 0;
    double totalValue = 0;
    double totalScrap = 0;

    // Items
    for (var item in stash) {
      if (_selectedItemIds.contains(item.id)) {
        totalWeight += item.weight;
        if (item.valueType == ValueType.Treasure) {
          totalValue += item.baseValue;
        } else {
          totalScrap += item.baseValue;
        }
      }
    }

    // Resources
    _selectedResources.forEach((key, amount) {
      // Approximate weights/values
      switch (key) {
        case 'scrap':
          totalScrap += amount; // 1:1
          totalWeight += amount * 0.1; // 0.1kg per scrap?
          break;
        case 'rupees':
          totalValue += amount; // 1:1
          // No weight for coins?
          break;
        case 'wood':
          totalWeight += amount * 1.0; // 1kg
          totalScrap += amount * 0.5; // 0.5 value?
          break;
        case 'iron':
          totalWeight += amount * 2.0;
          totalScrap += amount * 2.0;
          break;
        case 'meat':
          totalWeight += amount * 1.0;
          totalScrap += amount * 0.5;
          break;
        case 'rice':
          totalWeight += amount * 1.0;
          totalScrap += amount * 0.5;
          break;
        case 'short_arrows':
          totalWeight += amount * 0.05;
          totalScrap += amount * 0.1;
          break;
        case 'long_arrows':
          totalWeight += amount * 0.08;
          totalScrap += amount * 0.2;
          break;
      }
    });

    // Horse Capacity
    double horseCapacity = 0;
    for (var horse in herd) {
      if (_selectedHorseIds.contains(horse.id)) {
        horseCapacity += (100.0 + (horse.might * 10.0));
      }
    }

    // Aravt Capacity (Soldiers)
    int soldierCount = 0;
    for (var aravtId in widget.selectedAravtIds) {
      var aravt = gameState.aravts.firstWhere((a) => a.id == aravtId,
          orElse: () => gameState.aravts.first);
      soldierCount += aravt.soldierIds.length;
    }
    double soldierCapacity = soldierCount * 20.0;

    double totalCapacity = horseCapacity + soldierCapacity;

    bool overloaded = totalWeight > totalCapacity;
    double loadRatio = totalCapacity > 0
        ? totalWeight / totalCapacity
        : (totalWeight > 0 ? 999.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Stats Header ---
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("Weight", "${totalWeight.toStringAsFixed(1)} kg",
                  overloaded ? Colors.red : Colors.white),
              _buildStat("Capacity", "${totalCapacity.toStringAsFixed(1)} kg",
                  Colors.white70),
              _buildStat(
                  "Value", "${totalValue.toStringAsFixed(0)} ₹", Colors.amber),
              _buildStat("Scrap", "${totalScrap.toStringAsFixed(0)} §",
                  Colors.blue[200]!),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Main Content (2 Columns) ---
        Expanded(
          child: Row(
            children: [
              // Source Column
              Expanded(
                child: _buildInventoryColumn(
                  title: "Communal Storage",
                  items: stash
                      .where((i) => !_selectedItemIds.contains(i.id))
                      .toList(),
                  horses: herd
                      .where((h) => !_selectedHorseIds.contains(h.id))
                      .toList(),
                  isSource: true,
                  gameState: gameState,
                ),
              ),
              // Transfer Arrows Center
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compare_arrows, color: Colors.white54),
                ],
              ),
              // Destination Column
              Expanded(
                child: _buildInventoryColumn(
                  title: "Trade Delegation",
                  items: stash
                      .where((i) => _selectedItemIds.contains(i.id))
                      .toList(),
                  horses: herd
                      .where((h) => _selectedHorseIds.contains(h.id))
                      .toList(),
                  isSource: false,
                  gameState: gameState,
                ),
              ),
            ],
          ),
        ),

        if (overloaded)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "WARNING: Overloaded! Travel speed will be significantly reduced.",
              style: GoogleFonts.cinzel(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          )
        else if (loadRatio > 0.0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Load Efficiency: ${(100.0 / (loadRatio > 1.0 ? loadRatio : 1.0)).toStringAsFixed(0)}%",
              style:
                  GoogleFonts.cinzel(color: Colors.greenAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style:
                GoogleFonts.cinzel(color: color, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildInventoryColumn({
    required String title,
    required List<InventoryItem> items,
    required List<Mount> horses,
    required bool isSource,
    required GameState gameState,
  }) {
    // Helper to get available amount
    double getAvailable(String key) {
      switch (key) {
        case 'scrap':
          return gameState.communalScrap;
        case 'rupees':
          return gameState.communalRupees;
        case 'wood':
          return gameState.communalWood;
        case 'iron':
          return gameState.communalIronOre;
        case 'meat':
          return gameState.communalMeat;
        case 'rice':
          return gameState.communalRice;
        case 'short_arrows':
          return gameState.communalShortArrows.toDouble();
        case 'long_arrows':
          return gameState.communalLongArrows.toDouble();
        default:
          return 0;
      }
    }

    final resources = [
      'scrap',
      'rupees',
      'wood',
      'iron',
      'meat',
      'rice',
      'short_arrows',
      'long_arrows'
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                Text(title, style: GoogleFonts.cinzel(color: Colors.white70)),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              children: [
                // Resources
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text("Resources",
                      style: TextStyle(color: Colors.white30, fontSize: 10)),
                ),
                ...resources.map((key) {
                  final available = getAvailable(key);
                  final selected = _selectedResources[key] ?? 0.0;
                  final displayAmount =
                      isSource ? (available - selected) : selected;

                  if (displayAmount <= 0 && isSource) return const SizedBox();
                  if (displayAmount <= 0 && !isSource) return const SizedBox();

                  return _buildResourceTile(
                      key, displayAmount, isSource, available);
                }),

                if (horses.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text("Horses",
                        style: TextStyle(color: Colors.white30, fontSize: 10)),
                  ),
                  ...horses.map((h) => _buildHorseTile(h, isSource)),
                ],
                if (items.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text("Items",
                        style: TextStyle(color: Colors.white30, fontSize: 10)),
                  ),
                  ...items.map((i) => _buildItemTile(i, isSource)),
                ],
                if (items.isEmpty &&
                    horses.isEmpty &&
                    _isResourcesEmpty(isSource))
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                        child: Text("Empty",
                            style: TextStyle(color: Colors.white24))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isResourcesEmpty(bool isSource) {
    if (!isSource)
      return _selectedResources.isEmpty ||
          _selectedResources.values.every((v) => v <= 0);
    // For source, simplified check - usually not empty unless totally broke
    return false;
  }

  Widget _buildResourceTile(
      String key, double amount, bool isSource, double maxAvailable) {
    String label = key.toUpperCase().replaceAll('_', ' ');
    IconData icon = Icons.circle; // Default
    Color color = Colors.grey;

    switch (key) {
      case 'scrap':
        icon = Icons.grid_3x3;
        color = Colors.blue[200]!;
        break;
      case 'rupees':
        icon = Icons.monetization_on;
        color = Colors.amber;
        break;
      case 'wood':
        icon = Icons.forest;
        color = Colors.brown;
        break;
      case 'iron':
        icon = Icons.hexagon;
        color = Colors.blueGrey;
        break;
      case 'meat':
        icon = Icons.restaurant;
        color = Colors.red[300]!;
        break;
      case 'rice':
        icon = Icons.agriculture;
        color = Colors.yellow[100]!;
        break;
      case 'short_arrows':
        icon = Icons.arrow_right_alt;
        color = Colors.white70;
        break;
      case 'long_arrows':
        icon = Icons.keyboard_double_arrow_right;
        color = Colors.orange[200]!;
        break;
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      subtitle: Text(amount.toStringAsFixed(0),
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
      trailing: IconButton(
        icon: Icon(isSource ? Icons.arrow_forward : Icons.arrow_back,
            size: 16, color: Colors.white70),
        onPressed: () {
          if (isSource) {
            _showQuantityDialog(
                key, maxAvailable - (_selectedResources[key] ?? 0));
          } else {
            // Remove all from destination (or could ask quantity too)
            setState(() {
              _selectedResources.remove(key);
              _updateOptions();
            });
          }
        },
      ),
    );
  }

  void _showQuantityDialog(String key, double maxAmount) {
    showDialog(
        context: context,
        builder: (context) {
          final controller =
              TextEditingController(text: maxAmount.toInt().toString());
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("Transfer ${key.replaceAll('_', ' ')}",
                style: GoogleFonts.cinzel(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Available: ${maxAmount.toInt()}",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                // Slider?
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black),
                child: const Text("Transfer"),
                onPressed: () {
                  final val = double.tryParse(controller.text) ?? 0;
                  if (val > 0) {
                    setState(() {
                      // Add to selected
                      final current = _selectedResources[key] ?? 0;
                      double actualAdd = val;
                      if (current + actualAdd > (current + maxAmount)) {
                        actualAdd = maxAmount; // Cap at max available
                      }
                      _selectedResources[key] = current + actualAdd;
                      _updateOptions();
                    });
                  }
                  Navigator.pop(context);
                },
              )
            ],
          );
        });
  }

  Widget _buildItemTile(InventoryItem item, bool isSource) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: ItemSpriteWidget(item: item, size: const Size(24, 24)),
      title: Text(item.name,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      subtitle: Text("${item.weight}kg",
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
      trailing: IconButton(
        icon: Icon(isSource ? Icons.arrow_forward : Icons.arrow_back,
            size: 16, color: Colors.white70),
        onPressed: () {
          setState(() {
            if (isSource) {
              _selectedItemIds.add(item.id);
            } else {
              _selectedItemIds.remove(item.id);
            }
            _updateOptions();
          });
        },
      ),
    );
  }

  Widget _buildHorseTile(Mount horse, bool isSource) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.pets, color: Colors.orangeAccent, size: 20),
      title: Text(horse.name,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      subtitle: Text("Might: ${horse.might}",
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
      trailing: IconButton(
        icon: Icon(isSource ? Icons.arrow_forward : Icons.arrow_back,
            size: 16, color: Colors.white70),
        onPressed: () {
          setState(() {
            if (isSource) {
              _selectedHorseIds.add(horse.id);
            } else {
              _selectedHorseIds.remove(horse.id);
            }
            _updateOptions();
          });
        },
      ),
    );
  }

  void _updateOptions() {
    final options = {
      'cargoItemIds': _selectedItemIds.toList(),
      'horseIds': _selectedHorseIds.toList(),
      'resources': _selectedResources,
    };
    widget.onOptionsChanged(jsonEncode(options));
  }
}
