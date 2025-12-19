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
import '../models/assignment_data.dart';
import '../models/horde_data.dart';
import '../widgets/aravt_assignment_dialog.dart';
import '../widgets/persistent_menu_widget.dart';

class StockadeScreen extends StatelessWidget {
  const StockadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final imprisonedSoldiers =
        gameState.horde.where((s) => s.isImprisoned).toList();
    final assignedAravts = gameState.aravts
        .where((a) => a.currentAssignment == AravtAssignment.GuardPrisoners)
        .toList();
    final availableAravts =
        gameState.aravts.where((a) => a.task == null).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text('Stockade', style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                    context, assignedAravts, availableAravts, gameState),
                const SizedBox(height: 20),
                Expanded(
                  child: imprisonedSoldiers.isEmpty
                      ? Center(
                          child: Text(
                            'No prisoners currently held.',
                            style: GoogleFonts.cinzel(
                                color: Colors.white54, fontSize: 18),
                          ),
                        )
                      : ListView.builder(
                          itemCount: imprisonedSoldiers.length,
                          itemBuilder: (context, index) {
                            final soldier = imprisonedSoldiers[index];
                            return _buildPrisonerCard(soldier);
                          },
                        ),
                ),
              ],
            ),
          ),
          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Aravt> assignedAravts,
      List<Aravt> availableAravts, GameState gameState) {
    final bool isHordeLeader =
        gameState.player?.role == SoldierRole.hordeLeader;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guards Assigned: ${assignedAravts.length}',
              style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Available Aravts: ${availableAravts.length}',
              style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        if (isHordeLeader)
          ElevatedButton.icon(
            icon: const Icon(Icons.security),
            label: const Text('Assign Guards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AravtAssignmentDialog(
                  title: 'Assign Guards',
                  description: 'Assign Aravts to guard the stockade.',
                  availableAssignments: const [AravtAssignment.GuardPrisoners],
                  assignedAravts: assignedAravts,
                  availableAravts: availableAravts,
                  onConfirm: (assignment, selectedAravtIds, option) {
                    for (final id in selectedAravtIds) {
                      final aravt = gameState.findAravtById(id);
                      if (aravt != null) {
                        // Need a way to assign to stockade.
                        // We can use a special POI ID or just set the assignment.
                        // For now, let's assume we can just set the assignment and it's camp-based.
                        // But wait, assignAravtToPoi requires a POI.
                        // We should find the camp POI.
                        final campPoi =
                            gameState.findPoiByIdWorld('camp-player');
                        if (campPoi != null) {
                          gameState.assignAravtToPoi(
                              aravt, campPoi, assignment,
                              option: option);
                        } else {
                          // Fallback or error handling
                          print(
                              "Error: Camp POI not found for stockade assignment.");
                        }
                      }
                    }
                  },
                ),
              );
            },
          )
        else
          Text(
            'Only Horde Leader can assign guards',
            style: GoogleFonts.cinzel(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildPrisonerCard(Soldier soldier) {
    final duration = soldier.imprisonmentStartDate != null
        ? DateTime.now().difference(soldier.imprisonmentStartDate!).inDays
        : 0;

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  soldier.name,
                  style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                _buildHealthStatus(soldier),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Imprisoned for: $duration days',
              style: const TextStyle(color: Colors.white70),
            ),
            if (soldier.imprisonmentNotes != null &&
                soldier.imprisonmentNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Notes:',
                style:
                    TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              Text(
                soldier.imprisonmentNotes!,
                style: const TextStyle(
                    color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatus(Soldier soldier) {
    // Simple health check for now, can be more complex
    String status = 'Healthy';
    Color color = Colors.green;
    if (soldier.bodyHealthCurrent < soldier.bodyHealthMax * 0.5) {
      status = 'Unwell';
      color = Colors.orange;
    } else if (soldier.bodyHealthCurrent < soldier.bodyHealthMax * 0.25) {
      status = 'Sick';
      color = Colors.red;
    }
    // Add hunger check if available

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
