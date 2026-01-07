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

import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

class LeadershipReportsService {
  Future<void> resolveLeadershipAndReports(GameState gameState) async {
    print(
        "Step 10.8: Resolving Leadership & Reports (Lieutenant, Chronicler)...");

    // Lieutenant: Daily check.
    // Chronicler: Weekly entry (e.g., every 7 days).
    final isChroniclerDay = gameState.turn.turnNumber % 7 == 0;

    for (final aravt in gameState.aravts) {
      final members = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      // Only process reports for the player's horde
      if (!gameState.aravts.contains(aravt)) continue;

      // --- LIEUTENANT (Daily) ---
      final lieutenantId = aravt.dutyAssignments[AravtDuty.lieutenant];
      if (lieutenantId != null) {
        final lieutenant = gameState.findSoldierById(lieutenantId);
        if (lieutenant != null && lieutenant.status == SoldierStatus.alive) {
          // Calculate Leadership Quality
          // Based on Leadership, Intelligence, and Judgment
          final leadershipQuality = (lieutenant.leadership +
                  lieutenant.intelligence +
                  lieutenant.judgment) /
              3.0;

          if (leadershipQuality >= 6) {
            // Good Leadership: Boost Organization (reduce stress slightly, maybe small XP gain for everyone?)
            // Let's say small XP gain in 'adaptability' or 'patience' if those were skills.
            // Since they are stats, maybe just reduce stress and increase loyalty to Captain?

            final captainId = aravt.captainId;

            for (final s in members) {
              if (s.id == lieutenant.id) continue;

              // Reduce Stress
              s.stress = (s.stress - 0.3).clamp(0.0, 100.0);

              // Increase Loyalty to Captain (Lieutenant keeps them in line)
              // Increase Loyalty to Captain (Lieutenant keeps them in line)
              if (!s.hordeRelationships.containsKey(captainId)) {
                s.hordeRelationships[captainId] = RelationshipValues();
              }
              s.hordeRelationships[captainId]!.loyalty =
                  (s.hordeRelationships[captainId]!.loyalty + 0.05)
                      .clamp(0.0, 5.0);
            }
          }
        }
      }

      // --- CHRONICLER (Weekly) ---
      if (isChroniclerDay) {
        final chroniclerId = aravt.dutyAssignments[AravtDuty.chronicler];
        if (chroniclerId != null) {
          final chronicler = gameState.findSoldierById(chroniclerId);
          if (chronicler != null && chronicler.status == SoldierStatus.alive) {
            // Calculate Chronicle Quality
            // Based on Knowledge, Intelligence, and maybe 'poet' attribute?
            double quality =
                (chronicler.knowledge + chronicler.intelligence) / 2.0;
            if (chronicler.attributes.contains(SoldierAttribute.poet)) {
              quality += 2.0;
            }
            if (chronicler.attributes.contains(SoldierAttribute.storyTeller)) {
              quality += 2.0;
            }

            if (quality >= 6) {
              // Good Chronicle: Log an event summarizing the week?
              // Or just a generic "Chronicle written" event that boosts morale?
              // Let's do a morale boost and a log entry.

              for (final s in members) {
                // Reduce Stress (Feeling of legacy)
                s.stress = (s.stress - 1.0).clamp(0.0, 100.0);
              }

              gameState.logEvent(
                "Chronicler ${chronicler.name} has recorded the deeds of Aravt ${aravt.id} for posterity.",
                category: EventCategory.general,
                severity: EventSeverity.normal,
              );
            }
          }
        }
      }
    }
  }
}
