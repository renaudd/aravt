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
import 'package:aravt/models/fish_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/fishing_report.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/combat_service.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';

class FishingService {
  final Random _random = Random();

  Future<FishingTripReport> resolveFishingTrip({
    required Aravt aravt,
    required TerrainType terrain,
    required String locationName,
    required GameDate date,
    required GameState gameState,
  }) async {
    final List<IndividualFishingResult> individualResults = [];
    // Filter fish valid for this terrain
    final List<Fish> localFish = FishDatabase.allFish
        .where((f) => f.terrains.contains(terrain))
        .toList();

    // Fallback if water has no fish defined yet
    if (localFish.isEmpty) {
      return FishingTripReport(
        date: date.copy(),
        aravtId: aravt.id,
        aravtName: aravt.id,
        locationName: locationName,
        individualResults: [],
      );
    }

    int currentTurn = gameState.turn.turnNumber;

    for (final soldierId in aravt.soldierIds) {
      final soldier = gameState.findSoldierById(soldierId);
      if (soldier != null &&
          soldier.status == SoldierStatus.alive &&
          !soldier.isImprisoned) {
        final result =
            _resolveSoldierFishing(soldier, localFish, gameState, aravt);
        individualResults.add(result);

        //  Log Performance based on results
        if (result.totalMeat > 10.0 || result.catches.length >= 4) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Caught a huge amount of fish.",
              isPositive: true,
              magnitude: 2.0));
          soldier.pendingJustifications.add(JustificationEvent(
            description: "Caught a huge haul of fish (${result.totalMeat}kg)",
            type: JustificationType.praise,
            expiryTurn: currentTurn + 2,
            magnitude: 1.0,
          ));
        } else if (result.totalMeat > 0) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Successful fishing trip.",
              isPositive: true,
              magnitude: 1.0));
          soldier.pendingJustifications.add(JustificationEvent(
            description: "Caught some fish (${result.totalMeat}kg)",
            type: JustificationType.praise,
            expiryTurn: currentTurn + 2,
            magnitude: 0.5,
          ));
        } else {
          soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Caught nothing while fishing.",
            isPositive: false,
          ));
          soldier.pendingJustifications.add(JustificationEvent(
            description: "Failed to catch any fish",
            type: JustificationType.scold,
            expiryTurn: currentTurn + 2,
            magnitude: 0.3,
          ));
        }
      }
    }

    // Sort individualResults so Captain is first
    individualResults.sort((a, b) {
      final soldierA = gameState.findSoldierById(a.soldierId);
      final soldierB = gameState.findSoldierById(b.soldierId);
      if (soldierA?.role == SoldierRole.aravtCaptain) return -1;
      if (soldierB?.role == SoldierRole.aravtCaptain) return 1;
      return aravt.soldierIds
          .indexOf(a.soldierId)
          .compareTo(aravt.soldierIds.indexOf(b.soldierId));
    });

    // Filter out soldiers who caught nothing
    final filteredResults =
        individualResults.where((result) => result.totalMeat > 0).toList();

    return FishingTripReport(
      date: date.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      locationName: locationName,
      individualResults: filteredResults,
    );
  }

  IndividualFishingResult _resolveSoldierFishing(
      Soldier soldier, List<Fish> localFish, GameState gameState, Aravt aravt) {
    final List<CaughtFish> catches = [];

    // 1. Determine Technique
    final _FishingTechnique technique = _chooseFishingTechnique(soldier);

    // 2. Determine how many "good opportunities" they get today.
    // Fishing is about Patience first, then Perception.
    double opportunityScore = (soldier.patience * 3.0) +
        (soldier.perception * 1.5) +
        (soldier.experience / 10.0) +
        (_random.nextInt(30) - 15); // Variance

    int opportunities = 0;
    if (opportunityScore > 40) {
      opportunities = 4;
    } else if (opportunityScore > 30) {
      opportunities = 3;
    } else if (opportunityScore > 20) {
      opportunities = 2;
    } else if (opportunityScore > 10) {
      opportunities = 1;
    }

    for (int i = 0; i < opportunities; i++) {
      // 3. Identify Fish (weighted random based on rarity)
      final Fish fish = _spotFish(localFish);

      // 4. Attempt Catch
      if (_attemptCatch(soldier, fish, technique)) {
        // Success! Calculate yield.
        // --- UNDERSTRENGTH PENALTY ---
        final int memberCount = aravt.soldierIds.length;
        final double understrengthFactor = (memberCount / 10.0).clamp(0.0, 1.0);

        double meat =
            (fish.minMeat +
            _random.nextDouble() * (fish.maxMeat - fish.minMeat));
        meat *= understrengthFactor;

        catches.add(CaughtFish(
          fishId: fish.id,
          fishName: fish.name,
          meatYield: double.parse(meat.toStringAsFixed(1)),
          techniqueUsed: technique.name,
        ));
      }
    }

    return IndividualFishingResult(
      soldierId: soldier.id,
      soldierName: soldier.name,
      catches: catches,
    );
  }

  Fish _spotFish(List<Fish> possibleFish) {
    int totalWeight = possibleFish.fold(0, (sum, f) => sum + f.rarityWeight);
    int roll = _random.nextInt(totalWeight);
    int currentWeight = 0;
    for (final fish in possibleFish) {
      currentWeight += fish.rarityWeight;
      if (roll < currentWeight) return fish;
    }
    return possibleFish.last;
  }

  _FishingTechnique _chooseFishingTechnique(Soldier soldier) {
    // Find best available tool and skill combination
    double shieldSkill = soldier.equippedItems.containsKey(EquipmentSlot.shield)
        ? soldier.shieldSkill
        : -1.0;
    double spearSkill = soldier.equippedItems.containsKey(EquipmentSlot.spear)
        ? soldier.spearSkill
        : -1.0;
    double swordSkill =
        soldier.equippedItems.containsKey(EquipmentSlot.melee) &&
                (soldier.equippedItems[EquipmentSlot.melee]?.itemType ==
                    ItemType.sword)
            ? soldier.swordSkill
            : -1.0;

    if (shieldSkill >= spearSkill &&
        shieldSkill >= swordSkill &&
        shieldSkill != -1) {
      return _FishingTechnique(
          "Netting (Shield)", ItemType.shield, shieldSkill);
    } else if (spearSkill >= swordSkill && spearSkill != -1) {
      return _FishingTechnique("Spearfishing", ItemType.spear, spearSkill);
    } else if (swordSkill != -1) {
      return _FishingTechnique("Stunning (Sword)", ItemType.sword, swordSkill);
    } else {
      // Desperation: Hand fishing uses adaptability
      return _FishingTechnique(
          "Hand Fishing", ItemType.misc, (soldier.adaptability / 2).toDouble());
    }
  }

  bool _attemptCatch(Soldier soldier, Fish fish, _FishingTechnique technique) {
    // Base catch chance
    double baseCatchChance = 0.50;

    // Skill modifier (major factor)
    baseCatchChance += (technique.skillLevel - 5) * 0.05;

    // Technique Suitability Modifier
    // If the technique matches what the fish is vulnerable to, big bonus.
    if (fish.relevantSkillItem == technique.toolType) {
      baseCatchChance += 0.25;
    } else if (technique.toolType == ItemType.misc) {
      // Hand fishing is wildly inefficient
      baseCatchChance -= 0.30;
    }

    // Rarity modifier (rarer fish are harder to catch/spook easier)
    // rarityWeight 50 (Common) -> neutral
    // rarityWeight 5 (Very Rare) -> -0.20 approx
    baseCatchChance -= (50 - fish.rarityWeight) * 0.005;

    // Clamp and roll
    baseCatchChance = baseCatchChance.clamp(0.05, 0.95);
    return _random.nextDouble() < baseCatchChance;
  }
}

// Internal helper class
class _FishingTechnique {
  final String name;
  final ItemType toolType;
  final double skillLevel;
  _FishingTechnique(this.name, this.toolType, this.skillLevel);
}
