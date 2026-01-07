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
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/herd_data.dart';
import 'package:aravt/models/resource_report.dart';
import 'package:aravt/models/trade_report.dart';
import 'package:aravt/models/culinary_news.dart';
import 'package:aravt/models/fletching_report.dart';
import 'package:aravt/screens/soldier_profile_screen.dart';
import 'package:aravt/widgets/notification_badge.dart';
import '../screens/post_combat_report_screen.dart';
import 'dart:math' as math;

// --- HELPER CLASSES & WIDGETS ---

class _LedgerEntry {
  final IconData icon;
  final String name;
  final String quantity;
  final String weight;
  final String rupeeValue;
  final String scrapValue;
  final String quality;
  final String origin;
  final String type;
  final double totalValueRaw; // For sorting

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
                    Icon(entry.icon, size: 16, color: Colors.white70),
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

// --- COMMON HELPER WIDGETS ---
BoxDecoration _tabBackground() {
  return const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/steppe_background.jpg'),
      fit: BoxFit.cover,
      opacity: 0.3,
    ),
  );
}

Widget _buildEmptyTab(String message) {
  return Container(
    decoration: _tabBackground(),
    child: Center(
      child: Text(
        message,
        style: GoogleFonts.cinzel(fontSize: 20, color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Widget _buildSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    child: Text(title,
        style: GoogleFonts.cinzel(
            color: Colors.amber[200],
            fontSize: 16,
            fontWeight: FontWeight.bold)),
  );
}

// --- INDIVIDUAL TAB WIDGETS ---

class EventLogTab extends StatelessWidget {
  final bool isOmniscient;
  final int? soldierId;
  const EventLogTab(
      {super.key, required this.isOmniscient, required this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    final List<GameEvent> events = gameState.eventLog.where((event) {
      // Soldier-specific filtering
      if (soldierId != null) {
        return event.relatedSoldierId == soldierId;
      }

      // Global reports filtering
      if (!isOmniscient && !event.isPlayerKnown) {
        return false; // Hide unknown events in non-omniscient mode
      }

      //  Filter out NPC-only activities from global reports
      // Keep events that are:
      // 1. Related to player's soldiers
      // 2. Related to player's aravts
      // 3. Critical events (always show)
      // 4. System events (always show)
      if (event.severity == EventSeverity.critical ||
          event.category == EventCategory.system) {
        return true; // Always show critical and system events
      }

      // Check if event is related to player's horde
      if (event.relatedSoldierId != null) {
        final soldier = gameState.findSoldierById(event.relatedSoldierId!);
        if (soldier != null && gameState.horde.contains(soldier)) {
          return true; // Event is about a player's soldier
        }
      }

      if (event.relatedAravtId != null) {
        final aravt = gameState.findAravtById(event.relatedAravtId!);
        if (aravt != null && gameState.aravts.contains(aravt)) {
          return true; // Event is about a player's aravt
        }
      }

      // For events without specific relations, show general/travel/diplomacy categories
      // as they might be world events relevant to the player, BUT ONLY IF isPlayerKnown is true
      if (event.isPlayerKnown &&
          (event.category == EventCategory.general ||
              event.category == EventCategory.travel ||
              event.category == EventCategory.diplomacy)) {
        return true;
      }

      return false; // Filter out NPC-only activities
    }).toList();

    if (events.isEmpty) {
      return _buildEmptyTab(
          "No events logged${soldierId == null ? '' : ' for this soldier'}.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isPlayerAravt = gameState.isPlayerAravtReport(event);
          return Card(
            color: isPlayerAravt
                ? Colors.amber.withOpacity(0.2)
                : Colors.black.withOpacity(0.6),
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            borderOnForeground: true,
            shape: isPlayerAravt
                ? RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.amber, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: ListTile(
              leading: Icon(_getIconForEvent(event.category),
                  color: _getColorForSeverity(event.severity)),
              title: Text(
                event.message,
                style: GoogleFonts.cinzel(color: Colors.white),
              ),
              subtitle: Text(
                event.date.toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForEvent(EventCategory category) {
    switch (category) {
      case EventCategory.combat:
        return Icons.sports_kabaddi;
      case EventCategory.finance:
        return Icons.money;
      case EventCategory.food:
        return Icons.local_dining_outlined;
      case EventCategory.system:
        return Icons.save;
      case EventCategory.health:
        return Icons.local_hospital_outlined;
      case EventCategory.travel:
        return Icons.map;
      case EventCategory.general:
      default:
        return Icons.book;
    }
  }

  Color _getColorForSeverity(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return Colors.red[300]!;
      case EventSeverity.high:
        return Colors.orange[300]!;
      case EventSeverity.normal:
        return Colors.white70;
      case EventSeverity.low:
        return Colors.grey[400]!;
    }
  }
}

class CombatReportTab extends StatelessWidget {
  final int? soldierId;
  const CombatReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    final List<CombatReport> reports = gameState.combatReports.where((report) {
      if (soldierId == null) return true;
      return report.playerSoldiers
              .any((s) => s.originalSoldier.id == soldierId) ||
          report.enemySoldiers.any((s) => s.originalSoldier.id == soldierId);
    }).toList();

    final reversedReports = reports.reversed.toList();

    if (reversedReports.isEmpty) {
      return _buildEmptyTab(
          "No combat reports filed${soldierId == null ? '' : ' for this soldier'}.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: reversedReports.length,
        itemBuilder: (context, index) {
          final report = reversedReports[index];
          return Card(
            color: Colors.black.withOpacity(0.5),
            margin: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PostCombatReportScreen(report: report),
                  ),
                );
              },
            child: ListTile(
              leading: Icon(_getIconForReport(report.result),
                  color: _getColorForReport(report.result), size: 40),
              title: Text(
                _getTitleForReport(report.result),
                style: GoogleFonts.cinzel(
                    color: _getColorForReport(report.result),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${report.date.toString()}\n${report.playerInitialCount} soldiers vs ${report.enemyInitialCount} enemies",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForReport(CombatResult result) {
    switch (result) {
      case CombatResult.playerVictory:
      case CombatResult.enemyRout:
        return Icons.emoji_events;
      case CombatResult.playerDefeat:
      case CombatResult.playerRout:
        return Icons.dangerous;
      default:
        return Icons.balance;
    }
  }

  Color _getColorForReport(CombatResult result) {
    switch (result) {
      case CombatResult.playerVictory:
      case CombatResult.enemyRout:
        return Colors.green[300]!;
      case CombatResult.playerDefeat:
      case CombatResult.playerRout:
        return Colors.red[300]!;
      default:
        return Colors.yellow[300]!;
    }
  }

  String _getTitleForReport(CombatResult result) {
    switch (result) {
      case CombatResult.playerVictory:
        return "Player Victory";
      case CombatResult.enemyRout:
        return "Enemy Routed";
      case CombatResult.playerDefeat:
        return "Player Defeat";
      case CombatResult.playerRout:
        return "Player Routed";
      default:
        return "Mutual Rout";
    }
  }
}

class HealthReportTab extends StatelessWidget {
  final int? soldierId;
  const HealthReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    if (soldierId != null) {
      final soldier = gameState.findSoldierById(soldierId!);
      if (soldier == null) return _buildEmptyTab("Soldier not found.");

      List<String> issues = [];
      if (soldier.startingInjury != StartingInjuryType.none) {
        issues.add("Old Wound: ${soldier.startingInjury.name}");
      }
      if (soldier.ailments != null) {
        issues.add("Ailment: ${soldier.ailments}");
      }
      for (var injury in soldier.injuries) {
        issues.add(
            "Injury: ${injury.name} (${injury.severity}) - ${injury.isTreated ? 'Treated' : 'Untreated'}");
      }

      if (issues.isEmpty)
        return _buildEmptyTab("Soldier is in perfect health.");

      return Container(
        decoration: _tabBackground(),
        child: ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: issues.length,
          itemBuilder: (context, index) {
            return Card(
              color: Colors.black.withOpacity(0.6),
              child: ListTile(
                leading: const Icon(Icons.local_hospital, color: Colors.red),
                title: Text(issues[index],
                    style: GoogleFonts.cinzel(color: Colors.white)),
              ),
            );
          },
        ),
      );
    } else {
      final wounded = gameState.horde
          .where((s) =>
              s.injuries.isNotEmpty ||
              s.ailments != null ||
              s.startingInjury != StartingInjuryType.none)
          .toList();

      if (wounded.isEmpty) {
        return _buildEmptyTab("No soldiers have injuries or ailments.");
      }

      return Container(
        decoration: _tabBackground(),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80.0),
          itemCount: wounded.length,
          itemBuilder: (context, index) {
            final s = wounded[index];
            int injuryCount = s.injuries.length +
                (s.ailments != null ? 1 : 0) +
                (s.startingInjury != StartingInjuryType.none ? 1 : 0);
            return Card(
              color: Colors.black.withOpacity(0.6),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: Text(s.name,
                    style: GoogleFonts.cinzel(color: Colors.white)),
                subtitle: Text("$injuryCount health issues",
                    style: const TextStyle(color: Colors.white70)),
              ),
            );
          },
        ),
      );
    }
  }
}


// Merges Finance (Treasury) and Industry (Materials)
class CommerceReportTab extends StatefulWidget {
  final bool isOmniscient;
  final int? soldierId;
  const CommerceReportTab(
      {super.key, required this.isOmniscient, this.soldierId});

  @override
  State<CommerceReportTab> createState() => _CommerceReportTabState();
}

class _CommerceReportTabState extends State<CommerceReportTab> {
  int _selectedIndex = 0; // 0 = Finance, 1 = Industry

  @override
  Widget build(BuildContext context) {
    // If looking at a specific soldier, we don't need the split view,
    // just show their personal finance/industry summary.
    if (widget.soldierId != null) {
      return _buildSoldierPersonalView(context);
    }

    return Container(
      decoration: _tabBackground(), // ensure this helper is available in file
      child: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: _selectedIndex == 0
                ? const _FinanceView()
                : const _IndustryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          _buildSegmentButton("Finance", Icons.monetization_on, 0),
          _buildSegmentButton("Industry", Icons.build, 1),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          final gameState = context.read<GameState>();
          gameState.markReportTabViewed('Commerce', subTab: label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected ? Colors.amber : Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.cinzel(
                    color: isSelected ? Colors.amber : Colors.white54,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
              const SizedBox(width: 4),
              NotificationBadge(
                count: context
                    .watch<GameState>()
                    .getBadgeCountForCommerceSubTab(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoldierPersonalView(BuildContext context) {
    // Simple combined view for individual soldiers
    final gameState = context.watch<GameState>();
    final soldier = gameState.findSoldierById(widget.soldierId!);
    if (soldier == null) return _buildEmptyTab("Soldier not found.");

    return Container(
      decoration: _tabBackground(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildResourceTile(Icons.monetization_on, "Personal Treasure",
              "${soldier.treasureWealth.toStringAsFixed(0)} rupees"),
          _buildResourceTile(Icons.backpack, "Personal Supplies",
              "${soldier.suppliesWealth.toStringAsFixed(0)} value"),
          const Divider(color: Colors.white24),
          _buildSectionHeader("Recent Production"),
          // You could filter gameState.resourceReports here for just this soldier
        ],
      ),
    );
  }
}

// --- SUB-VIEW 1: FINANCE ---

class _FinanceView extends StatefulWidget {
  const _FinanceView();

  @override
  State<_FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<_FinanceView> {
  String _selectedWealthView = 'total'; // total, personal, communal, aravt, npc

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildWealthChart(gameState),
        const SizedBox(height: 20),
        _buildWealthEvents(gameState),
        const SizedBox(height: 20),
        _buildTradeReports(gameState),
        _buildPillageReports(gameState),
        const SizedBox(height: 80), // Bottom padding
      ],
    );
  }

  Widget _buildWealthChart(GameState gameState) {
    if (gameState.wealthHistory.isEmpty) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: Text("Gathering wealth data...",
                  style: TextStyle(color: Colors.white54))));
    }

    return Card(
      color: Colors.black.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Wealth History (Last 30 Turns)",
                    style: GoogleFonts.cinzel(color: Colors.amber)),
                _buildWealthViewToggle(),
              ],
            ),
            const SizedBox(height: 16),
            _buildCurrentWealthSummary(gameState),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: gameState.wealthHistory.asMap().entries.map((entry) {
                  bool isLoss = entry.key > 0 &&
                      entry.value < gameState.wealthHistory[entry.key - 1];
                  double maxWealth = gameState.wealthHistory.reduce(math.max);
                  if (maxWealth == 0) maxWealth = 1;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: FractionallySizedBox(
                        heightFactor:
                            (entry.value / maxWealth).clamp(0.05, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLoss ? Colors.red[400] : Colors.green[400],
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWealthViewToggle() {
    return DropdownButton<String>(
      value: _selectedWealthView,
      dropdownColor: Colors.black87,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
      underline: Container(height: 1, color: Colors.amber.withOpacity(0.3)),
      items: const [
        DropdownMenuItem(value: 'total', child: Text('Total Horde')),
        DropdownMenuItem(value: 'personal', child: Text('Personal')),
        DropdownMenuItem(value: 'communal', child: Text('Communal')),
        DropdownMenuItem(value: 'aravt', child: Text('Per Aravt')),
        DropdownMenuItem(value: 'npc', child: Text('NPC Soldiers')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _selectedWealthView = value);
      },
    );
  }

  Widget _buildCurrentWealthSummary(GameState gameState) {
    double personalWealth = (gameState.player?.treasureWealth ?? 0) +
        (gameState.player?.suppliesWealth ?? 0);
    double communalWealth = gameState.communalScrap; // Simplified
    double npcWealth = gameState.horde
        .where((s) => s.id != gameState.player?.id)
        .fold(0.0, (sum, s) => sum + s.treasureWealth + s.suppliesWealth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildWealthStat('Personal', personalWealth),
        _buildWealthStat('Communal', communalWealth),
        _buildWealthStat('NPC Total', npcWealth),
      ],
    );
  }

  Widget _buildWealthStat(String label, double value) {
    return Column(
      children: [
        Text(value.toStringAsFixed(0),
            style: GoogleFonts.cinzel(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildWealthEvents(GameState gameState) {
    final events = gameState.wealthEvents.reversed.take(10).toList();

    if (events.isEmpty) {
      return Card(
        color: Colors.black.withOpacity(0.5),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No wealth events recorded.",
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Recent Wealth Events"),
        ...events.map((event) => Card(
              color: Colors.black.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: Icon(
                  event.isGain ? Icons.arrow_upward : Icons.arrow_downward,
                  color: event.isGain ? Colors.green : Colors.red,
                ),
                title: Text(event.description,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                    "${event.date.toShortString()} - ${event.type.name}",
                    style: const TextStyle(color: Colors.white54)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (event.rupeesChange != 0)
                      Text(
                          "${event.rupeesChange > 0 ? '+' : ''}${event.rupeesChange.toStringAsFixed(0)} ₹",
                          style: TextStyle(
                              color: event.rupeesChange > 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold)),
                    if (event.scrapChange != 0)
                      Text(
                          "${event.scrapChange > 0 ? '+' : ''}${event.scrapChange.toStringAsFixed(0)} scrap",
                          style: TextStyle(
                              color: event.scrapChange > 0
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 11)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildPillageReports(GameState gameState) {
    if (gameState.pillageReports.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader("Pillage Reports"),
        ...gameState.pillageReports.reversed.map((report) {
          return Card(
            color: Colors.black.withOpacity(0.6),
            child: ExpansionTile(
              leading: const Icon(Icons.gavel, color: Colors.amber),
              title: Text(
                "Pillaged ${report.locationName}",
                style: GoogleFonts.cinzel(color: Colors.white),
              ),
              subtitle: Text(
                "${report.date.toIso8601String().substring(0, 10)} - Total Value: ${report.totalValue.toStringAsFixed(0)} §",
                style: const TextStyle(color: Colors.white70),
              ),
              children: [
                ListTile(
                  title: const Text("Scrap Pillaged",
                      style: TextStyle(color: Colors.white70)),
                  trailing: Text("${report.scrapPillaged.toStringAsFixed(0)} §",
                      style: const TextStyle(color: Colors.amber)),
                ),
                if (report.animalsTaken > 0)
                  ListTile(
                    title: const Text("Animals Taken",
                        style: TextStyle(color: Colors.white70)),
                    trailing: Text("${report.animalsTaken}",
                        style: const TextStyle(color: Colors.amber)),
                  ),
                if (report.prisonersTaken > 0)
                  ListTile(
                    title: const Text("Prisoners Taken",
                        style: TextStyle(color: Colors.white70)),
                    trailing: Text("${report.prisonersTaken}",
                        style: const TextStyle(color: Colors.amber)),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTradeReports(GameState gameState) {
    final reports = gameState.tradeReports.reversed.take(10).toList();

    if (reports.isEmpty) {
      return Card(
        color: Colors.black.withOpacity(0.5),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No trade reports filed.",
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Recent Trade Reports"),
        ...reports.map((report) => Card(
              color: Colors.black.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ExpansionTile(
                leading: Icon(
                  _getTradeOutcomeIcon(report.outcome),
                  color: _getTradeOutcomeColor(report.outcome),
                ),
                title: Text("Trade with ${report.partnerName}",
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                    "${report.date.toShortString()} - ${report.outcome.name}",
                    style: const TextStyle(color: Colors.white54)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (report.itemsGiven.isNotEmpty) ...[
                          Text("Items Given:",
                              style: GoogleFonts.cinzel(
                                  color: Colors.red[300],
                                  fontWeight: FontWeight.bold)),
                          ...report.itemsGiven.map((item) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 4.0),
                                child: Text(
                                    "• ${item.itemName} x${item.quantity}",
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              )),
                          const SizedBox(height: 8),
                        ],
                        if (report.itemsReceived.isNotEmpty) ...[
                          Text("Items Received:",
                              style: GoogleFonts.cinzel(
                                  color: Colors.green[300],
                                  fontWeight: FontWeight.bold)),
                          ...report.itemsReceived.map((item) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 4.0),
                                child: Text(
                                    "• ${item.itemName} x${item.quantity}",
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              )),
                        ],
                        if (report.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(report.notes,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _getTradeOutcomeIcon(TradeOutcome outcome) {
    switch (outcome) {
      case TradeOutcome.success:
        return Icons.check_circle;
      case TradeOutcome.partialSuccess:
        return Icons.check_circle_outline;
      case TradeOutcome.rejected:
        return Icons.cancel;
      case TradeOutcome.cancelled:
        return Icons.block;
    }
  }

  Color _getTradeOutcomeColor(TradeOutcome outcome) {
    switch (outcome) {
      case TradeOutcome.success:
        return Colors.green;
      case TradeOutcome.partialSuccess:
        return Colors.yellow;
      case TradeOutcome.rejected:
      case TradeOutcome.cancelled:
        return Colors.red;
    }
  }
}

// --- SUB-VIEW 2: INDUSTRY ---

class _IndustryView extends StatelessWidget {
  const _IndustryView();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final resourceReports = gameState.resourceReports
        .where((r) => gameState.aravts.any((a) => a.id == r.aravtId))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildStockpiles(gameState, context),
        const Divider(color: Colors.white24, height: 40),
        _buildSectionHeader("Material Flow Summary"),
        _buildMaterialFlowSummary(gameState),
        const Divider(color: Colors.white24, height: 40),
        _buildSectionHeader("Production Log"),
        if (resourceReports.isEmpty && gameState.fletchingReports.isEmpty)
          const Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("No industry reports filed yet.",
                style: const TextStyle(color: Colors.white54)),
          ))
        else ...[
          ...(() {
            final list = [
              ...resourceReports.map((r) =>
                  MapEntry(r.turn, _buildResourceReportCard(r, context))),
              ...gameState.fletchingReports
                  .where((r) => gameState.aravts.any((a) => a.id == r.aravtId))
                  .map((r) =>
                      MapEntry(r.turn, _buildFletchingReportCard(r, context)))
            ];
            list.sort((a, b) => b.key.compareTo(a.key));
            return list.map((e) => e.value).take(20).toList();
          })(),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStockpiles(GameState gameState, BuildContext context) {
    final List<_LedgerEntry> entries = [];

    if (gameState.cumulativeWoodGathered > 0) {
      double val = 0.5; // Base value per kg
      double total = gameState.cumulativeWoodGathered * val;
      entries.add(_LedgerEntry(
        icon: Icons.forest,
        name: 'Wood Gathered',
        quantity: gameState.cumulativeWoodGathered.toStringAsFixed(0),
        weight: gameState.cumulativeWoodGathered.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Normal',
        origin: 'Gathered',
        type: 'Material',
        totalValueRaw: total,
      ));
    }
    if (gameState.cumulativeIronMined > 0) {
      double val = 2.0;
      double total = gameState.cumulativeIronMined * val;
      entries.add(_LedgerEntry(
        icon: Icons.landscape,
        name: 'Iron Ore Mined',
        quantity: gameState.cumulativeIronMined.toStringAsFixed(0),
        weight: gameState.cumulativeIronMined.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Raw',
        origin: 'Mined',
        type: 'Ore',
        totalValueRaw: total,
      ));
    }
    if (gameState.cumulativeScrapScavenged > 0) {
      double val = 1.0; // Nominal value
      double total = gameState.cumulativeScrapScavenged * val;
      entries.add(_LedgerEntry(
        icon: Icons.build,
        name: 'Scrap Scavenged',
        quantity: gameState.cumulativeScrapScavenged.toStringAsFixed(0),
        weight: (gameState.cumulativeScrapScavenged * 0.5).toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '1.0',
        quality: 'Mixed',
        origin: 'Scavenged',
        type: 'Salvage',
        totalValueRaw: total,
      ));
    }
    if (gameState.cumulativeShortArrowsFletched > 0) {
      double val = 0.5;
      double total = gameState.cumulativeShortArrowsFletched * val;
      entries.add(_LedgerEntry(
        icon: Icons.arrow_upward,
        name: 'Short Arrows Fletched',
        quantity: '${gameState.cumulativeShortArrowsFletched}',
        weight:
            (gameState.cumulativeShortArrowsFletched * 0.05).toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Standard',
        origin: 'Crafted',
        type: 'Ammo',
        totalValueRaw: total,
      ));
    }
    if (gameState.cumulativeLongArrowsFletched > 0) {
      double val = 0.7;
      double total = gameState.cumulativeLongArrowsFletched * val;
      entries.add(_LedgerEntry(
        icon: Icons.arrow_upward,
        name: 'Long Arrows Fletched',
        quantity: '${gameState.cumulativeLongArrowsFletched}',
        weight:
            (gameState.cumulativeLongArrowsFletched * 0.08).toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Standard',
        origin: 'Crafted',
        type: 'Ammo',
        totalValueRaw: total,
      ));
    }

    return Card(
      color: Colors.black.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Production Output",
                style: GoogleFonts.cinzel(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildLedgerTable(entries, context),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialFlowSummary(GameState gameState) {
    if (gameState.materialFlowHistory.isEmpty) {
      return Card(
        color: Colors.black.withOpacity(0.5),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No material flow data yet.",
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    // Group by material type and end state
    final Map<String, Map<String, double>> flowSummary = {};
    for (var entry in gameState.materialFlowHistory.take(100)) {
      final materialName = entry.material.name;
      final endState = entry.endState.name;

      flowSummary.putIfAbsent(materialName, () => {});
      flowSummary[materialName]!.update(
        endState,
        (value) => value + entry.quantity,
        ifAbsent: () => entry.quantity,
      );
    }

    return Card(
      color: Colors.black.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Material Refinement & End States (Last 100 Entries)",
                style: GoogleFonts.cinzel(
                    color: Colors.amber[200], fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...flowSummary.entries.map((materialEntry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(materialEntry.key,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: materialEntry.value.entries.map((endState) {
                        return Chip(
                          label: Text(
                              "${endState.key}: ${endState.value.toStringAsFixed(0)}"),
                          backgroundColor: _getColorForEndState(endState.key),
                          labelStyle: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getColorForEndState(String endState) {
    switch (endState) {
      case 'consumed':
        return Colors.blue[700]!;
      case 'traded':
        return Colors.green[700]!;
      case 'equipped':
        return Colors.purple[700]!;
      case 'lost':
      case 'spoiled':
        return Colors.red[700]!;
      case 'stockpiled':
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildResourceReportCard(ResourceReport report, BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.6),
      child: ExpansionTile(
        leading:
            Icon(_getIconForResourceType(report.type), color: Colors.amber),
        title: Text(
            "${report.aravtName}: ${_getNameForResourceType(report.type)}",
            style: GoogleFonts.cinzel(color: Colors.white)),
        subtitle: Text(
            "${report.locationName} - ${report.date.toShortString()}\nTotal: ${report.totalGathered.toStringAsFixed(1)}",
            style: const TextStyle(color: Colors.white70)),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: report.individualResults.map((res) {
                Color performanceColor = Colors.white70;
                if (res.amountGathered >= 25)
                  performanceColor = Colors.green;
                else if (res.amountGathered < 8)
                  performanceColor = Colors.red[300]!;

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SoldierProfileScreen(soldierId: res.soldierId),
                      ),
                    );
                  },
                  child: ListTile(
                    dense: true,
                    title: Text(res.soldierName,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    trailing: Text(
                      "${res.amountGathered.toStringAsFixed(1)} ${_getUnitForResourceType(report.type)}",
                      style: TextStyle(
                          color: performanceColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFletchingReportCard(
      FletchingReport report, BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.6),
      child: ExpansionTile(
        leading: const Icon(Icons.arrow_upward, color: Colors.amber),
        title: Text("${report.aravtName}: Fletching",
            style: GoogleFonts.cinzel(color: Colors.white)),
        subtitle: Text(
            "${report.date.toShortString()}\nTotal: ${report.totalArrowsCrafted} ${report.isLongArrows ? 'long' : 'short'} arrows",
            style: const TextStyle(color: Colors.white70)),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
                "Consumed: ${report.totalWoodConsumed.toStringAsFixed(1)}kg wood, ${report.totalScrapConsumed.toStringAsFixed(0)} scrap",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: report.individualResults.map((res) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SoldierProfileScreen(soldierId: res.soldierId),
                      ),
                    );
                  },
                  child: ListTile(
                    dense: true,
                    title: Text(res.soldierName,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    trailing: Text(
                      "${res.arrowsCrafted} arrows",
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  IconData _getIconForResourceType(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Icons.forest;
      case ResourceType.ironOre:
        return Icons.landscape;
      case ResourceType.scrap:
        return Icons.build;
      case ResourceType.arrows:
        return Icons.arrow_upward;
    }
  }

  String _getNameForResourceType(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return "Woodchopping";
      case ResourceType.ironOre:
        return "Mining";
      case ResourceType.scrap:
        return "Scavenging";
      case ResourceType.arrows:
        return "Fletching";
    }
  }

  String _getUnitForResourceType(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
      case ResourceType.ironOre:
        return "kg";
      default:
        return "units";
    }
  }
}

// --- Helper re-definition just in case it's needed in this file scope ---
Widget _buildResourceTile(IconData icon, String label, String value) {
  return Card(
    color: Colors.black.withOpacity(0.5),
    child: ListTile(
      leading: Icon(icon, color: Colors.amber),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Text(value,
          style: GoogleFonts.cinzel(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );
}


class HerdsReportTab extends StatelessWidget {
  final int? soldierId;
  const HerdsReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cattle = gameState.communalCattle;

    return Container(
      decoration: _tabBackground(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Horses Section (Merged) ---
          _buildSectionHeader("Communal Horses"),
          Card(
            color: Colors.black.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cruelty_free, size: 40, color: Colors.white54),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${gameState.communalHerd.length} Total Mounts",
                        style: GoogleFonts.cinzel(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "(Excludes personally owned horses)",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- Cattle Section ---
          _buildSectionHeader("Cattle Herd"),
          Card(
            color: Colors.black.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat("Total", cattle.totalPopulation.toString()),
                      _buildStat("Bulls", cattle.adultMales.toString()),
                      _buildStat("Cows", cattle.adultFemales.toString()),
                      _buildStat("Calves", cattle.young.toString()),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  Text("Today's Activity",
                      style: GoogleFonts.cinzel(
                          color: Colors.amber[200],
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat("Milk",
                          "${cattle.dailyMilkProduction.toStringAsFixed(1)} L"),
                      _buildStat("Births", "+${cattle.dailyBirths}",
                          color: Colors.green),
                      _buildStat("Deaths", "-${cattle.dailyDeaths}",
                          color: Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    cattle.lastGrazedTurn == gameState.turn.turnNumber
                        ? "Status: Grazed Today"
                        : (gameState.turn.turnNumber - cattle.lastGrazedTurn < 3
                            ? "Status: Satisfied"
                            : (gameState.turn.turnNumber -
                                        cattle.lastGrazedTurn <
                                    7
                                ? "Status: Needs Grazing Soon"
                                : "Status: STARVING")),
                    style: TextStyle(
                      color: cattle.lastGrazedTurn == gameState.turn.turnNumber
                          ? Colors.green
                          : (gameState.turn.turnNumber - cattle.lastGrazedTurn <
                                  3
                              ? Colors.green[300]
                              : (gameState.turn.turnNumber -
                                          cattle.lastGrazedTurn <
                                      7
                                  ? Colors.yellow
                                  : Colors.red)),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
          ),

          //  Herd Ledger
          const SizedBox(height: 20),
          _buildSectionHeader("Herd Ledger"),
          Card(
            color: Colors.black.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHerdLedger(cattle.animals, context),
            ),
          ),

          //  Shepherding Reports
          const SizedBox(height: 20),
          _buildSectionHeader("Shepherding Log"),
          if (gameState.shepherdingReports.isEmpty)
            Card(
              color: Colors.black.withOpacity(0.5),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No shepherding reports yet.",
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ...gameState.shepherdingReports.reversed
                .where((report) =>
                    soldierId == null ||
                    report.individualResults
                        .any((res) => res.soldierId == soldierId))
                .map((report) {
              return Card(
                color: Colors.black.withOpacity(0.6),
                child: ExpansionTile(
                  leading: const Icon(Icons.pets, color: Colors.amber),
                  title: Text(
                      "${report.aravtName} shepherded ${report.totalAnimals} animals",
                      style: GoogleFonts.cinzel(color: Colors.white)),
                  subtitle: Text(
                      "${report.date.toShortString()} - Milk: ${report.milkProduced.toStringAsFixed(1)} L",
                      style: const TextStyle(color: Colors.white70)),
                  children: [
                    if (report.events.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: report.events
                              .map((e) => Text("• $e",
                                  style:
                                      const TextStyle(color: Colors.redAccent)))
                              .toList(),
                        ),
                      ),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: report.individualResults.map((res) {
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SoldierProfileScreen(
                                      soldierId: res.soldierId),
                                ),
                              );
                            },
                            child: ListTile(
                              dense: true,
                              title: Text(res.soldierName,
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(res.eventDescription,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              trailing: Text(
                                "Rating: ${res.performanceRating.toStringAsFixed(1)}",
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildHerdLedger(List<LivestockAnimal> animals, BuildContext context) {
    final List<_LedgerEntry> entries = animals.map((animal) {
      double val = 0;
      String name = "Unknown";
      String weight = "Unknown";

      if (animal.type == AnimalType.Cattle) {
        if (animal.age < 2) {
          name = "Calf";
          val = 20;
          weight = "80";
        } else if (animal.isMale) {
          name = "Bull";
          val = 80;
          weight = "600";
        } else {
          name = "Cow";
          val = 50;
          weight = "400";
        }
      } else {
        name = animal.type.name;
        val = 30;
        weight = "50";
      }

      // Adjust value by health
      val *= animal.health;

      return _LedgerEntry(
        icon: Icons.cruelty_free,
        name: name,
        quantity: '1',
        weight: weight,
        rupeeValue: '0',
        scrapValue: val.toStringAsFixed(0),
        quality: animal.health > 0.9
            ? 'Prime'
            : (animal.health > 0.5 ? 'Good' : 'Poor'),
        origin: 'Herd',
        type: 'Livestock',
        totalValueRaw: val,
      );
    }).toList();

    return _buildLedgerTable(entries, context);
  }

  Widget _buildStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.cinzel(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class FoodReportTab extends StatefulWidget {
  final int? soldierId;
  const FoodReportTab({super.key, this.soldierId});

  @override
  State<FoodReportTab> createState() => _FoodReportTabState();
}

class _FoodReportTabState extends State<FoodReportTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final gameState = context.read<GameState>();
        String subTab = 'Overview';
        if (_tabController.index == 1) subTab = 'Fishing';
        if (_tabController.index == 2) subTab = 'Hunting';
        gameState.markReportTabViewed('Food', subTab: subTab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black54,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            tabs: [
              _buildSubTab('Overview', 0),
              _buildSubTab(
                  'Fishing',
                  context
                      .watch<GameState>()
                      .getBadgeCountForFoodSubTab('Fishing')),
              _buildSubTab(
                  'Hunting',
                  context
                      .watch<GameState>()
                      .getBadgeCountForFoodSubTab('Hunting')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FoodOverviewTab(soldierId: widget.soldierId),
              FishingReportTab(soldierId: widget.soldierId),
              HuntingReportTab(soldierId: widget.soldierId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTab(String text, int badgeCount) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          const SizedBox(width: 4),
          NotificationBadge(count: badgeCount),
        ],
      ),
    );
  }
}

class _FoodOverviewTab extends StatelessWidget {
  final int? soldierId;
  const _FoodOverviewTab({this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Container(
      decoration: _tabBackground(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFoodStockpiles(gameState, context),
          const SizedBox(height: 20),
          _buildCulinaryNews(gameState),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFoodStockpiles(GameState gameState, BuildContext context) {
    final List<_LedgerEntry> entries = [];

    if (gameState.communalMeat > 0) {
      double val = 4.0; // Example value
      double total = gameState.communalMeat * val;
      entries.add(_LedgerEntry(
        icon: Icons.restaurant,
        name: 'Meat',
        quantity: gameState.communalMeat.toStringAsFixed(1),
        weight: gameState.communalMeat.toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Fresh',
        origin: 'Butchered',
        type: 'Food',
        totalValueRaw: total,
      ));
    }
    if (gameState.communalMilk > 0) {
      double val = 2.0;
      double total = gameState.communalMilk * val;
      entries.add(_LedgerEntry(
        icon: Icons.water_drop,
        name: 'Milk',
        quantity: gameState.communalMilk.toStringAsFixed(1),
        weight: gameState.communalMilk.toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Fresh',
        origin: 'Milked',
        type: 'Drink',
        totalValueRaw: total,
      ));
    }
    if (gameState.communalCheese > 0) {
      double val = 8.0;
      double total = gameState.communalCheese * val;
      entries.add(_LedgerEntry(
        icon: Icons.food_bank,
        name: 'Cheese',
        quantity: gameState.communalCheese.toStringAsFixed(1),
        weight: gameState.communalCheese.toStringAsFixed(1),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Aged',
        origin: 'Crafted',
        type: 'Food',
        totalValueRaw: total,
      ));
    }
    if (gameState.communalGrain > 0) {
      double val = 1.5;
      double total = gameState.communalGrain * val;
      entries.add(_LedgerEntry(
        icon: Icons.grass,
        name: 'Grain',
        quantity: gameState.communalGrain.toStringAsFixed(0),
        weight: gameState.communalGrain.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'Raw',
        origin: 'Gathered',
        type: 'Ingredient',
        totalValueRaw: total,
      ));
    }

    if (gameState.communalRice > 0) {
      double val = 2.0;
      double total = gameState.communalRice * val;
      entries.add(_LedgerEntry(
        icon: Icons.grass,
        name: 'Rice',
        quantity: gameState.communalRice.toStringAsFixed(0),
        weight: gameState.communalRice.toStringAsFixed(0),
        rupeeValue: val.toStringAsFixed(1),
        scrapValue: '0',
        quality: 'White',
        origin: 'Traded',
        type: 'Ingredient',
        totalValueRaw: total,
      ));
    }

    return _buildLedgerTable(entries, context);
  }

  Widget _buildCulinaryNews(GameState gameState) {
    final news = gameState.culinaryNews.reversed.take(10).toList();

    if (news.isEmpty) {
      return Card(
        color: Colors.black.withOpacity(0.5),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No culinary news yet.",
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Culinary News"),
        ...news.map((item) => Card(
              color: Colors.black.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: Icon(_getCulinaryIcon(item.type),
                    color: _getCulinaryColor(item.type)),
                title: Text(item.description,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(item.date.toShortString(),
                    style: const TextStyle(color: Colors.white54)),
                trailing: item.qualityRating != null
                    ? Text("${item.qualityRating}/10",
                        style: GoogleFonts.cinzel(
                            color: Colors.amber, fontWeight: FontWeight.bold))
                    : null,
              ),
            )),
      ],
    );
  }

  IconData _getFoodIcon(String name) {
    if (name.contains("Meat")) return Icons.restaurant;
    if (name.contains("Milk")) return Icons.water_drop;
    if (name.contains("Cheese")) return Icons.food_bank;
    if (name.contains("Grain") || name.contains("Rice")) return Icons.grass;
    return Icons.fastfood;
  }

  IconData _getCulinaryIcon(CulinaryEventType type) {
    switch (type) {
      case CulinaryEventType.legendaryMeal:
        return Icons.star;
      case CulinaryEventType.newRecipe:
        return Icons.menu_book;
      case CulinaryEventType.newSpice:
        return Icons.local_florist;
      case CulinaryEventType.feastReport:
        return Icons.celebration;
      case CulinaryEventType.cookPromotion:
        return Icons.trending_up;
      case CulinaryEventType.disasterMeal:
        return Icons.warning;
    }
  }

  Color _getCulinaryColor(CulinaryEventType type) {
    switch (type) {
      case CulinaryEventType.legendaryMeal:
        return Colors.amber;
      case CulinaryEventType.newRecipe:
      case CulinaryEventType.newSpice:
        return Colors.green;
      case CulinaryEventType.feastReport:
        return Colors.purple;
      case CulinaryEventType.cookPromotion:
        return Colors.blue;
      case CulinaryEventType.disasterMeal:
        return Colors.red;
    }
  }
}

class HuntingReportTab extends StatelessWidget {
  final int? soldierId;
  const HuntingReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final reports = gameState.huntingReports
        .where((r) {
          // Soldier-specific filtering
          if (soldierId != null) {
            return r.individualResults.any((res) => res.soldierId == soldierId);
          }

          //  Global reports: filter out NPC-only hunts
          // Check if any participant is from player's horde
          for (var res in r.individualResults) {
            final soldier = gameState.findSoldierById(res.soldierId);
            if (soldier != null && gameState.horde.contains(soldier)) {
              return true; // At least one player soldier participated
            }
          }
          return false; // No player soldiers, filter out
        })
        .toList()
        .reversed
        .toList();

    if (reports.isEmpty) {
      return _buildEmptyTab(
          "No hunting reports filed${soldierId == null ? '' : ' for this soldier'}.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          double displayMeat = report.totalMeat;
          int displayPelts = report.totalPelts;
          if (soldierId != null) {
            final soldierResult = report.individualResults
                .firstWhere((r) => r.soldierId == soldierId);
            displayMeat = soldierResult.totalMeat;
            displayPelts = soldierResult.totalPelts;
          }

          return Card(
            color: Colors.black.withOpacity(0.6),
            child: ExpansionTile(
              leading: const Icon(Icons.explore, color: Colors.green),
              title: Text(
                  "${report.aravtName} hunted at ${report.locationName}",
                  style: GoogleFonts.cinzel(color: Colors.white)),
              subtitle: Text(
                  "${report.date.toShortString()} - Yield: ${displayMeat.toStringAsFixed(1)} kg meat, $displayPelts pelts",
                  style: const TextStyle(color: Colors.white70)),
              children: report.individualResults.map((res) {
                if (soldierId != null && res.soldierId != soldierId)
                  return const SizedBox.shrink();
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SoldierProfileScreen(soldierId: res.soldierId),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(res.soldierName,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        res.kills.isEmpty
                            ? "Caught nothing."
                            : res.kills
                                .map(
                                    (k) => "${k.animalName} (${k.meatYield}kg)")
                                .join(", "),
                        style: const TextStyle(color: Colors.white70)),
                    trailing: res.wasInjured
                        ? const Icon(Icons.local_hospital, color: Colors.red)
                        : null,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class FishingReportTab extends StatelessWidget {
  final int? soldierId;
  const FishingReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final reports = gameState.fishingReports
        .where((r) {
          if (soldierId == null) return true;
          return r.individualResults.any((res) => res.soldierId == soldierId);
        })
        .toList()
        .reversed
        .toList();

    if (reports.isEmpty) {
      return _buildEmptyTab(
          "No fishing reports filed${soldierId == null ? '' : ' for this soldier'}.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          double displayMeat = report.totalMeat;
          int displayFish = report.totalFishCaught;
          if (soldierId != null) {
            final soldierResult = report.individualResults
                .firstWhere((r) => r.soldierId == soldierId);
            displayMeat = soldierResult.totalMeat;
            displayFish = soldierResult.catches.length;
          }

          return Card(
            color: Colors.black.withOpacity(0.6),
            child: ExpansionTile(
              leading: const Icon(Icons.phishing, color: Colors.blue),
              title: Text(
                  "${report.aravtName} fished at ${report.locationName}",
                  style: GoogleFonts.cinzel(color: Colors.white)),
              subtitle: Text(
                  "${report.date.toShortString()} - Yield: $displayFish fish (${displayMeat.toStringAsFixed(1)} kg)",
                  style: const TextStyle(color: Colors.white70)),
              children: report.individualResults.map((res) {
                if (soldierId != null && res.soldierId != soldierId)
                  return const SizedBox.shrink();
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SoldierProfileScreen(soldierId: res.soldierId),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(res.soldierName,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        res.catches.isEmpty
                            ? "Caught nothing."
                            : "${res.catches.length} fish caught using ${res.catches.first.techniqueUsed} and others.",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class GamesReportTab extends StatelessWidget {
  final int? soldierId;
  const GamesReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final history = gameState.tournamentHistory.reversed.toList();
    final upcoming = gameState.upcomingTournaments;

    if (history.isEmpty && upcoming.isEmpty) {
      return _buildEmptyTab("No tournaments scheduled or completed.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView(
        padding: const EdgeInsets.all(8.0).copyWith(bottom: 80.0),
        children: [
          if (gameState.activeTournament != null) ...[
            _buildActiveTournamentCard(gameState.activeTournament!),
            const Divider(color: Colors.white24, height: 30),
          ],
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Upcoming Events",
                  style: GoogleFonts.cinzel(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
            ...upcoming.map((future) => _buildFutureTournamentCard(future)),
            const Divider(color: Colors.white24, height: 30),
          ],
          if (history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Past Results",
                  style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
            ...history.map((result) =>
                _buildTournamentResultCard(context, result, gameState)),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: Text("Schedule New Event", style: GoogleFonts.cinzel()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Event scheduling not yet implemented.")));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTournamentCard(ActiveTournament active) {
    return Card(
      color: Colors.teal[900]!.withOpacity(0.7),
      child: ExpansionTile(
        leading:
            const Icon(Icons.play_circle_filled, color: Colors.greenAccent),
        title: Text(active.name,
            style: GoogleFonts.cinzel(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text("Day ${active.currentDay} of ${active.duration}",
            style: const TextStyle(
                color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current Standings:",
                    style: GoogleFonts.cinzel(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...active.currentStandings.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(color: Colors.white70)),
                        Text("${entry.value} pts",
                            style: const TextStyle(color: Colors.amber)),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Text("Tournament Events:",
                    style: GoogleFonts.cinzel(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                ...List.generate(active.duration, (index) {
                  int day = index + 1;
                  List<TournamentEventType> dayEvents = [];
                  // Define Schedule (Must match TournamentService)
                  if (day == 1) dayEvents.add(TournamentEventType.archery);
                  if (day == 2) dayEvents.add(TournamentEventType.horseArchery);
                  if (day == 3) {
                    dayEvents.add(TournamentEventType.wrestling);
                    dayEvents.add(TournamentEventType.horseRace);
                  }
                  if (day == 4) dayEvents.add(TournamentEventType.buzkashi);

                  // Filter by what's actually in this tournament
                  dayEvents = dayEvents
                      .where((e) => active.events.contains(e))
                      .toList();

                  if (dayEvents.isEmpty) return const SizedBox.shrink();

                  bool isPast = day < active.currentDay;
                  bool isCurrent = day == active.currentDay;

                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: dayEvents.map((event) {
                        return Row(
                          children: [
                            Icon(_getEventIcon(event),
                                color: isCurrent
                                    ? Colors.greenAccent
                                    : (isPast
                                        ? Colors.white24
                                        : Colors.white54),
                                size: 16),
                            const SizedBox(width: 8),
                            Text("Day $day: ${_getEventName(event)}",
                                style: TextStyle(
                                    color: isCurrent
                                        ? Colors.greenAccent
                                        : (isPast
                                            ? Colors.white24
                                            : Colors.white70),
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Text("Daily Reports:",
                    style: GoogleFonts.cinzel(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                ...active.dailyReports.entries.map((entry) {
                  final isLatest = entry.key == active.currentDay - 1;
                  return ExpansionTile(
                    initiallyExpanded: isLatest,
                    title: Text("Day ${entry.key}",
                        style: const TextStyle(color: Colors.amber)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(entry.value,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Courier')), // Monospace fallback
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureTournamentCard(FutureTournament future) {
    return Card(
      color: Colors.black.withOpacity(0.7),
      child: ExpansionTile(
        leading: Icon(Icons.calendar_today,
            color: future.isCritical ? Colors.red : Colors.amber),
        title: Text(future.name,
            style: GoogleFonts.cinzel(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
            future.name.contains("Downsizing")
                ? "05/01/1140"
                : future.date.toShortString(),
            style: const TextStyle(color: Colors.white70)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(future.description,
                    style: const TextStyle(
                        color: Colors.white, fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),
                Text("Scheduled Events:",
                    style: GoogleFonts.cinzel(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                ...future.events.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Row(
                        children: [
                          Icon(_getEventIcon(e),
                              color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text(_getEventName(e),
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentResultCard(
      BuildContext context, TournamentResult result, GameState gameState) {
    var sortedStandings = result.finalAravtStandings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.black.withOpacity(0.7),
      child: ExpansionTile(
        leading: const Icon(Icons.emoji_events, color: Colors.amber),
        title: Text(
            "${result.name} (Winner: ${result.winnerAravtId ?? 'None'})",
            style: GoogleFonts.cinzel(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(result.date.toShortString(),
            style: const TextStyle(color: Colors.white70)),
        children: [
          _buildSectionHeader("Final Standings"),
          ...sortedStandings.map((entry) {
            String displayName = entry.key;
            final aravt = gameState.findAravtById(entry.key);
            if (aravt != null) {
              final captain = gameState.findSoldierById(aravt.captainId);
              if (captain != null)
                displayName = "${captain.name}'s Aravt (${entry.key})";
            }
            return ListTile(
              dense: true,
              title: Text(displayName,
                  style: const TextStyle(color: Colors.white)),
              trailing: Text("${entry.value} pts",
                  style: GoogleFonts.cinzel(
                      color: Colors.amber, fontWeight: FontWeight.bold)),
            );
          }),
          _buildSectionHeader("Event Details"),
          ...result.eventResults.entries.map((entry) {
            return _buildEventDetailTile(
                context, entry.key, entry.value, gameState);
          }),
          if (result.dailyReports.isNotEmpty) ...[
            _buildSectionHeader("Daily Reports"),
            ...result.dailyReports.entries.map((entry) {
              final isLatest =
                  entry.key == result.dailyReports.keys.reduce(math.max);
              return _buildParsedReport(entry.key, entry.value, isLatest);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEventDetailTile(BuildContext context, TournamentEventType type,
      EventResult result, GameState gameState) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(_getEventIcon(type), color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(_getEventName(type),
              style: GoogleFonts.cinzel(color: Colors.white70)),
        ],
      ),
      children: [_buildEventResultDetails(type, result, gameState)],
    );
  }

  Widget _buildEventResultDetails(
      TournamentEventType type, EventResult result, GameState gameState) {
    if (result is ScoreBasedEventResult) {
      return _buildScoreList(result.rankings, result.scores, gameState, "pts");
    } else if (result is RaceEventResult) {
      return _buildRaceResultList(result.entries, result.rankings, gameState);
    } else if (result is WrestlingEventResult) {
      return _buildBracketView(result.rounds, gameState);
    } else if (result is BuzkashiEventResult) {
      return _buildBuzkashiBracketView(result.rounds, gameState);
    }
    return const SizedBox.shrink();
  }

  Widget _buildScoreList(List<int> rankings, Map<int, num> scores,
      GameState gameState, String suffix) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final soldierId = rankings[index];
          if (this.soldierId != null && this.soldierId != soldierId) {
            return const SizedBox.shrink();
          }
          final soldier = gameState.findSoldierById(soldierId);
          final scoreVal = scores[soldierId] ?? 0;
          return ListTile(
            dense: true,
            leading: Text("#${index + 1}",
                style: const TextStyle(color: Colors.amber)),
            title: Text(soldier?.name ?? "Unknown",
                style: const TextStyle(color: Colors.white)),
            trailing: Text("$scoreVal $suffix",
                style: const TextStyle(color: Colors.white70)),
          );
        },
      ),
    );
  }

  Widget _buildRaceResultList(
      List<RaceResultEntry> entries, List<int> rankings, GameState gameState) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final soldierId = rankings[index];
          if (this.soldierId != null && this.soldierId != soldierId) {
            return const SizedBox.shrink();
          }
          final soldier = gameState.findSoldierById(soldierId);
          final entry = entries.firstWhere((e) => e.soldierId == soldierId,
              orElse: () => RaceResultEntry(
                  soldierId: -1, horseName: 'Unknown', time: 9999));
          int minutes = (entry.time / 60).floor();
          double seconds = entry.time % 60;
          String timeText =
              "$minutes:${seconds.toStringAsFixed(2).padLeft(5, '0')}";

          return ListTile(
            dense: true,
            leading: Text("#${index + 1}",
                style: const TextStyle(color: Colors.amber)),
            title: Text(entry.horseName,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text("Rider: ${soldier?.name ?? 'Unknown'}",
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            trailing:
                Text(timeText, style: const TextStyle(color: Colors.white70)),
          );
        },
      ),
    );
  }

  Widget _buildParsedReport(int day, String reportText, bool isLatest) {
    // Try to parse the report text into structured data for DataTable
    final lines = reportText.split('\n');
    List<Widget> children = [];

    // Check if it's a column-based report (Archery, Horse Archery, Horse Race)
    bool isColumnar =
        reportText.contains("Rank") && reportText.contains("Aravt");

    if (isColumnar) {
      // Parse columns
      List<String> headers = [];
      List<List<String>> rows = [];
      bool inTable = false;

      for (var line in lines) {
        if (line.trim().isEmpty) {
          if (inTable && headers.isNotEmpty && rows.isNotEmpty) {
            // End of table, render it and reset
            children.add(_buildDataTable(headers, rows));
            headers = [];
            rows = [];
            inTable = false;
          }
          continue;
        }

        if (line.startsWith("Rank") && line.contains("Aravt")) {
          // Header line
          // Header line
          if (line.contains('|')) {
            headers = line.split('|').map((e) => e.trim()).toList();
          } else {
            headers =
                line.split(RegExp(r'\s{2,}')).map((e) => e.trim()).toList();
          }
          inTable = true;
          continue;
        }

        if (inTable && line.startsWith("-")) {
          // Skip separator line
          continue;
        }

        if (inTable && RegExp(r'^\d+\.').hasMatch(line)) {
          // Row line
          // Row line
          List<String> parts;
          if (line.contains('|')) {
            parts = line.split('|').map((e) => e.trim()).toList();
          } else {
            parts = line.split(RegExp(r'\s{2,}')).map((e) => e.trim()).toList();
          }

          if (parts.length >= headers.length) {
            rows.add(parts.take(headers.length).toList());
          } else {
            // Pad with empty strings if too few columns
            while (parts.length < headers.length) {
              parts.add("");
            }
            rows.add(parts);
          }
          continue;
        }

        // Non-table line, just add as text
        if (inTable && headers.isNotEmpty && rows.isNotEmpty) {
          children.add(_buildDataTable(headers, rows));
          headers = [];
          rows = [];
          inTable = false;
        }
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(line,
              style: GoogleFonts.cinzel(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
        ));
      }
      if (inTable && headers.isNotEmpty && rows.isNotEmpty) {
        children.add(_buildDataTable(headers, rows));
      }
    } else {
      // Fallback to text for Wrestling/Buzkashi
      children.add(Text(reportText,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontFamily: 'Courier')));
    }

    return ExpansionTile(
      initiallyExpanded: isLatest,
      title: Text("Day $day", style: const TextStyle(color: Colors.amber)),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        horizontalMargin: 4,
        headingRowHeight: 30,
        dataRowMinHeight: 24,
        dataRowMaxHeight: 36,
        columns: headers
            .map((h) => DataColumn(
                label: Text(h,
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold))))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                cells: row
                    .take(headers.length)
                    .map((c) => DataCell(Text(c,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11))))
                    .toList()))
            .toList(),
      ),
    );
  }

  Widget _buildBracketView(List<WrestlingRound> rounds, GameState gameState) {
    return Column(
      children: rounds.map((round) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(round.name,
                  style: GoogleFonts.cinzel(
                      color: Colors.amber[200], fontWeight: FontWeight.bold)),
            ),
            ...round.matches.map((match) {
              final s1 = gameState.findSoldierById(match.soldier1Id);
              final s2 = gameState.findSoldierById(match.soldier2Id);
              if (soldierId != null &&
                  match.soldier1Id != soldierId &&
                  match.soldier2Id != soldierId) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(s1?.name ?? "Unknown",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: match.winnerId == match.soldier1Id
                                    ? Colors.green
                                    : Colors.white70))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child:
                          Text("vs", style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(
                        child: Text(s2?.name ?? "Unknown",
                            style: TextStyle(
                                color: match.winnerId == match.soldier2Id
                                    ? Colors.green
                                    : Colors.white70))),
                  ],
                ),
              );
            }),
            const Divider(color: Colors.white10),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBuzkashiBracketView(
      List<BuzkashiRound> rounds, GameState gameState) {
    String getAravtName(String aravtId) {
      final aravt = gameState.findAravtById(aravtId);
      if (aravt != null) {
        final captain = gameState.findSoldierById(aravt.captainId);
        if (captain != null) return "${captain.name}'s Team";
      }
      return aravtId;
    }

    return Column(
      children: rounds.map((round) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(round.name,
                  style: GoogleFonts.cinzel(
                      color: Colors.amber[200], fontWeight: FontWeight.bold)),
            ),
            ...round.matches.map((match) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(getAravtName(match.aravt1Id),
                            style: TextStyle(
                                color: match.winnerId == match.aravt1Id
                                    ? Colors.green
                                    : Colors.white70)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text("${match.score1} - ${match.score2}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text(getAravtName(match.aravt2Id),
                            style: TextStyle(
                                color: match.winnerId == match.aravt2Id
                                    ? Colors.green
                                    : Colors.white70)),
                      ],
                    ),
                    if (match.goalScorers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8.0,
                          children: match.goalScorers.entries.map((e) {
                            final scorer = gameState.findSoldierById(e.key);
                            return Text(
                              "${scorer?.firstName ?? 'Unknown'}: ${e.value} ",
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            );
                          }).toList(),
                        ),
                      )
                  ],
                ),
              );
            }),
            const Divider(color: Colors.white10),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(title,
          style: GoogleFonts.cinzel(
              color: Colors.white54, fontWeight: FontWeight.bold)),
    );
  }

  IconData _getEventIcon(TournamentEventType type) {
    switch (type) {
      case TournamentEventType.archery:
        return Icons.gps_fixed;
      case TournamentEventType.horseRace:
        return Icons.directions_run;
      case TournamentEventType.wrestling:
        return Icons.sports_kabaddi;
      case TournamentEventType.horseArchery:
        return Icons.monetization_on;
      case TournamentEventType.buzkashi:
        return Icons.sports_soccer;
    }
  }

  String _getEventName(TournamentEventType type) {
    switch (type) {
      case TournamentEventType.archery:
        return "Archery";
      case TournamentEventType.horseRace:
        return "Horse Race";
      case TournamentEventType.wrestling:
        return "Wrestling";
      case TournamentEventType.horseArchery:
        return "Horse Archery";
      case TournamentEventType.buzkashi:
        return "Buzkashi";
    }
  }
}
