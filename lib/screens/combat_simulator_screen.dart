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
import '../providers/game_state.dart';
import '../models/soldier_data.dart';
import '../widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/paper_panel.dart';

class CombatSimulatorScreen extends StatefulWidget {
  const CombatSimulatorScreen({super.key});

  @override
  State<CombatSimulatorScreen> createState() => _CombatSimulatorScreenState();
}

class _CombatSimulatorScreenState extends State<CombatSimulatorScreen> {
  // Army Builder State
  final List<Soldier> _teamA = [];
  final List<Soldier> _teamB = [];

  String _selectedTerrain = 'Steppe';
  final List<String> _terrains = ['Steppe', 'Forest', 'Mountain', 'River'];

  double _winOddsA = 0.5;
  double _winOddsB = 0.5;

  void _calculateWinOdds() {
    double pointsA =
        _teamA.fold(0.0, (sum, s) => sum + s.calculateCombatPointValue());
    double pointsB =
        _teamB.fold(0.0, (sum, s) => sum + s.calculateCombatPointValue());

    if (pointsA + pointsB == 0) {
      _winOddsA = 0.5;
      _winOddsB = 0.5;
    } else {
      _winOddsA = pointsA / (pointsA + pointsB);
      _winOddsB = pointsB / (pointsA + pointsB);
    }
  }

  @override
  Widget build(BuildContext context) {
    _calculateWinOdds();
    // ignore: unused_local_variable
    final gameState = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Combat Simulator", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _buildTeamBuilder("Army A", _teamA, Colors.blue)),
                _buildCenterControls(),
                Expanded(
                    child: _buildTeamBuilder("Army B", _teamB, Colors.red)),
              ],
            ),
          ),
          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildTeamBuilder(String name, List<Soldier> team, Color teamColor) {
    double totalPoints =
        team.fold(0.0, (sum, s) => sum + s.calculateCombatPointValue());

    return Expanded(
      child: PaperPanel(
        padding: EdgeInsets.zero,
        borderColor: teamColor.withValues(alpha: 0.5),
        borderWidth: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(name,
                  style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: teamColor.withAlpha(200))),
            ),
            Text("Total Points: ${totalPoints.toStringAsFixed(1)}",
                style:
                    GoogleFonts.cinzel(fontSize: 12, color: Colors.brown[800])),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: team.length,
                itemBuilder: (context, index) {
                  final soldier = team[index];
                  return ListTile(
                    dense: true,
                    title: Text(soldier.name.toUpperCase(),
                        style: GoogleFonts.cinzel(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D241E))), // Dark Espresso
                    subtitle: Text(
                        "Combat Value: ${soldier.calculateCombatPointValue().toStringAsFixed(1)}",
                        style: TextStyle(
                            color: const Color(0xFF4A3F35),
                            fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => setState(() => team.removeAt(index)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  8, 8, 8, 40), // Added bottom padding to avoid menu
              child: ElevatedButton(
                onPressed: () => _showAddSoldierDialog(team),
                style: ElevatedButton.styleFrom(
                    backgroundColor: teamColor.withValues(alpha: 0.8),
                    foregroundColor: Colors.white),
                child: const Text("Add Soldier"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.black.withValues(alpha: 0.7),
      child: Column(
        children: [
          Text("Terrain",
              style: GoogleFonts.cinzel(
                  fontWeight: FontWeight.bold, color: Colors.amber)),
          DropdownButton<String>(
            value: _selectedTerrain,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            items: _terrains
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) => setState(() => _selectedTerrain = val!),
          ),
          const Spacer(),
          Text("Victory Odds:",
              style: GoogleFonts.cinzel(fontSize: 12, color: Colors.white70)),
          Text(
            "${(_winOddsA * 100).toStringAsFixed(0)}% / ${(_winOddsB * 100).toStringAsFixed(0)}%",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 10),
          _buildOddsBar(),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_teamA.isEmpty || _teamB.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text("Each army must have at least one soldier.")),
                );
                return;
              }
              // Trigger combat in GameState
              context.read<GameState>().startSimulatorCombat(_teamA, _teamB);
              // Navigation will be handled by GameStateNavigator if integrated,
              // but since we are in a standalone simulator, we might need a push.
              // Actually, GameState change triggers Navigator in main.dart or similar?
              // Let's assume there's a listener.
              // If not, we push to '/combat'.
              Navigator.pushNamed(context, '/combat');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text("SIMULATE",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOddsBar() {
    return Container(
      width: 120,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[850],
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Expanded(
                flex: (_winOddsA * 100).round().clamp(1, 99),
                child: Container(color: Colors.blue)),
            Expanded(
                flex: (_winOddsB * 100).round().clamp(1, 99),
                child: Container(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  void _addSoldierTemplate(List<Soldier> team, String type) {
    int id = team.length +
        (team == _teamA ? 10000 : 20000) +
        DateTime.now().millisecondsSinceEpoch % 10000;

    Soldier soldier;
    if (type == 'Archer') {
      soldier = SoldierGenerator.generateNewSoldier(
        id: id,
        aravt: 'Simulator',
        overrideLongRangeArchery: 7,
        overrideMountedArchery: 4,
        overrideStrength: 4,
      );
    } else if (type == 'Veteran') {
      soldier = SoldierGenerator.generateNewSoldier(
        id: id,
        aravt: 'Simulator',
        overrideSword: 8,
        overrideSpear: 6,
        overrideStrength: 7,
        overrideExperience: 1500,
      );
    } else if (type == 'Scout') {
      soldier = SoldierGenerator.generateNewSoldier(
        id: id,
        aravt: 'Simulator',
        overrideMountedArchery: 8,
        overrideHorsemanship: 9,
        overridePerception: 8,
      );
    } else {
      soldier = SoldierGenerator.generateNewSoldier(
        id: id,
        aravt: 'Simulator',
      );
    }

    setState(() => team.add(soldier));
  }

  void _showAddSoldierDialog(List<Soldier> team) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: PaperPanel(
            width: 350,
            height: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("ADD SOLDIER TO ARMY",
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D241E))),
                const SizedBox(height: 20),
                _buildTemplateOption(ctx, team, "Archer", Icons.adjust),
                _buildTemplateOption(ctx, team, "Veteran", Icons.shield),
                _buildTemplateOption(ctx, team, "Scout", Icons.visibility),
                _buildTemplateOption(
                    ctx, team, "Random Recruit", Icons.person_add),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("CLOSE",
                      style: GoogleFonts.cinzel(
                          color: const Color(0xFF4A3F35),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateOption(
      BuildContext context, List<Soldier> team, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4A3F35)),
      title: Text(label.toUpperCase(),
          style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D241E))),
      onTap: () {
        _addSoldierTemplate(team, label);
        Navigator.pop(context);
      },
    );
  }
}
