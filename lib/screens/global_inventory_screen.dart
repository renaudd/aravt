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
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/widgets/item_sprite_widget.dart';
import 'package:aravt/widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/equipped_gear_view.dart';

class GlobalInventoryScreen extends StatelessWidget {
  const GlobalInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InventoryView(showMenu: true);
  }
}

class InventoryView extends StatelessWidget {
  final bool showMenu;
  const InventoryView({super.key, this.showMenu = false});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: showMenu
            ? AppBar(
                title: Text("Inventory", style: GoogleFonts.cinzel()),
                backgroundColor: Colors.black.withOpacity(0.5),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                bottom: const TabBar(
                  indicatorColor: Colors.amber,
                  tabs: [
                    Tab(icon: Icon(Icons.person_outline), text: "Khan"),
                    Tab(icon: Icon(Icons.groups_outlined), text: "Communal"),
                    Tab(icon: Icon(Icons.public_outlined), text: "Global"),
                  ],
                ),
              )
            : null,
        body: Stack(
          children: [
            TabBarView(
              children: [
                const PersonalInventoryTab(),
                const CommunalInventoryTab(),
                GlobalInventoryTab(isOmniscient: gameState.isOmniscientMode),
              ],
            ),
            if (showMenu) const PersistentMenuWidget(),
          ],
        ),
      ),
    );
  }
}

// --- Tab 1: Personal Inventory ---
class PersonalInventoryTab extends StatelessWidget {
  const PersonalInventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final khan = gameState.khan;

    if (khan == null) {
      return const Center(child: Text("Khan not found"));
    }

