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

// lib/screens/post_combat_report_screen.dart
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/models/prisoner_action.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:provider/provider.dart';

class PostCombatReportScreen extends StatefulWidget {
  final CombatReport report;

  const PostCombatReportScreen({super.key, required this.report});

  @override
  State<PostCombatReportScreen> createState() => _PostCombatReportScreenState();
}

class _PostCombatReportScreenState extends State<PostCombatReportScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final Map<int, PrisonerAction> _captiveDecisions;
  bool _showCaptivesTab = false;

  @override
  void initState() {
    super.initState();

    _showCaptivesTab = widget.report.hasCaptivesToProcess;

    _tabController = TabController(
      length: _showCaptivesTab ? 5 : 4, // 4 or 5 tabs
      vsync: this,
    );

    _captiveDecisions = {
      for (var captive in widget.report.captives)
        captive.id: PrisonerAction.undecided,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAppBarButtonPressed() {
    final gameState = context.read<GameState>();

    if (gameState.combatFlowState != CombatFlowState.postCombat) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_showCaptivesTab) {
      if (_captiveDecisions.containsValue(PrisonerAction.undecided)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "You must decide the fate of all captives before continuing.",
              style: GoogleFonts.cinzel(color: Colors.white),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
        _tabController.animateTo(3);
        return;
      }


      // This is the fix. We call a new function with our decisions.
      gameState.processCombatReport(widget.report, _captiveDecisions);

    } else {

      gameState.processCombatReport(widget.report, {});

    }
  }

  @override
  Widget build(BuildContext context) {
    final IconData appBarIcon = _showCaptivesTab ? Icons.check : Icons.close;

    final List<Widget> tabs = [
      const Tab(icon: Icon(Icons.assessment), text: "Summary"),
      const Tab(icon: Icon(Icons.shield), text: "Player"),
      const Tab(icon: Icon(Icons.sports_kabaddi), text: "Enemy"),
      const Tab(icon: Icon(Icons.inventory), text: "Loot"),
      if (_showCaptivesTab)
        const Tab(icon: Icon(Icons.gavel), text: "Captives"),
    ];

    final List<Widget> tabViews = [
      _buildSummaryTab(context),
      _buildSoldierList(widget.report.playerSoldiers, true),
      _buildSoldierList(widget.report.enemySoldiers, false),
      _buildLootTab(context),
      if (_showCaptivesTab) _buildCaptiveList(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("After Action Report", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withOpacity(0.5),
        leading: IconButton(
          icon: Icon(appBarIcon),
          onPressed: _onAppBarButtonPressed,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          tabs: tabs,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/steppe_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: tabViews,
        ),
      ),
    );
  }

  /// Builds the Summary tab
  Widget _buildSummaryTab(BuildContext context) {
    final report = widget.report;
    int playerKilled = report.getPlayerCount(SoldierStatus.killed);
    int playerWounded = report.getPlayerCount(SoldierStatus.wounded);
    int playerFled = report.getPlayerCount(SoldierStatus.fled);
    int playerSurvived = report.playerInitialCount - playerKilled - playerFled;

    int enemyKilled = report.getEnemyCount(SoldierStatus.killed);
    int enemyWounded = report.getEnemyCount(SoldierStatus.wounded);
    int enemyFled = report.getEnemyCount(SoldierStatus.fled);
    int enemySurvived = report.enemyInitialCount - enemyKilled - enemyFled;

    String title;
    Color titleColor;

    switch (report.result) {
      case CombatResult.playerVictory:
      case CombatResult.enemyRout:
        title = "VICTORY";
        titleColor = Colors.greenAccent[400]!;
        break;
      case CombatResult.playerDefeat:
      case CombatResult.playerRout:
        title = "DEFEAT";
        titleColor = Colors.redAccent[400]!;
        break;
      default:
        title = "STALEMATE";
        titleColor = Colors.yellow[400]!;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.cinzel(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          Text(
            report.date.toString(),
            style: GoogleFonts.cinzel(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatColumn(
                "Player",
                Icons.shield,
                Colors.blue[300]!,
                report.playerInitialCount,
                playerSurvived,
                playerWounded,
                playerKilled,
                playerFled,
                report.playerKills,
              ),
              _buildStatColumn(
                "Enemy",
                Icons.sports_kabaddi,
                Colors.red[300]!,
                report.enemyInitialCount,
                enemySurvived,
                enemyWounded,
                enemyKilled,
                enemyFled,
                report.enemyKills,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLootSection(
            context,
            report.lootObtained,
            report.lootLost,
          ),
        ],
      ),
    );
  }

  /// Builds a stat column for the summary page
  Widget _buildStatColumn(
    String title,
    IconData icon,
    Color color,
    int initial,
    int survived,
    int wounded,
    int killed,
    int fled,
    int kills,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.cinzel(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          "Deployed: $initial",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          "Survived: $survived",
          style: TextStyle(color: Colors.green[300], fontSize: 16),
        ),
        Text(
          "Wounded: $wounded",
          style: TextStyle(color: Colors.yellow[300], fontSize: 16),
        ),
        Text(
          "Casualties: $killed",
          style: TextStyle(color: Colors.red[300], fontSize: 16),
        ),
        Text(
          "Fled: $fled",
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          "Kills Scored: $kills",
          style: TextStyle(color: Colors.amber[300], fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildLootSection(
    BuildContext context,
    LootReport obtained,
    LootReport lost,
  ) {
    if (obtained.isEmpty && lost.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (obtained.isNotEmpty)
          _buildLootCard(
            context,
            "Loot Obtained",
            Colors.green[300]!,
            Icons.monetization_on,
            obtained,
          ),
        if (obtained.isNotEmpty && lost.isNotEmpty) const SizedBox(height: 16),
        if (lost.isNotEmpty)
          _buildLootCard(
            context,
            "Loot Lost",
            Colors.red[300]!,
            Icons.money_off,
            lost,
          ),
      ],
    );
  }

  Widget _buildLootCard(
    BuildContext context,
    String title,
    Color color,
    IconData icon,
    LootReport loot,
  ) {
    final itemEntries = loot.entries;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loot.currency > 0)
            Text(
              "Currency: ${loot.currency}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          if (itemEntries.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                "Items:",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ...itemEntries.map((entry) {
            final String itemName = entry.item.name;
            final String recipient = entry.soldierName;

            return Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: Text(
                "• $itemName -> $recipient",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLootTab(BuildContext context) {
    if (widget.report.lootObtained.isEmpty) {
      return Center(
        child: Text(
          "No loot obtained.",
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    // Group loot by soldier
    final Map<int, List<LootEntry>> groupedLoot = {};
    for (var entry in widget.report.lootObtained.entries) {
      groupedLoot.putIfAbsent(entry.soldierId, () => []).add(entry);
    }

    final soldierIds = groupedLoot.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: soldierIds.length,
      itemBuilder: (context, index) {
        final soldierId = soldierIds[index];
        final entries = groupedLoot[soldierId]!;
        final soldierName = entries.first.soldierName;

        return Card(
          color: Colors.black.withOpacity(0.6),
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  soldierName,
                  style: GoogleFonts.cinzel(
                    color: Colors.amber[300],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.white24),
                ...entries.map((entry) {
                  return ListTile(
                    leading:
                        const Icon(Icons.inventory_2, color: Colors.white70),
                    title: Text(
                      entry.item.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      entry.item.description,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the scrollable list for the Player and Enemy tabs
  Widget _buildSoldierList(
      List<CombatReportSoldierSummary> soldiers, bool isPlayer) {
    if (soldiers.isEmpty) {
      return Center(
        child: Text(
          "No soldiers involved.",
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    soldiers.sort((a, b) => _statusSortValue(a.finalStatus)
        .compareTo(_statusSortValue(b.finalStatus)));

    return ListView.builder(
      itemCount: soldiers.length,
      itemBuilder: (context, index) {
        final summary = soldiers[index];
        final soldier = summary.originalSoldier;

        return Card(
          color: Colors.black.withOpacity(0.6),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            leading:
                _buildStatusIcon(summary.finalStatus, summary.wasUnconscious),
            title: Text(
              soldier.name,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: _buildSubtitleColumn(summary, isPlayer),
            isThreeLine: false, // Let the Column manage its own height
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(SoldierStatus status, bool wasUnconscious) {
    IconData icon;
    Color color;

    switch (status) {
      case SoldierStatus.killed:
        icon = Icons.dangerous;
        color = Colors.red[400]!;
        break;
      case SoldierStatus.fled:
        icon = Icons.directions_run;
        color = Colors.grey[400]!;
        break;
      case SoldierStatus.unconscious:
        icon = Icons.airline_seat_flat;
        color = Colors.orange[300]!;
        break;
      case SoldierStatus.wounded:
        icon = Icons.healing;
        color = Colors.yellow[300]!;
        break;
      case SoldierStatus.alive:
        icon = Icons.check_circle;
        color = Colors.green[300]!;
        break;
    }
    return Icon(icon, color: color, size: 36);
  }

  Widget _buildSubtitleColumn(
      CombatReportSoldierSummary summary, bool isPlayer) {
    final statusStyle = GoogleFonts.cinzel(color: Colors.white, fontSize: 14);
    final injuryStyle = GoogleFonts.cinzel(
        color: Colors.red[200], fontSize: 12, fontStyle: FontStyle.italic);
    final killStyle = GoogleFonts.cinzel(
        color: Colors.green[200], fontSize: 12, fontStyle: FontStyle.italic);

    List<Widget> children = [];

    switch (summary.finalStatus) {
      case SoldierStatus.killed:
        children.add(Text("Killed in Action", style: statusStyle));
        break;
      case SoldierStatus.fled:
        children.add(Text("Fled the Battlefield", style: statusStyle));
        break;
      case SoldierStatus.unconscious:
        children.add(Text("Unconscious", style: statusStyle));
        break;
      case SoldierStatus.wounded:
        children.add(Text("Wounded", style: statusStyle));
        break;
      case SoldierStatus.alive:
        children.add(Text("Survived Unscathed", style: statusStyle));
        break;
    }

    if (summary.injuriesSustained.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4.0, left: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: summary.injuriesSustained
              .map((injury) => Text(
                    "• ${injury.name} (from ${injury.inflictedBy})",
                    style: injuryStyle,
                  ))
              .toList(),
        ),
      ));
    }

    if (summary.defeatedSoldiers.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4.0, left: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: summary.defeatedSoldiers
              .map((victim) => Text(
                    "+ Defeated ${victim.name}",
                    style: killStyle,
                  ))
              .toList(),
        ),
      ));
    }

    // If no injuries and no kills, it's an empty column.
    // We add padding to ensure the ListTile has the correct height.
    if (children.length == 1 &&
        summary.injuriesSustained.isEmpty &&
        summary.defeatedSoldiers.isEmpty) {
      children.add(const SizedBox(height: 4));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildCaptiveList() {
    final captives = widget.report.captives;

    if (captives.isEmpty) {
      return Center(
        child: Text(
          "No captives taken.",
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      itemCount: captives.length,
      itemBuilder: (context, index) {
        final captive = captives[index];
        final currentDecision = _captiveDecisions[captive.id]!;

        TextStyle getOptionStyle(Soldier captive, PrisonerAction action) {
          // Stub for future AI logic
          return const TextStyle(color: Colors.white);
        }

        return Card(
          color: Colors.black.withOpacity(0.6),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  captive.name,
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  "Status: Wounded", // TODO: Get more granular status
                  style: TextStyle(color: Colors.yellow[300]),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PrisonerAction>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    selectedForegroundColor: Colors.black,
                    selectedBackgroundColor: Colors.amber[300],
                  ),
                  segments: [
                    ButtonSegment<PrisonerAction>(
                      value: PrisonerAction.recruit,
                      label: Text("Recruit",
                          style:
                              getOptionStyle(captive, PrisonerAction.recruit)),
                    ),
                    ButtonSegment<PrisonerAction>(
                      value: PrisonerAction.imprison,
                      label: Text("Imprison",
                          style:
                              getOptionStyle(captive, PrisonerAction.imprison)),
                    ),
                    ButtonSegment<PrisonerAction>(
                      value: PrisonerAction.release,
                      label: Text("Release",
                          style:
                              getOptionStyle(captive, PrisonerAction.release)),
                    ),
                    ButtonSegment<PrisonerAction>(
                      value: PrisonerAction.execute,
                      label: Text("Execute",
                          style:
                              getOptionStyle(captive, PrisonerAction.execute)),
                    ),
                  ],
                  selected: {currentDecision},
                  onSelectionChanged: (Set<PrisonerAction> newSelection) {
                    setState(() {
                      _captiveDecisions[captive.id] = newSelection
                          .firstWhere((a) => a != PrisonerAction.undecided);
                    });
                  },
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _statusSortValue(SoldierStatus status) {
    switch (status) {
      case SoldierStatus.killed:
        return 0;
      case SoldierStatus.fled:
        return 1;
      case SoldierStatus.unconscious:
        return 2;
      case SoldierStatus.wounded:
        return 3;
      case SoldierStatus.alive:
        return 4;
    }
  }
}
