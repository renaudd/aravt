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
import 'package:aravt/models/training_report.dart';

class TrainingReportTab extends StatelessWidget {
  final int? soldierId;
  const TrainingReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    final List<TrainingReport> reports =
        gameState.trainingReports.where((report) {
      if (!report.isPlayerReport) return false;
      if (soldierId == null) return true;
      return report.individualResults.any((r) => r.soldierId == soldierId);
    }).toList();

    final reversedReports = reports.reversed.toList();

    if (reversedReports.isEmpty) {
      return _buildEmptyTab(
          "No training reports filed${soldierId == null ? '' : ' for this soldier'}.");
    }

    return Container(
      decoration: _tabBackground(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: reversedReports.length,
        itemBuilder: (context, index) {
          final report = reversedReports[index];
          return Card(
            color: Colors.black.withOpacity(0.6),
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ExpansionTile(
              leading: const Icon(Icons.fitness_center, color: Colors.amber),
              title: Text(
                "${report.trainingType} Training",
                style: GoogleFonts.cinzel(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${report.date.toString()} - ${report.aravtName}",
                style: const TextStyle(color: Colors.white70),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Captain: ${report.captainName}",
                          style: const TextStyle(color: Colors.white70)),
                      Text("Drill Sergeant: ${report.drillSergeantName}",
                          style: const TextStyle(color: Colors.white70)),
                      const Divider(color: Colors.white24),
                      ...report.individualResults.map((res) {
                        if (soldierId != null && res.soldierId != soldierId) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          dense: true,
                          title: Text(res.soldierName,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text("Trained ${res.skillTrained}",
                              style: const TextStyle(color: Colors.white70)),
                          trailing: Text(
                              "+${res.xpGained.toStringAsFixed(2)} Skill",
                              style: const TextStyle(color: Colors.green)),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
}
