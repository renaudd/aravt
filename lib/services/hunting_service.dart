import 'dart:math';
import 'package:aravt/models/animal_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/hunting_report.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/combat_service.dart'; // For TerrainType
import 'package:aravt/models/combat_models.dart';
// [GEMINI-NEW] Import for PerformanceEvent
import 'package:aravt/models/interaction_models.dart';

class HuntingService {
  final Random _random = Random();

  /// Main entry point to resolve a day of hunting for an Aravt.
  Future<HuntingTripReport> resolveHuntingTrip({
    required Aravt aravt,
    required TerrainType terrain,
    required String locationName,
    required GameDate date,
    required GameState gameState,
  }) async {
    final List<IndividualHuntResult> individualResults = [];
    final List<Animal> localAnimals =
        AnimalDatabase.getAnimalsForTerrain(terrain);

    // Fallback if a terrain has no animals defined yet
    if (localAnimals.isEmpty) {
      return HuntingTripReport(
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
        final result = _resolveSoldierHunt(soldier, localAnimals, gameState);
        individualResults.add(result);

        // [GEMINI-NEW] Log Performance based on results
        if (result.totalMeat > 50.0 || result.kills.length >= 3) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Exceptional hunt, brought back a feast.",
              isPositive: true,
              magnitude: 2.0));
        } else if (result.totalMeat > 0) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Successful hunt.",
              isPositive: true,
              magnitude: 1.0));
        } else {
          // Coming back empty-handed is a failure
          soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Failed to catch anything while hunting.",
            isPositive: false,
          ));
        }
      }
    }

    // Filter out soldiers who caught nothing
    final filteredResults =
        individualResults.where((result) => result.totalMeat > 0).toList();

    return HuntingTripReport(
      date: date.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      locationName: locationName,
      individualResults: filteredResults,
    );
  }

  IndividualHuntResult _resolveSoldierHunt(
      Soldier soldier, List<Animal> localAnimals, GameState gameState) {
    final List<HuntedAnimal> kills = [];
    bool wasInjured = false; // Placeholder for future "boar gores you" logic

    // 1. Determine how many animals are spotted (0 to 3)
    // Based on Perception, Patience, Experience, Knowledge
    double spotScore = (soldier.perception * 2.0) +
        soldier.patience +
        (soldier.experience / 10.0) +
        soldier.knowledge +
        (_random.nextInt(20) - 10); // Variance

    int spottedCount = 0;
    if (spotScore > 35)
      spottedCount = 3;
    else if (spotScore > 25)
      spottedCount = 2;
    else if (spotScore > 15) spottedCount = 1;

    for (int i = 0; i < spottedCount; i++) {
      // 2. Identify Animal (weighted random based on rarity)
      final Animal animal = _spotAnimal(localAnimals);

      // 3. Choose Weapon
      final Weapon? chosenWeapon = _chooseHuntingWeapon(soldier, animal);

      if (chosenWeapon != null) {
        // 4. Take the shot!
        if (_attemptKill(soldier, animal, chosenWeapon)) {
          // Success! Calculate yield.
          double meat = animal.minMeat +
              _random.nextDouble() * (animal.maxMeat - animal.minMeat);

          kills.add(HuntedAnimal(
            animalId: animal.id,
            animalName: animal.name,
            meatType: animal.meatType,
            meatYield: double.parse(meat.toStringAsFixed(1)),
            peltYield: animal.peltCount,
            weaponUsed: chosenWeapon.name,
          ));

          // [GEMINI-NEW] Add Pelts to Communal Stash
          for (int p = 0; p < animal.peltCount; p++) {
            gameState.addItemToCommunalStash(InventoryItem(
              id: 'pelt_${animal.id}_${DateTime.now().microsecondsSinceEpoch}_$p',
              templateId: 'resource_pelt_${animal.id}',
              name: '${animal.name} Pelt',
              description: 'A valuable pelt from a ${animal.name}.',
              itemType: ItemType.misc,
              valueType: ValueType.Treasure,
              baseValue: (20.0 - animal.rarityWeight / 5.0)
                  .clamp(1.0, 50.0), // Rarer = more valuable
              weight: 1.0,
              // Placeholder icon until we have specific pelt icons
              iconAssetPath: 'assets/images/items/consumables_items.png',
            ));
          }
        }
      }
    }

    return IndividualHuntResult(
      soldierId: soldier.id,
      soldierName: soldier.name,
      kills: kills,
      wasInjured: wasInjured,
    );
  }

  Animal _spotAnimal(List<Animal> possibleAnimals) {
    int totalWeight = possibleAnimals.fold(0, (sum, a) => sum + a.rarityWeight);
    int roll = _random.nextInt(totalWeight);
    int currentWeight = 0;
    for (final animal in possibleAnimals) {
      currentWeight += animal.rarityWeight;
      if (roll < currentWeight) return animal;
    }
    return possibleAnimals.last;
  }

  Weapon? _chooseHuntingWeapon(Soldier soldier, Animal target) {
    // Get all valid weapons the soldier actually HAS
    List<Weapon> availableWeapons = [];
    for (final item in soldier.equippedItems.values) {
      if (item is Weapon && target.validWeapons.contains(item.itemType)) {
        // Ensure they have ammo if it's a bow
        if (item.itemType == ItemType.bow) {
          // Simplified: assume they always have some arrows for hunting for now,
          // or check a hypothetical 'quiver' item.
          // For this stage of dev, let's assume they can scrounge a few hunting arrows.
          availableWeapons.add(item);
        } else {
          availableWeapons.add(item);
        }
      }
    }

    if (availableWeapons.isEmpty) return null;

    // A) Preferred gift type check
    try {
      final preferred = availableWeapons.firstWhere(
        (w) =>
            w.itemType.name.toLowerCase() ==
            soldier.giftTypePreference.name.toLowerCase(),
      );
      return preferred;
    } catch (e) {
      // No preferred weapon available, continue to B
    }

    // B) 50% Best Skill, 50% Random
    if (_random.nextBool()) {
      // Use best skill
      availableWeapons.sort((a, b) => _getSkillForWeapon(soldier, b.itemType)
          .compareTo(_getSkillForWeapon(soldier, a.itemType)));
      return availableWeapons.first;
    } else {
      // Random
      return availableWeapons[_random.nextInt(availableWeapons.length)];
    }
  }

  int _getSkillForWeapon(Soldier soldier, ItemType type) {
    switch (type) {
      case ItemType.bow:
        return soldier
            .longRangeArcherySkill; // Hunting is usually on foot/steady
      case ItemType.spear:
        return soldier.spearSkill;
      case ItemType.sword:
        return soldier.swordSkill;
      default:
        return 0;
    }
  }

  bool _attemptKill(Soldier soldier, Animal animal, Weapon weapon) {
    // Base hit chance similar to combat, but simplified for hunting (static target initially)
    double baseHitChance = 0.60;

    // Skill modifier
    int skill = _getSkillForWeapon(soldier, weapon.itemType);
    baseHitChance += (skill - 5) * 0.05;

    // Attribute modifiers
    baseHitChance += (soldier.patience - 5) * 0.02;
    baseHitChance += (soldier.perception - 5) * 0.02;

    // Animal size modifier
    if (animal.size == AnimalSize.small || animal.size == AnimalSize.bird) {
      baseHitChance -= 0.20; // Harder to hit small things
    } else if (animal.size == AnimalSize.large) {
      baseHitChance += 0.10; // Easier to hit big things
    }

    // Clamp and roll
    baseHitChance = baseHitChance.clamp(0.10, 0.95);
    if (_random.nextDouble() > baseHitChance) {
      return false; // Missed completely
    }

    // Hit! Now determine if it was a killing blow.
    // Large animals need a better "hit" (simulating moderate+ injury)
    if (animal.size == AnimalSize.large) {
      // Need a "good" hit. For simplicity: 50/50 chance it was just a flesh wound on a large animal
      // unless skill is very high.
      if (skill < 7 && _random.nextDouble() < 0.5) return false;
    }

    return true;
  }
}
