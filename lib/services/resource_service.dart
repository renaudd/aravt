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
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';

import 'package:aravt/models/resource_report.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';
import 'package:aravt/models/game_date.dart';

class ResourceService {
  final Random _random = Random();

  // --- MINING ---
  Future<ResourceReport> resolveMiningDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
    GameDate? date,
  }) async {
    return await _resolveResourceGatheringDetailed(
      aravt: aravt,
      poi: poi,
      gameState: gameState,
      resourceType: ResourceType.ironOre,
      resourceName: "Iron Ore",
      baseYieldPerSoldier: 25.0,
      maxYieldPerSoldier: 50.0,
      skillEvaluator: (s) =>
          s.strength +
          s.stamina +
          s.knowledge +
          (s.intelligence * 0.5) +
          (s.adaptability * 0.5) +
          (s.swordSkill * 0.5), // Using sword as proxy for pickaxe
      date: date,
    );
  }

  // --- WOODCUTTING ---
  Future<ResourceReport> resolveWoodcuttingDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
    GameDate? date,
  }) async {
    return await _resolveResourceGatheringDetailed(
      aravt: aravt,
      poi: poi,
      gameState: gameState,
      resourceType: ResourceType.wood,
      resourceName: "Wood",
      baseYieldPerSoldier: 50.0,
      maxYieldPerSoldier: 90.0,
      skillEvaluator: (s) =>
          s.strength +
          s.stamina +
          // (s.axeSkill * 1.5) + // Future: Axe skill
          (s.strength * 0.5) +
          s.adaptability,
      date: date,
    );
  }

  // --- SCAVENGING (Example for future use) ---
  Future<ResourceReport> resolveScavengingDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
    GameDate? date,
  }) async {
    return await _resolveResourceGatheringDetailed(
      aravt: aravt,
      poi: poi,
      gameState: gameState,
      resourceType: ResourceType.scrap,
      resourceName: "Scrap",
      baseYieldPerSoldier: 10.0,
      maxYieldPerSoldier: 30.0,
      skillEvaluator: (s) =>
          s.intelligence * 1.5 + s.adaptability * 1.5 + s.knowledge,
      date: date,
    );
  }

  // --- CORE LOGIC ---
  Future<ResourceReport> _resolveResourceGatheringDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
    required ResourceType resourceType,
    required String resourceName,
    required double baseYieldPerSoldier,
    required double maxYieldPerSoldier,
    required double Function(Soldier) skillEvaluator,
    GameDate? date,
  }) async {
    double totalGathered = 0;
    List<IndividualResourceResult> individualResults = [];

    // Get current richness (defaults to 1.0 / 100%)
    double resourceRichness = gameState.getLocationResourceLevel(poi.id) ?? 1.0;

    // Hard depletion floor
    if (resourceRichness <= 0.05) resourceRichness = 0.05;

    for (var id in aravt.soldierIds) {
      final soldier = gameState.findSoldierById(id);
      if (soldier != null &&
          soldier.status == SoldierStatus.alive &&
          !soldier.isImprisoned) {
        // 1. Calculate Score
        double score = skillEvaluator(soldier) +
            (_random.nextInt(20) - 10) + // Variance (-10 to +10)
            (soldier.experience / 5.0);

        double individualYield = 0;
        double performanceRating = 0.5; // Default average

        // 2. Determine base yield based on score
        if (score > 35) {
          // Great success
          individualYield =
              maxYieldPerSoldier * (0.8 + _random.nextDouble() * 0.4);
          performanceRating = 1.0;
        } else if (score > 20) {
          // Standard success
          individualYield =
              baseYieldPerSoldier * (0.8 + _random.nextDouble() * 0.4);
          performanceRating = 0.7;
        } else {
          // Poor performance
          individualYield = (baseYieldPerSoldier * 0.4) * _random.nextDouble();
          performanceRating = 0.2;
        }

        // --- UNDERSTRENGTH PENALTY ---
        // Aravts with < 10 members work less efficiently.
        // Efficiency = (Members / 10). Clamped to 1.0 max (no bonus for >10).
        // However, we are iterating *per soldier*, so we shouldn't penalize per soldier *count* directly again?
        // The user said: "Aravts operate with a penalty when they have fewer than 10 members. The penalty is linear relative to the number of missing soldiers."
        // If an aravt has 5 members, they should be at 50% efficiency *per soldier*? Or just 50% total output?
        // "Penalty is linear... relative to missing soldiers."
        // If it was just "total output is less because fewer soldiers", that's natural.
        // The user implies an *additional* penalty.
        // So 5 soldiers = 50% efficiency factor on top of having 50% manpower.
        // Effectively 25% total output compared to a full 10-man squad.
        final int memberCount = aravt.soldierIds.length;
        final double understrengthFactor = (memberCount / 10.0).clamp(0.0, 1.0);
        individualYield *= understrengthFactor;

        // 3. Apply richness modifier
        individualYield *= resourceRichness;

        // 4. Record individual result
        individualResults.add(IndividualResourceResult(
          soldierId: soldier.id,
          soldierName: soldier.name,
          amountGathered: individualYield,
          performanceRating: performanceRating,
        ));

        //  Log Performance & Justification
        if (performanceRating >= 1.0) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: gameState.turn.turnNumber,
              description: "Exceptional $resourceName gathering.",
              isPositive: true,
              magnitude: 1.5));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Gathered huge amount of $resourceName",
              type: JustificationType.praise,
              expiryTurn: gameState.turn.turnNumber + 2,
              magnitude: 1.0));
        } else if (performanceRating <= 0.2) {
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: gameState.turn.turnNumber,
              description: "Poor $resourceName gathering.",
              isPositive: false,
              magnitude: 0.5));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Poor gathering performance",
              type: JustificationType.scold,
              expiryTurn: gameState.turn.turnNumber + 2,
              magnitude: 0.5));
        }

        totalGathered += individualYield;

        //  Mining byproduct: Scrap
        if (resourceType == ResourceType.ironOre &&
            _random.nextDouble() < 0.3) {
          // 30% chance per soldier to find some scrap metal/old tools
          double scrapFound = 1.0 + _random.nextInt(3);
          gameState.addCommunalScrap(scrapFound);
        }
      }
    }

    // Sort individualResults so Captain is first
    individualResults.sort((a, b) {
      final soldierA = gameState.findSoldierById(a.soldierId);
      final soldierB = gameState.findSoldierById(b.soldierId);
      if (soldierA?.role == SoldierRole.aravtCaptain) return -1;
      if (soldierB?.role == SoldierRole.aravtCaptain) return 1;
      return 0;
    });

    // 5. Update Location Depletion
    // Rate: 10,000 units gathered = 100% depletion of a node.
    double depletionAmount = totalGathered / 10000.0;
    double newRichness = (resourceRichness - depletionAmount).clamp(0.0, 1.0);
    gameState.updateLocationResourceLevel(poi.id, newRichness);

    if (resourceRichness < 0.2 && newRichness < 0.1) {
      gameState.logEvent(
        "The $resourceName at ${poi.name} is almost completely depleted.",
        category: EventCategory.general,
        severity: EventSeverity.high,
        isPlayerKnown: poi.isDiscovered,
      );
    }

    return ResourceReport(
      date: date ?? gameState.gameDate.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      locationName: poi.name,
      type: resourceType,
      totalGathered: totalGathered,
      individualResults: individualResults,
      turn: gameState.turn.turnNumber,
    );
  }

  // --- DEPRECATED LEGACY METHODS (kept briefly for compatibility if needed during transition, but should be removed eventually) ---
  // These just wrap the new detailed methods and discard the report,
  // mimicking the old fire-and-forget behavior if any old code still calls them.

  Future<void> resolveMining({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
  }) async {
    final report = await resolveMiningDetailed(
        aravt: aravt, poi: poi, gameState: gameState);
    gameState.addCommunalIronOre(report.totalGathered);
  }

  Future<void> resolveWoodcutting({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
  }) async {
    final report = await resolveWoodcuttingDetailed(
        aravt: aravt, poi: poi, gameState: gameState);
    gameState.addCommunalWood(report.totalGathered);
  }
}
