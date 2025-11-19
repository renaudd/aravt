import 'dart:math';
import 'package:aravt/models/fish_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/fishing_report.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/combat_service.dart';
// [GEMINI-NEW] Needed for PerformanceEvent
import 'package:aravt/models/interaction_models.dart';

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
        final result = _resolveSoldierFishing(soldier, localFish, gameState);
        individualResults.add(result);

        // [GEMINI-NEW] Log Performance based on results
        if (result.totalMeat > 10.0 || result.catches.length >= 4) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Caught a huge amount of fish.",
              isPositive: true,
              magnitude: 2.0));
        } else if (result.totalMeat > 0) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Successful fishing trip.",
              isPositive: true,
              magnitude: 1.0));
        } else {
          soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Caught nothing while fishing.",
            isPositive: false,
          ));
        }
      }
    }

    return FishingTripReport(
      date: date.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      locationName: locationName,
      individualResults: individualResults,
    );
  }

  IndividualFishingResult _resolveSoldierFishing(
      Soldier soldier, List<Fish> localFish, GameState gameState) {
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
    if (opportunityScore > 40)
      opportunities = 4;
    else if (opportunityScore > 30)
      opportunities = 3;
    else if (opportunityScore > 20)
      opportunities = 2;
    else if (opportunityScore > 10) opportunities = 1;

    for (int i = 0; i < opportunities; i++) {
      // 3. Identify Fish (weighted random based on rarity)
      final Fish fish = _spotFish(localFish);

      // 4. Attempt Catch
      if (_attemptCatch(soldier, fish, technique)) {
        // Success! Calculate yield.
        double meat =
            fish.minMeat + _random.nextDouble() * (fish.maxMeat - fish.minMeat);

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
    int shieldSkill = soldier.equippedItems.containsKey(EquipmentSlot.shield)
        ? soldier.shieldSkill
        : -1;
    int spearSkill = soldier.equippedItems.containsKey(EquipmentSlot.spear)
        ? soldier.spearSkill
        : -1;
    int swordSkill = soldier.equippedItems.containsKey(EquipmentSlot.melee) &&
            (soldier.equippedItems[EquipmentSlot.melee]?.itemType ==
                ItemType.sword)
        ? soldier.swordSkill
        : -1;

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
          "Hand Fishing", ItemType.misc, (soldier.adaptability / 2).round());
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
  final int skillLevel;
  _FishingTechnique(this.name, this.toolType, this.skillLevel);
}
