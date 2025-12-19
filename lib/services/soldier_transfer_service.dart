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

import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/horde_data.dart'; // For Aravt
import 'package:aravt/models/game_event.dart'; // <-- FIX: Added missing import

/// Service for handling the morale and relationship changes
/// from soldier transfers, imprisonment, or expulsion.
class SoldierTransferService {
  /// Resolves all soldier transfer morale changes at the end of a turn.
  Future<void> resolveSoldierTransfers(
      GameState gameState, Map<int, String> soldierOriginalAravt) async {
    // Get a modifiable list of all soldiers
    List<Soldier> allSoldiers = [
      ...gameState.horde,
      ...gameState.npcHorde1,
      ...gameState.npcHorde2,
    ];

    for (var soldier in allSoldiers) {
      // Check for expulsion first, as they shouldn't be processed further
      if (soldier.isExpelled) {
        // This is a flag we just set, so the game state can remove them
        // The actual removal will be handled by the game state.
        continue;
      }

      final String originalAravtId =
          soldierOriginalAravt[soldier.id] ?? soldier.aravt;
      final String currentAravtId = soldier.aravt;

      if (originalAravtId != currentAravtId) {
        // The soldier was transferred! Apply morale effects.
        _applyTransferMoraleEffects(
            soldier, originalAravtId, currentAravtId, gameState);
      }


      if (soldier.isImprisoned) {
        _applyImprisonmentEffects(soldier, gameState);
      }

    }
  }

  /// Calculates and applies the morale/relationship changes for a single soldier
  /// based on their transfer.
  void _applyTransferMoraleEffects(Soldier soldier, String originalAravtId,
      String currentAravtId, GameState gameState) {
    // 1. Get the player (for relationship checks)
    final Soldier? player = gameState.player;
    if (player == null) return;

    // 2. Get new/old aravts and captains

    final Aravt? newAravt = gameState.findAravtById(currentAravtId);
    final Soldier? newCaptain = (newAravt != null)
        ? gameState.findSoldierById(newAravt.captainId)
        : null;

    // --- Define positive/negative factors ---
    double loyaltyChange = 0;
    double admirationChange = 0; // Admiration for the player/leader

    // Negative: Moved from player's aravt
    if (originalAravtId == player.aravt &&
        currentAravtId != player.aravt &&
        soldier.role != SoldierRole.aravtCaptain) {
      loyaltyChange -= 0.5;
      admirationChange -= 0.2;
      print(
          "TRANSFER (${soldier.name}): Feels slighted for being moved from the player's aravt.");
    }

    // Negative: Demoted from Captain
    // (This logic might be better handled in Step 1, but we can check here)
    // We assume their role *would* be updated before this step.
    if (soldier.role != SoldierRole.aravtCaptain &&
        originalAravtId != currentAravtId) {
      // How to check if they *were* a captain? We need to store original role too.
      // For now, let's skip this check as it's complex.
    }

    // Positive: Promoted to Captain
    if (soldier.role == SoldierRole.aravtCaptain &&
        newAravt != null &&
        newAravt.captainId == soldier.id) {
      loyaltyChange += 1.0;
      admirationChange += 0.5;
      print(
          "TRANSFER (${soldier.name}): Is honored to be promoted to captain!");
    }

    // Positive: Moved to player's aravt
    if (currentAravtId == player.aravt && originalAravtId != player.aravt) {
      loyaltyChange += 0.3;
      admirationChange += 0.3;
      print("TRANSFER (${soldier.name}): Is happy to join the player's aravt.");
    }

    // Positive: Moved to a good leader's aravt
    if (newCaptain != null && newCaptain.id != player.id) {
      if (newCaptain.leadership > 7 || newCaptain.charisma > 7) {
        loyaltyChange += 0.2;
        print(
            "TRANSFER (${soldier.name}): Respects their new captain (${newCaptain.name}).");
      }
    }

    // TODO: Positive: Moved to be with friends
    // (Requires looping soldier.hordeRelationships)

    // --- Apply changes ---
    final relToPlayer = soldier.getRelationship(player.id);
    relToPlayer.updateLoyalty(loyaltyChange);
    relToPlayer.updateAdmiration(admirationChange);

    if (loyaltyChange != 0 || admirationChange != 0) {
      gameState.logEvent(
        "${soldier.name} reflects on their new assignment in ${newAravt?.id ?? 'a new aravt'}.",

        severity: (loyaltyChange + admirationChange > 0)
            ? EventSeverity.low
            : EventSeverity.normal,
        soldierId: soldier.id,
      );
    }
  }


  void _applyImprisonmentEffects(Soldier soldier, GameState gameState) {
    if (gameState.player == null) return;

    final relToPlayer = soldier.getRelationship(gameState.player!.id);
    relToPlayer.updateAdmiration(-0.1); // Constant resentment
    relToPlayer.updateLoyalty(-0.05);

    print("IMPRISONMENT (${soldier.name}): Resents being in the stockade.");

    // TODO: Add logic for starvation/sickness
    // This will be handled in Step 11 (Soldier Updates)
  }

}