    final bool isPlayerKhan = gameState.isPlayerLeader;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/steppe_background.jpg'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child:
                  EquippedGearView(soldier: khan, isInteractive: isPlayerKhan),
            ),
            Expanded(child: _buildInventoryList(context, gameState, khan)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList(
      BuildContext context, GameState gameState, Soldier targetSoldier) {
    final List<InventoryItem> inventory = targetSoldier.personalInventory;
    final bool isPlayerKhan = gameState.isPlayerLeader;

    return DragTarget<InventoryItem>(
      builder: (context, candidateData, rejectedData) {
        final bool isReceiving = candidateData.isNotEmpty &&
            candidateData.first?.equippableSlot != null &&
            isPlayerKhan;

        return Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isReceiving ? Colors.greenAccent : Colors.white30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text("${targetSoldier.name}'s Inventory",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: inventory.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final item = inventory[index];
                    return Draggable<InventoryItem>(
                      data: item,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                            width: 300,
                            child: _buildItemTile(item, isDragging: true)),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildItemTile(item),
                      ),
                      child: _buildItemTile(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      onWillAccept: (item) => item?.equippableSlot != null && isPlayerKhan,
      onAccept: (item) {
        context
            .read<GameState>()
            .unequipItemFromSoldier(targetSoldier, item.equippableSlot!);
      },
    );
  }

  Widget _buildItemTile(InventoryItem item, {bool isDragging = false}) {
    return Container(
        color: isDragging ? Colors.black54 : Colors.transparent,
        child: ListTile(
          leading: ItemSpriteWidget(item: item, size: const Size(48, 48)),
          title:
              Text(item.name, style: GoogleFonts.cinzel(color: Colors.white)),
          subtitle: Text(
            "${item.itemType.name} | ${item.quality ?? 'Standard'} | ${item.origin}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: Text(
            "${item.baseValue.toStringAsFixed(0)} ${item.valueType == ValueType.Treasure ? '₹' : '§'}",
            style: GoogleFonts.cinzel(
                color: item.valueType == ValueType.Treasure
                    ? Colors.amber
                    : Colors.white),
          ),
        ));
  }
}

// --- Tab 2: Communal Inventory (Ledger Style) ---
class CommunalInventoryTab extends StatefulWidget {
  const CommunalInventoryTab({super.key});

  @override
  State<CommunalInventoryTab> createState() => _CommunalInventoryTabState();
}

class _CommunalInventoryTabState extends State<CommunalInventoryTab> {
  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final ledgerEntries = _generateLedger(gameState);

    double totalTreasure = 0;
    double totalSupplies = 0;

    // Calculate totals from entries (parsing strings)
    for (var entry in ledgerEntries) {
      double qty = double.tryParse(entry.quantity.split(' ').first) ?? 0;
      double rVal = double.tryParse(entry.rupeeValue) ?? 0;
      double sVal = double.tryParse(entry.scrapValue) ?? 0;

      totalTreasure += rVal * qty;
      totalSupplies += sVal * qty;
    }
    // Add liquid currency
    totalSupplies += gameState.communalScrap;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/steppe_background.jpg'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0D5C1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Wealth Summary ---
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.white24, width: 2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWealthSummary(
                        Icons.monetization_on,
                        "Treasure Wealth",
                        "${totalTreasure.toStringAsFixed(0)} ₹",
                        Colors.amber),
                    _buildWealthSummary(
                        Icons.build,
                        "Supply Wealth",
                        "${totalSupplies.toStringAsFixed(0)} §",
                        Colors.blue[200]!),
                  ],
                ),
              ),
              // --- Ledger Table ---
              Expanded(
                child: _buildLedgerTable(ledgerEntries, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_LedgerEntry> _generateLedger(GameState gameState) {
    List<_LedgerEntry> entries = [];

    // --- RESOURCES ---
    if (gameState.communalMeat > 0) {
      double val = 2.0;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.kebab_dining, color: Colors.redAccent, size: 24),
        name: "Meat (Raw)",
        quantity: gameState.communalMeat.toStringAsFixed(0),
        weight: gameState.communalMeat.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Normal',
        origin: 'Gathered',
        type: 'Food',
        totalValueRaw: gameState.communalMeat * val,
      ));
    }
    if (gameState.communalRice > 0) {
      double val = 1.0;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.rice_bowl, color: Colors.white, size: 24),
        name: "Rice",
        quantity: gameState.communalRice.toStringAsFixed(0),
        weight: gameState.communalRice.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Normal',
        origin: 'Gathered',
        type: 'Food',
        totalValueRaw: gameState.communalRice * val,
      ));
    }
    if (gameState.communalWood > 0) {
      double val = 0.5;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.forest, color: Colors.brown, size: 24),
        name: "Wood",
        quantity: gameState.communalWood.toStringAsFixed(0),
        weight: gameState.communalWood.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Normal',
        origin: 'Gathered',
        type: 'Material',
        totalValueRaw: gameState.communalWood * val,
      ));
    }
    if (gameState.communalIronOre > 0) {
      double val = 1.0;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.landscape, color: Colors.grey, size: 24),
        name: "Iron Ore",
        quantity: gameState.communalIronOre.toStringAsFixed(0),
        weight: gameState.communalIronOre.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Raw',
        origin: 'Mined',
        type: 'Ore',
        totalValueRaw: gameState.communalIronOre * val,
      ));
    }
    if (gameState.communalScrap > 0) {
      double val = 1.0;
      entries.add(_LedgerEntry(
        icon: Icon(Icons.build, color: Colors.blue[200]!, size: 24),
        name: "Scrap",
        quantity: gameState.communalScrap.toStringAsFixed(0),
        weight: (gameState.communalScrap * 0.5).toStringAsFixed(1),
        rupeeValue: '0.1',
        scrapValue: val.toStringAsFixed(1),
        quality: 'Mixed',
        origin: 'Scavenged',
        type: 'Salvage',
        totalValueRaw: gameState.communalScrap * 0.1,
      ));
    }
    if (gameState.communalShortArrows > 0) {
      double val = 0.5;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.arrow_upward, color: Colors.white70, size: 24),
        name: "Short Arrows",
        quantity: '${gameState.communalShortArrows}',
        weight: (gameState.communalShortArrows * 0.05).toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Standard',
        origin: 'Crafted',
        type: 'Ammo',
        totalValueRaw: gameState.communalShortArrows * val,
      ));
    }
    if (gameState.communalLongArrows > 0) {
      double val = 0.7;
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.arrow_upward, color: Colors.white70, size: 24),
        name: "Long Arrows",
        quantity: '${gameState.communalLongArrows}',
        weight: (gameState.communalLongArrows * 0.08).toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Standard',
        origin: 'Crafted',
        type: 'Ammo',
        totalValueRaw: gameState.communalLongArrows * val,
      ));
    }

    // --- COMMUNAL STASH (Grouped) ---
    if (gameState.communalStash.isNotEmpty) {
      final Map<String, List<InventoryItem>> grouped = {};
      for (var item in gameState.communalStash) {
        grouped.putIfAbsent(item.templateId, () => []).add(item);
      }
      grouped.forEach((templateId, items) {
        final prototype = items.first;
        double val =
            prototype.valueType == ValueType.Treasure ? prototype.baseValue : 0;
        double scrap =
            prototype.valueType == ValueType.Supply ? prototype.baseValue : 0;

        entries.add(_LedgerEntry(
          icon: ItemSpriteWidget(item: prototype, size: const Size(24, 24)),
          name: prototype.name,
          quantity: '${items.length}',
          weight: (prototype.weight * items.length).toStringAsFixed(1),
          rupeeValue: val.toStringAsFixed(0),
          scrapValue: scrap.toStringAsFixed(0),
          quality: prototype.quality ?? 'Standard',
          origin: prototype.origin,
          type: prototype.itemType.name,
          totalValueRaw: val * items.length,
        ));
      });
    }

    // --- LIVESTOCK ---
    // Group cattle by age/sex for cleaner ledger
    Map<String, int> cattleGroups = {};
    for (var cow in gameState.communalCattle.animals) {
      String key = "Steppe ${cow.isMale ? 'Bull' : 'Cow'} (${cow.age}y)";
      cattleGroups[key] = (cattleGroups[key] ?? 0) + 1;
    }
    cattleGroups.forEach((name, count) {
      entries.add(_LedgerEntry(
        icon: const Icon(Icons.grass, color: Colors.brown, size: 24),
        name: name,
        quantity: '$count',
        weight: (count * 400).toStringAsFixed(0),
        rupeeValue: '0',
        scrapValue: '200',
        quality: 'Normal',
        origin: 'Herd',
        type: 'Livestock',
        totalValueRaw:
            0, // Cattle have no rupee value currently? Or maybe they do.
      ));
    });

    if (gameState.communalHerd.isNotEmpty) {
      for (var horse in gameState.communalHerd) {
        entries.add(_LedgerEntry(
          icon: const Icon(Icons.pets, color: Colors.orangeAccent, size: 24),
          name: horse.name,
          quantity: '1',
          weight: '350',
          rupeeValue: horse.baseValue.toStringAsFixed(0),
          scrapValue: '0',
          quality: 'Normal',
          origin: 'Herd',
          type: 'Mount',
          totalValueRaw: horse.baseValue,
        ));
      }
    }

    return entries;
  }

  Widget _buildWealthSummary(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Text(value,
                style: GoogleFonts.cinzel(
                    color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label, style: GoogleFonts.cinzel(color: Colors.white70)),
      ],
    );
  }
}

