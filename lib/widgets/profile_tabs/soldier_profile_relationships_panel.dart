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

// widgets/profile_tabs/soldier_profile_relationships_panel.dart

import 'package:aravt/screens/soldier_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/widgets/soldier_portrait_widget.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';

class SoldierProfileRelationshipsPanel extends StatefulWidget {
  final Soldier soldier;
  const SoldierProfileRelationshipsPanel({super.key, required this.soldier});

  @override
  State<SoldierProfileRelationshipsPanel> createState() =>
      _SoldierProfileRelationshipsPanelState();
}

class _SoldierProfileRelationshipsPanelState
    extends State<SoldierProfileRelationshipsPanel>
    with TickerProviderStateMixin {
  // This controller needs to be late-initialized
  late TabController _tabController;

  // These will be populated by _initializeAndGroupData
  Map<String, List<Soldier>> _aravts = {};
  List<String> _sortedAravtKeys = [];
  Soldier? _hordeLeader;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // We need to initialize the TabController here, but it needs data from the provider.
    // We use addPostFrameCallback to access the provider safely after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // We read the GameState here, as it's needed for initialization
        final gameState = context.read<GameState>();
        setState(() {
          _initializeAndGroupData(gameState);
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    // Only dispose if it was initialized
    if (_isInitialized) {
      _tabController.dispose();
    }
    super.dispose();
  }

  /// Groups soldiers and initializes the TabController.
  void _initializeAndGroupData(GameState gameState) {
    final allSoldiers = gameState.horde;
    final viewingSoldier = widget.soldier;

    _hordeLeader = allSoldiers.firstWhere(
        (s) => s.role == SoldierRole.hordeLeader,
        orElse: () => allSoldiers.first);

    _aravts = _groupSoldiersByAravt(allSoldiers, viewingSoldier, _hordeLeader!);
    _sortedAravtKeys = _aravts.keys.toList()..sort();

    int initialIndex = _sortedAravtKeys.indexOf(viewingSoldier.aravt);
    if (initialIndex == -1 || initialIndex >= _sortedAravtKeys.length) {
      initialIndex = 0;
    }

    _tabController = TabController(
      length: _sortedAravtKeys.isNotEmpty
          ? _sortedAravtKeys.length
          : 1, // Must be at least 1
      initialIndex: _sortedAravtKeys.isEmpty ? 0 : initialIndex,
      vsync: this,
    );
  }

  /// Groups soldiers by aravt, excluding the viewing soldier and leader.
  Map<String, List<Soldier>> _groupSoldiersByAravt(
      List<Soldier> allSoldiers, Soldier viewingSoldier, Soldier hordeLeader) {
    final Map<String, List<Soldier>> map = {};
    for (final soldier in allSoldiers) {
      if (soldier.id == viewingSoldier.id) continue;
      if (soldier.id == hordeLeader.id) continue;

      (map[soldier.aravt] ??= []).add(soldier);
    }

    map.forEach((aravtId, soldierList) {
      Soldier? captain;
      try {
        captain =
            soldierList.firstWhere((s) => s.role == SoldierRole.aravtCaptain);
      } catch (e) {
        captain = null; // No captain found
      }

      soldierList.sort((a, b) => a.name.compareTo(b.name));

      if (captain != null) {
        soldierList.remove(captain);
        soldierList.insert(0, captain);
      }
    });
    return map;
  }

  @override
  Widget build(BuildContext context) {
    // We need to watch for GameState changes (e.g., soldier death/transfer)
    // and re-initialize if the aravt list changes.
    final gameState = context.watch<GameState>();
    final allSoldiers = gameState.horde;
    final viewingSoldier = widget.soldier;

    // Re-group data on build to catch changes
    _hordeLeader = allSoldiers.firstWhere(
        (s) => s.role == SoldierRole.hordeLeader,
        orElse: () => allSoldiers.first);
    _aravts = _groupSoldiersByAravt(allSoldiers, viewingSoldier, _hordeLeader!);
    _sortedAravtKeys = _aravts.keys.toList()..sort();

    // Check if controller is initialized
    if (!_isInitialized) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFE0D5C1)));
    }

    // Check if the number of aravts has changed
    if (_tabController.length !=
        (_sortedAravtKeys.isNotEmpty ? _sortedAravtKeys.length : 1)) {
      // If it changed, dispose the old one and create a new one
      _tabController.dispose();
      _initializeAndGroupData(gameState);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel (Leader & External)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (viewingSoldier.id != _hordeLeader!.id)
                    _buildLeaderPanel(viewingSoldier, _hordeLeader!),
                  const SizedBox(height: 20),
                  _buildExternalPanel(viewingSoldier),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right Panel (Horde Aravts)
          Expanded(
            flex: 3,
            child: _buildHordePanel(
                context, viewingSoldier, _aravts, _sortedAravtKeys),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderPanel(Soldier viewingSoldier, Soldier hordeLeader) {
    final leaderRel = viewingSoldier.hordeRelationships[hordeLeader.id];
    return _RelUiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Towards Leader: ${hordeLeader.name}',
            style: GoogleFonts.cinzel(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white54),
          if (leaderRel != null)
            _RelationshipValuesDisplay(values: leaderRel)
          else
            Text('No Data', style: GoogleFonts.cinzel(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildExternalPanel(Soldier viewingSoldier) {
    if (viewingSoldier.externalRelationships.isEmpty) {
      return _RelUiPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Towards Other Factions',
              style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white54),
            Text('No external relations.',
                style: GoogleFonts.cinzel(color: Colors.grey)),
          ],
        ),
      );
    }

    return _RelUiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Towards Other Factions',
            style: GoogleFonts.cinzel(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white54),
          ...viewingSoldier.externalRelationships.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key,
                    style: GoogleFonts.cinzel(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                _RelationshipValuesDisplay(values: entry.value),
                const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold);

    return Padding(
      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
              width: 45,
              child:
                  Text('ADM', style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(
              width: 45,
              child:
                  Text('RES', style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(
              width: 45,
              child: Text('FEAR',
                  style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(
              width: 45,
              child:
                  Text('LOY', style: headerStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildStatCell(double value) {
    Color color = Colors.white.withOpacity(0.8);
    FontWeight fontWeight = FontWeight.normal;

    if (value > 2.99) {
      color = Colors.green[300]!;
    } else if (value < 2.00) {
      color = Colors.red[300]!;
    }
    if (value > 3.99 || value < 1.00) {
      fontWeight = FontWeight.bold;
    }

    return SizedBox(
      width: 45,
      child: Text(
        value.toStringAsFixed(2),
        textAlign: TextAlign.center,
        style: GoogleFonts.cinzel(
          color: color,
          fontWeight: fontWeight,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHordePanel(
    BuildContext context,
    Soldier viewingSoldier,
    Map<String, List<Soldier>> aravts,
    List<String> sortedAravtKeys,
  ) {
    return _RelUiPanel(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.cinzel(),
            tabs: sortedAravtKeys
                .map((aravtName) => Tab(text: aravtName))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: sortedAravtKeys.map((aravtName) {
                final members = aravts[aravtName]!;

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildHeaderRow(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(0),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final relationship =
                              viewingSoldier.hordeRelationships[member.id];

                          final bool isCaptain =
                              member.role == SoldierRole.aravtCaptain;
                          final titleStyle = GoogleFonts.cinzel(
                            color: member.isPlayer
                                ? Color(0xFFE0D5C1)
                                : (isCaptain
                                    ? Colors.yellow[300]
                                    : Colors.white),
                            fontWeight: FontWeight.bold,
                          );

                          return ListTile(
                            leading: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SoldierProfileScreen(
                                      soldierId: member.id,
                                    ),
                                  ),
                                );
                              },
                              child: SoldierPortrait(
                                index: member.portraitIndex,
                                size: 40.0,
                                backgroundColor: member.backgroundColor,
                              ),
                            ),
                            title: Text(
                              member.name,
                              style: titleStyle,
                            ),
                            subtitle: isCaptain
                                ? Text("Captain",
                                    style: GoogleFonts.cinzel(
                                        color: Colors.yellow[300],
                                        fontSize: 12))
                                : null,
                            trailing: relationship != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatCell(relationship.admiration),
                                      _buildStatCell(relationship.respect),
                                      _buildStatCell(relationship.fear),
                                      _buildStatCell(relationship.loyalty),
                                    ],
                                  )
                                : SizedBox(
                                    width: 180,
                                    child: Text('No Data',
                                        style: GoogleFonts.cinzel(
                                            color: Colors.grey),
                                        textAlign: TextAlign.center)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Local UI Panel for this screen, to match old style ---
class _RelUiPanel extends StatelessWidget {
  final Widget child;
  const _RelUiPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Ensure the panel doesn't overflow
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
      ),
      child: child,
    );
  }
}

// --- Local RelationshipValuesDisplay widget ---
class _RelationshipValuesDisplay extends StatelessWidget {
  final RelationshipValues values;
  const _RelationshipValuesDisplay({required this.values});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow('Adm', values.admiration),
        _buildStatRow('Rsp', values.respect),
        _buildStatRow('Fear', values.fear),
        _buildStatRow('Loy', values.loyalty),
      ],
    );
  }

  Widget _buildStatRow(String label, double value) {
    Color color = Colors.white.withOpacity(0.8);
    FontWeight fontWeight = FontWeight.normal;

    if (value > 2.99) {
      color = Colors.green[300]!;
    } else if (value < 2.00) {
      color = Colors.red[300]!;
    }
    if (value > 3.99 || value < 1.00) {
      fontWeight = FontWeight.bold;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.cinzel(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            value.toStringAsFixed(2),
            style: GoogleFonts.cinzel(
              color: color,
              fontWeight: fontWeight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
