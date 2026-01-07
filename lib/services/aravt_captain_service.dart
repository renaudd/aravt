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

import 'dart:math';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/game_event.dart';

/// Service for handling the decision-making logic of an Aravt Captain.
class AravtCaptainService {
  final Random _random = Random();

  /// Resolves all Aravt Captain decisions for all aravts in the game.
  Future<void> resolveAravtCaptainTurns(GameState gameState) async {
    // Get all aravts from all hordes
    List<Aravt> allAravts = [
      ...gameState.aravts,
      ...gameState.npcAravts1,
      ...gameState.npcAravts2,
    ];

    for (var aravt in allAravts) {

      // but allow AI to run if player is just a member and captain is NPC.
      final Soldier? captain = gameState.findSoldierById(aravt.captainId);
      if (captain == null || captain.status != SoldierStatus.alive) {
        continue;
      }
      if (captain.isPlayer) continue;

      // Get all active soldier objects in this aravt
      final List<Soldier> soldiersInAravt = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .where((s) => s.status == SoldierStatus.alive && !s.isImprisoned)
          .toList();

      if (soldiersInAravt.isEmpty) continue;

      // Run the 3 sub-tasks
      _resolveDutyAssignments(captain, aravt, soldiersInAravt, gameState);
      _resolveMemberManagement(captain, aravt, soldiersInAravt, gameState);
      _resolvePersonalInteractions(captain, aravt, soldiersInAravt, gameState);
    }
  }

  /// 1. AI for Re-assigning Intra-Aravt Duties
  void _resolveDutyAssignments(Soldier captain, Aravt aravt,
      List<Soldier> soldiersInAravt, GameState gameState) {
    // 1. Collect potential candidates (excluding captain)
    final candidates =
        soldiersInAravt.where((s) => s.id != captain.id).toList();

    if (candidates.isEmpty) return;

    // 2. Assign Lieutenant (Best Leadership/Courage)
    if (aravt.dutyAssignments[AravtDuty.lieutenant] == null ||
        aravt.dutyAssignments[AravtDuty.lieutenant] == captain.id) {
      candidates.sort((a, b) {
        int scoreA = a.leadership * 2 + a.courage;
        int scoreB = b.leadership * 2 + b.courage;
        return scoreB.compareTo(scoreA);
      });
      aravt.dutyAssignments[AravtDuty.lieutenant] = candidates.first.id;
    }

    // 3. Assign Tuulch (Best Charisma/Storyteller)
    if (aravt.dutyAssignments[AravtDuty.tuulch] == null ||
        aravt.dutyAssignments[AravtDuty.tuulch] == captain.id) {
      final remainingCandidates = candidates
          .where((c) => c.id != aravt.dutyAssignments[AravtDuty.lieutenant])
          .toList();
      if (remainingCandidates.isNotEmpty) {
        remainingCandidates.sort((a, b) {
          int scoreA = a.charisma * 2 +
              (a.attributes.contains(SoldierAttribute.storyTeller) ? 10 : 0);
          int scoreB = b.charisma * 2 +
              (b.attributes.contains(SoldierAttribute.storyTeller) ? 10 : 0);
          return scoreB.compareTo(scoreA);
        });
        aravt.dutyAssignments[AravtDuty.tuulch] = remainingCandidates.first.id;
      }
    }

    // 4. Assign Cook (Best Patience/Animal Handling)
    if (aravt.dutyAssignments[AravtDuty.cook] == null ||
        aravt.dutyAssignments[AravtDuty.cook] == captain.id) {
      final remainingCandidates = candidates
          .where((c) =>
              c.id != aravt.dutyAssignments[AravtDuty.lieutenant] &&
              c.id != aravt.dutyAssignments[AravtDuty.tuulch])
          .toList();
      if (remainingCandidates.isNotEmpty) {
        remainingCandidates.sort((a, b) => (b.patience + b.animalHandling)
            .compareTo(a.patience + a.animalHandling));
        aravt.dutyAssignments[AravtDuty.cook] = remainingCandidates.first.id;
      }
    }
  }