class _LedgerEntry {
  final Widget icon;
  final String name;
  final String quantity;
  final String weight;
  final String rupeeValue;
  final String scrapValue;
  final String quality;
  final String origin;
  final String type;
  final double totalValueRaw;

  _LedgerEntry({
    required this.icon,
    required this.name,
    required this.quantity,
    required this.weight,
    required this.rupeeValue,
    required this.scrapValue,
    required this.quality,
    required this.origin,
    required this.type,
    required this.totalValueRaw,
  });

  String get totalValue => totalValueRaw.toStringAsFixed(0);
}

Widget _buildLedgerTable(List<_LedgerEntry> entries, BuildContext context) {
  if (entries.isEmpty) {
    return const Center(
        child: Padding(
      padding: EdgeInsets.all(16.0),
      child:
          Text("No items in ledger.", style: TextStyle(color: Colors.white54)),
    ));
  }

  // Sort by total value descending by default
  entries.sort((a, b) => b.totalValueRaw.compareTo(a.totalValueRaw));

  return LayoutBuilder(builder: (context, constraints) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columnSpacing: 24,
            horizontalMargin: 12,
            headingTextStyle:
                GoogleFonts.cinzel(color: Colors.white70, fontSize: 12),
            dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Qty'), numeric: true),
              DataColumn(label: Text('Wgt (Kg)'), numeric: true),
              DataColumn(label: Text('Val (₹)'), numeric: true),
              DataColumn(label: Text('Scrap (§)'), numeric: true),
              DataColumn(
                  label: Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('Qual'),
              )),
              DataColumn(label: Text('Origin')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Total (₹)'), numeric: true),
            ],
            rows: entries.map((entry) {
              return DataRow(cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    entry.icon,
                    const SizedBox(width: 8),
                    Text(entry.name),
                  ],
                )),
                DataCell(Text(entry.quantity)),
                DataCell(Text(entry.weight)),
                DataCell(Text(entry.rupeeValue,
                    style: const TextStyle(color: Colors.amber))),
                DataCell(Text(entry.scrapValue,
                    style: TextStyle(color: Colors.blue[200]))),
                DataCell(Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(entry.quality),
                )),
                DataCell(Text(entry.origin)),
                DataCell(Text(entry.type)),
                DataCell(Text(entry.totalValue,
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  });
}

class GlobalInventoryTab extends StatelessWidget {
  final bool isOmniscient;
  const GlobalInventoryTab({super.key, required this.isOmniscient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/steppe_background.jpg'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
              child: Text(
                isOmniscient ? "Horde Totals (Omniscient)" : "Horde Estimates",
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFE0D5C1),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30),
                ),
                child: Center(
                  child: Text(
                    isOmniscient
                        ? "Detailed breakdown of every item owned by every soldier would go here."
                        : "Rough estimates of total fighting strength and supplies based on known information.",
                    style:
                        GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
