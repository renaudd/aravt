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
import 'package:aravt/models/settlement_data.dart';

class DiplomacyReportTab extends StatelessWidget {
  final int? soldierId; // Kept for consistency, though likely unused for now
  const DiplomacyReportTab({super.key, this.soldierId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    // Filter settlements that the player has interacted with or knows about
    // For now, we show all settlements as "Known Entities"
    // (We might want to filter by discovery status later)
    final settlements = gameState.settlements;

    final diplomacyEvents = gameState.eventLog
        .where((e) => e.category == EventCategory.diplomacy && e.isPlayerKnown)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/steppe_background.jpg'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader("Foreign Relations"),
          if (settlements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No known settlements.",
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ...settlements.map((s) => _buildSettlementCard(s)),

          const SizedBox(height: 20),
          _buildSectionHeader("Diplomatic Reports"),
          if (diplomacyEvents.isEmpty)
            const Card(
              color: Colors.black54,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No diplomatic missions recorded.",
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ...diplomacyEvents.reversed.map((e) => _buildEventCard(e)),

          const SizedBox(height: 80), // Pad for bottom menu
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(title,
          style: GoogleFonts.cinzel(
              color: Colors.amber[200],
              fontSize: 18,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettlementCard(Settlement settlement) {
    // Assuming 'Player' is the faction ID we care about for now
    final rel = settlement.getRelationship('Player');

    return Card(
      color: Colors.black.withOpacity(0.6),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settlement.name,
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.location_city, color: Colors.white70),
              ],
            ),
            const Divider(color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Respect", rel.respect, Colors.blue[300]!),
                _buildStat("Admiration", rel.admiration, Colors.green[300]!),
                _buildStat("Fear", rel.fear, Colors.red[300]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(value.toStringAsFixed(1),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildEventCard(GameEvent event) {
    return Card(
      color: Colors.black.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: const Icon(Icons.handshake, color: Colors.amber),
        title: Text(event.message, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          event.date.toShortString(),
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
