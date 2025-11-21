import 'dart:math';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/resource_report.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';

class ResourceService {
  final Random _random = Random();

  // --- MINING ---
  Future<ResourceReport> resolveMiningDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
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
    );
  }

  // --- WOODCUTTING ---
  Future<ResourceReport> resolveWoodcuttingDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
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
    );
  }

  // --- SCAVENGING (Example for future use) ---
  Future<ResourceReport> resolveScavengingDetailed({
    required Aravt aravt,
    required PointOfInterest poi,
    required GameState gameState,
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

        // 3. Apply richness modifier
        individualYield *= resourceRichness;

        // 4. Record individual result
        individualResults.add(IndividualResourceResult(
          soldierId: soldier.id,
          soldierName: soldier.name,
          amountGathered: individualYield,
          performanceRating: performanceRating,
        ));

        // [GEMINI-NEW] Log Performance & Justification
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
      }
    }

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
      );
    }

    return ResourceReport(
      date: gameState.gameDate,
      aravtId: aravt.id,
      aravtName: aravt.id,
      locationName: poi.name,
      type: resourceType,
      totalGathered: totalGathered,
      individualResults: individualResults,
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