  /// 2. AI for Member Management (Stockade/Expel)
  void _resolveMemberManagement(Soldier captain, Aravt aravt,
      List<Soldier> soldiersInAravt, GameState gameState) {
    for (var soldier in soldiersInAravt) {
      if (soldier.id == captain.id) continue;

      final rel = captain.getRelationship(soldier.id);
      bool shouldImprison = false;
      String reason = "";

      // Check for bad traits + low respect/high strictness
      if (soldier.attributes.contains(SoldierAttribute.murderer) ||
          soldier.attributes.contains(SoldierAttribute.bully)) {
        // If captain is perceptive OR strict, they might act. Low chance per day to avoid instant jailing.
        if ((captain.perception > 6 || captain.temperament < 4) &&
            _random.nextDouble() < 0.05) {
          shouldImprison = true;
          reason = "suspicious behavior";
        }
      }

      // Check for insubordination (low loyalty + strict captain)
      if (rel.loyalty < 1.5 &&
          captain.temperament < 4 &&
          _random.nextDouble() < 0.05) {
        shouldImprison = true;
        reason = "insubordination";
      }

      if (shouldImprison && !soldier.isImprisoned) {
        gameState.imprisonSoldier(soldier);
        gameState.logEvent(
            "${captain.name} imprisoned ${soldier.name} for $reason.",
            category: EventCategory.general,
            severity: EventSeverity.high,
            isPlayerKnown: gameState.horde.any((s) => s.id == captain.id));
      } else if (soldier.isImprisoned && _random.nextDouble() < 0.1) {
        // 10% chance per day to release if they were already imprisoned
        gameState.imprisonSoldier(soldier); // Toggles it off
        gameState.logEvent(
            "${captain.name} released ${soldier.name} from the stockade.",
            category: EventCategory.general,
            isPlayerKnown: gameState.horde.any((s) => s.id == captain.id));
      }
    }
  }

  /// 3. AI for Personal Interactions (Gifting)
  void _resolvePersonalInteractions(Soldier captain, Aravt aravt,
      List<Soldier> soldiersInAravt, GameState gameState) {
    // Only charismatic captains bother with this
    if (captain.charisma < 6) return;

    for (var soldier in soldiersInAravt) {
      if (soldier.id == captain.id) continue;

      final rel = soldier.getRelationship(captain.id);
      // If they already admire the captain, maybe reward them to cement loyalty
      // Very low chance per day to keep it rare.
      if (rel.admiration > 4.0 && _random.nextDouble() < 0.02) {
        _attemptGift(captain, soldier, gameState);
      }
    }
  }

  void _attemptGift(Soldier captain, Soldier recipient, GameState gameState) {
    // Find a suitable gift in captain's inventory
    InventoryItem? gift;

    // 1. Look for preferred gift type that is also a treasure
    try {
      gift = captain.personalInventory.firstWhere(
        (i) =>
            i.itemType.name == recipient.giftTypePreference.name &&
            i.valueType == ValueType.Treasure,
      );
    } catch (e) {
      // 2. Fallback to any treasure
      try {
        gift = captain.personalInventory
            .firstWhere((i) => i.valueType == ValueType.Treasure);
      } catch (e2) {
        // No suitable gifts
      }
    }

    if (gift != null) {
      captain.personalInventory.remove(gift);
      recipient.personalInventory.add(gift);

      // Boost relationships significantly
      recipient.getRelationship(captain.id).updateLoyalty(0.5);
      recipient.getRelationship(captain.id).updateAdmiration(0.5);

      gameState.logEvent(
          "${captain.name} gifted ${gift.name} to ${recipient.name} as a reward for their faithful service.",
          category: EventCategory.general,
          severity: EventSeverity.low,
          isPlayerKnown: gameState.horde.any((s) => s.id == captain.id));
    }
  }
}
