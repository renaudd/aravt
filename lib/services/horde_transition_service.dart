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

import 'dart:convert';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/narrative_models.dart';

import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/location_data.dart';

class HordeTransitionService {
  Future<void> handleLeaderDeath(GameState gameState, Soldier leader) async {
    print("[HordeTransition] Handling death of leader: ${leader.name}");

    // 1. Find Successor Candidates (All Captains)
    final captains = gameState.horde
        .where((s) =>
            s.role == SoldierRole.aravtCaptain &&
            s.status == SoldierStatus.alive)
        .toList();

    if (captains.isEmpty) {
      // Fallback: If no captains, pick the oldest soldier or end game?
      // For now, pick oldest soldier.
      final oldest = gameState.horde
          .where((s) => s.status == SoldierStatus.alive)
          .toList()
        ..sort((a, b) => b.age.compareTo(a.age));

      if (oldest.isNotEmpty) {
        captains.add(oldest.first);
      } else {
        // No one left! Game over.
        gameState.gameOverReason = "All soldiers died.";
        gameState.isGameOver = true;
        return;
      }
    }

    // 2. Select Successor: Player always becomes the new leader of the player's horde.
    Soldier? successor = gameState.player;
    if (successor == null || successor.status != SoldierStatus.alive) {
      // Fallback if player is dead or missing (should not happen in normal play yet)
      successor = captains.firstWhere((c) => c.id != leader.id,
          orElse: () => captains.first);
    }

    print("[HordeTransition] Player is now leader: ${successor.name}");

    // 3. Handle Schisms
    List<Soldier> splinteringCaptains = [];
    for (var captain in captains) {
      if (captain.id == successor.id) continue;
      final rel = captain.getRelationship(successor.id);
      // Combined relationship < 15.0 (Admiration + Respect + Fear + Loyalty)
      // Increased threshold to make it harder to keep captains
      double combinedRel =
          rel.admiration + rel.respect + rel.fear + rel.loyalty;

      double threshold = 11.0; // Default Medium
      if (gameState.difficulty.toLowerCase() == 'easy') {
        threshold = 10.0;
      } else if (gameState.difficulty.toLowerCase() == 'hard') {
        threshold = 12.0;
      }

      if (combinedRel < threshold) {
        splinteringCaptains.add(captain);
      }
    }

    // 4. Apply Changes
    // Update roles
    leader.role = SoldierRole.soldier; // No longer leader (is dead anyway)
    successor.role = SoldierRole.hordeLeader;


    if (leader.isPlayer) {
      print(
          "[HordeTransition] Player died. Transferring control to ${successor.name}");
      gameState.setPlayer(successor);
      // Ensure the old player is marked as dead/killed if not already
      if (leader.status == SoldierStatus.alive) {
        leader.status = SoldierStatus.killed;
      }
    }

    // Ensure leader is removed from any captaincy
    final leaderAravt = gameState.findAravtById(leader.aravt);
    if (leaderAravt != null && leaderAravt.captainId == leader.id) {
      // Find a new captain for this aravt if possible, or leave it captainless for now

      leaderAravt.soldierIds.remove(leader.id);
      leaderAravt.captainId =
          -1; // Clear captain ID so a new one can be assigned

      if (leaderAravt.soldierIds.isNotEmpty) {
        // Assign new captain from remaining members
        // (In reality, this aravt might be merged or disbanded, but this is a quick fix)
        // HordeAIService will handle assignment next turn
      }
    }

    // Handle Splinters
    List<String> splinteredAravtIds = [];
    List<Soldier> allSplinterSoldiers = [];
    List<Aravt> allSplinterAravts = [];

    for (var captain in splinteringCaptains) {
      final aravtId = captain.aravt;
      splinteredAravtIds.add(aravtId);

      final aravt = gameState.findAravtById(aravtId);
      if (aravt != null) {
        allSplinterAravts.add(aravt);
        for (var soldierId in List.from(aravt.soldierIds)) {
          final soldier = gameState.findSoldierById(soldierId);
          if (soldier != null) {
            gameState.horde.remove(soldier);
            soldier.aravt =
                aravtId; // Ensure soldier is associated with the new Aravt
            allSplinterSoldiers.add(soldier);
          }
        }
        gameState.aravts.remove(aravt);
      }
    }

    if (allSplinterSoldiers.isNotEmpty) {
      gameState.splinterHordes.add(allSplinterSoldiers);
      gameState.splinterAravts.add(allSplinterAravts);

      //  Difficulty-based combat probability
      bool triggerCombat = true;
      if (gameState.difficulty.toLowerCase() == 'easy') {
        triggerCombat = false;
      } else if (gameState.difficulty.toLowerCase() == 'medium') {
        triggerCombat =
            (new DateTime.now().millisecond % 100) < 25; // 25% chance
      }

      if (triggerCombat) {
        // Trigger Combat immediately via GameState to handle UI transition
        gameState.initiateCombat(
          playerAravts: gameState.aravts,
          opponentAravts: allSplinterAravts,
          allPlayerSoldiers: gameState.horde,
          allOpponentSoldiers: allSplinterSoldiers,
        );
      } else {
        print("[HordeTransition] Splinter combat skipped due to difficulty.");
        // Optional: Log event that they left peacefully or were allowed to leave
      }
    }

    // 6. Return remaining Aravts to camp
    PointOfInterest? playerCamp;
    for (final area in gameState.worldMap.values) {
      try {
        playerCamp =
            area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
        break;
      } catch (e) {}
    }

    if (playerCamp != null) {
      for (final aravt in gameState.aravts) {
        if (aravt.hexCoords != null && aravt.hexCoords != playerCamp.position) {
          int distance = aravt.hexCoords!.distanceTo(playerCamp.position!);
          double travelSeconds = distance * 86400.0;


          aravt.task = MovingTask(
            destination: GameLocation.poi(playerCamp.id),
            durationInSeconds: travelSeconds,
            startTime: gameState.gameDate.toDateTime(),
            followUpAssignment: AravtAssignment.Rest,
          );
        } else {
          aravt.task = null; // Already at camp, just rest
        }
      }
      gameState.logEvent("All remaining Aravts have been recalled to camp.",
          category: EventCategory.general, aravtId: successor.aravt);
    } else {
      // Fallback if camp not found
      for (final aravt in gameState.aravts) {
        aravt.task = null;
      }
      gameState.logEvent(
          "All remaining Aravts have returned to camp to await orders.",
          category: EventCategory.general,
          aravtId: successor.aravt);
    }

    // 5. Narrative Event (JSON for structured UI)
    final Map<String, dynamic> data = {
      'leaderName': leader.name,
      'deathReason': leader.deathReason.name,
      'successorName': successor.name,
      'splinteringCaptains': splinteringCaptains
          .map((c) => {
                'name': c.name,
                'aravtId': c.aravt,
                'portraitIndex': c.portraitIndex,
                'backgroundColor': c.backgroundColor.value,
              })
          .toList(),
    };

    gameState.startNarrativeEvent(NarrativeEvent(
      type: NarrativeEventType.hordeLeaderTransition,
      instigatorId: leader.id,
      targetId: successor.id,
      description: jsonEncode(data),
    ));

    gameState.logEvent(
      "Horde Leader Transition: ${successor.name} is now the leader.",
      category: EventCategory.general,
      severity: EventSeverity.critical,
    );
  }
}
