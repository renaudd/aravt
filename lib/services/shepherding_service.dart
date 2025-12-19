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
import 'package:aravt/models/herd_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';
// For SoldierStatus
import 'package:aravt/models/shepherding_report.dart';

class ShepherdingService {
  final Random _random = Random();

  /// Main entry point for a day of shepherding.
  Future<ShepherdingReport> resolveShepherding({
    required Aravt aravt,
    required Herd herd,
    required GameState gameState,
  }) async {
    // 1. Identify Shepherds
    List<Soldier> shepherds = [];
    for (var id in aravt.soldierIds) {
      final s = gameState.findSoldierById(id);
      if (s != null && s.status == SoldierStatus.alive && !s.isImprisoned) {
        shepherds.add(s);
      }
    }

    List<String> events = [];
    List<IndividualShepherdingResult> individualResults = [];
    double milkProduced = 0;

    if (shepherds.isEmpty) {
      return ShepherdingReport(
        date: gameState.gameDate.copy(),
        aravtId: aravt.id,
        aravtName: aravt.id,
        totalAnimals: herd.totalPopulation,
        milkProduced: 0,
        events: ["No shepherds available."],
        individualResults: [],
        turn: gameState.turn.turnNumber,
      );
    }

    // New: Capacity & Exclusivity
    int animalsToShepherd =
        min(50, herd.totalPopulation - herd.dailyAnimalsShepherded);
    if (animalsToShepherd <= 0) {
      return ShepherdingReport(
        date: gameState.gameDate.copy(),
        aravtId: aravt.id,
        aravtName: aravt.id,
        totalAnimals: herd.totalPopulation,
        milkProduced: 0,
        events: ["All animals already shepherded today."],
        individualResults: [],
        turn: gameState.turn.turnNumber,
      );
    }

    // 2. Wolf Attack Check (10% chance for demo/testing)
    bool hadWolfAttack = false;
    if (_random.nextDouble() < 0.10) {
      hadWolfAttack = true;
      await _resolveWolfAttack(
          aravt, shepherds, herd, gameState, events, individualResults);
    }

    // 3. Regular Grazing Resolution
    // Only continue if there are still live shepherds after the potential attack
    bool canStillGraze = shepherds
        .any((s) => s.status == SoldierStatus.alive && !s.isImprisoned);

    if (canStillGraze) {
      milkProduced = _resolveGrazing(
          aravt, shepherds, herd, gameState, events, individualResults,
          animalsToShepherd: animalsToShepherd, wasAttacked: hadWolfAttack);
    }

    // Sort individualResults so Captain is first
    individualResults.sort((a, b) {
      final soldierA = gameState.findSoldierById(a.soldierId);
      final soldierB = gameState.findSoldierById(b.soldierId);
      if (soldierA?.role == SoldierRole.aravtCaptain) return -1;
      if (soldierB?.role == SoldierRole.aravtCaptain) return 1;
      return 0;
    });

    return ShepherdingReport(
      date: gameState.gameDate.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      totalAnimals: herd.totalPopulation,
      milkProduced: milkProduced,
      events: events,
      individualResults: individualResults,
      turn: gameState.turn.turnNumber,
    );
  }

  Future<void> _resolveWolfAttack(
      Aravt aravt,
      List<Soldier> shepherds,
      Herd herd,
      GameState gameState,
      List<String> events,
      List<IndividualShepherdingResult> individualResults) async {
    int wolfCount = _random.nextInt(6) + 3; // 3 to 8 wolves
    String attackMsg = "A pack of $wolfCount wolves attacks the herd!";
    events.add(attackMsg);
    gameState.logEvent(
      attackMsg,
      category: EventCategory.general,
      severity: EventSeverity.high,
      aravtId: aravt.id,
      isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
    );

    double aravtPower = 0;
    for (var s in shepherds) {
      // Simple combat power approximation for this auto-resolution
      aravtPower += (s.spearSkill * 1.5) +
          s.swordSkill +
          (s.longRangeArcherySkill * 0.8) +
          (s.strength * 0.5);
    }

    // Wolves are dangerous
    double wolfPackPower = (wolfCount * 15.0) + _random.nextInt(50);

    int currentTurn = gameState.turn.turnNumber;

    if (aravtPower >= wolfPackPower * 0.8) {
      // VICTORY (even a close one counts as driving them off)
      int wolvesKilled = (_random.nextDouble() * wolfCount).ceil();
      double meat = wolvesKilled * (20.0 + _random.nextInt(11));
      gameState.addCommunalMeat(meat);

      String victoryMsg =
          "Drove off wolves, killed $wolvesKilled. Gained ${meat.toStringAsFixed(1)} kg meat.";
      events.add(victoryMsg);
      gameState.logEvent(
        victoryMsg,
        category: EventCategory.general,
        severity: EventSeverity.normal,
        aravtId: aravt.id,
      );

      // Log POSITIVE performance
      for (var s in shepherds) {
        if (s.status == SoldierStatus.alive) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Helped drive off a wolf pack.",
              isPositive: true,
              magnitude: 1.5));
          s.pendingJustifications.add(JustificationEvent(
            description: "Fought off wolves",
            type: JustificationType.praise,
            expiryTurn: currentTurn + 2,
            magnitude: 1.0,
          ));
          individualResults.add(IndividualShepherdingResult(
            soldierId: s.id,
            soldierName: s.name,
            performanceRating: 1.0,
            eventDescription: "Fought off wolves",
          ));
        }
      }

      // Even in victory, might take minor injuries
      _applyMinorDamage(aravt, shepherds, gameState, events, chance: 0.3);
    } else {
      // DEFEAT - Wolves get some cattle
      int cattleLost = min(herd.totalPopulation, wolfCount);
      herd.removeRandomAnimals(cattleLost);

      String defeatMsg =
          "Wolves overwhelmed shepherds! $cattleLost cattle lost.";
      events.add(defeatMsg);
      gameState.logEvent(
        defeatMsg,
        category: EventCategory.general,
        severity: EventSeverity.critical,
        aravtId: aravt.id,
      );

      // Log NEGATIVE performance
      for (var s in shepherds) {
        if (s.status == SoldierStatus.alive) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Failed to defend the herd from wolves.",
              isPositive: false,
              magnitude: 2.0));
          s.pendingJustifications.add(JustificationEvent(
            description: "Failed to protect herd from wolves",
            type: JustificationType.scold,
            expiryTurn: currentTurn + 2,
            magnitude: 1.0,
          ));
          individualResults.add(IndividualShepherdingResult(
            soldierId: s.id,
            soldierName: s.name,
            performanceRating: 0.0,
            eventDescription: "Failed to protect herd",
          ));
        }
      }

      // Higher chance of injury in defeat
      _applyMinorDamage(aravt, shepherds, gameState, events,
          chance: 0.7, severityMultiplier: 2.0);
    }
  }

  double _resolveGrazing(
      Aravt aravt,
      List<Soldier> shepherds,
      Herd herd,
      GameState gameState,
      List<String> events,
      List<IndividualShepherdingResult> individualResults,
      {required int animalsToShepherd,
      bool wasAttacked = false}) {
    double totalSkill = 0;
    for (var s in shepherds) {
      // Animal Handling is primary, Patience/Judgment secondary
      totalSkill += (s.animalHandling * 2.0) +
          s.patience +
          s.judgment +
          (s.stamina * 0.5);
    }

    // Base difficulty scales with herd size.
    // 20 cattle = difficulty ~25 (increased from 15). 100 cattle = difficulty ~125.
    double difficulty = animalsToShepherd / 20.0 * 25.0;
    if (wasAttacked) {
      difficulty *= 1.5; // Harder to calm herd after attack
    }
    if (difficulty < 10.0) difficulty = 10.0; // Minimum difficulty

    double successRatio = totalSkill / difficulty;
    // Add variance: +/- 30% (increased from 20%)
    successRatio *= (0.7 + _random.nextDouble() * 0.6);

    int currentTurn = gameState.turn.turnNumber;
    double milkProduced = 0;

    if (successRatio > 1.5) {
      // EXTRA SUCCESSFUL
      herd.lastGrazedTurn = currentTurn;
      herd.dailyAnimalsShepherded += animalsToShepherd;

      // Small milk bonus if cattle/goats/sheep
      if (herd.type != AnimalType.Horse) {
        milkProduced = herd.adultFemales *
            0.5 *
            _random.nextDouble(); // very rough abstract milk yield
        // TODO: Add milk to game state if we track it separately, or just generic food
        // For now, just log it as a 'nice to have' but don't track liquid.
        herd.dailyMilkProduction += milkProduced;
      }

      String successMsg = "The herd is well-grazed and content.";
      events.add(successMsg);
      gameState.logEvent(
        successMsg,
        category: EventCategory.general,
        severity: EventSeverity.low,
        isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
      );

      for (var s in shepherds) {
        s.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Excellent job tending the herd.",
            isPositive: true,
            magnitude: 1.0));
        s.pendingJustifications.add(JustificationEvent(
          description: "Excellent shepherding",
          type: JustificationType.praise,
          expiryTurn: currentTurn + 2,
          magnitude: 0.5,
        ));
        individualResults.add(IndividualShepherdingResult(
          soldierId: s.id,
          soldierName: s.name,
          performanceRating: 1.0,
          eventDescription: "Excellent shepherding",
        ));
      }
    } else if (successRatio > 0.8) {
      // STANDARD SUCCESS
      herd.lastGrazedTurn = currentTurn;
      herd.dailyAnimalsShepherded += animalsToShepherd;
      // No special performance log for standard work
      for (var s in shepherds) {
        individualResults.add(IndividualShepherdingResult(
          soldierId: s.id,
          soldierName: s.name,
          performanceRating: 0.7,
          eventDescription: "Standard shepherding",
        ));
      }
    } else {
      // FAILURE
      if (_random.nextDouble() < 0.2 && herd.totalPopulation > 0) {
        // CRITICAL FAILURE (Lost animal due to incompetence)
        herd.removeRandomAnimals(1);
        String failureMsg =
            "An animal wandered off while grazing and was lost.";
        events.add(failureMsg);
        gameState.logEvent(
          failureMsg,
          category: EventCategory.general,
          severity: EventSeverity.high,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
        );

        for (var s in shepherds) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Lost an animal while grazing.",
              isPositive: false,
              magnitude: 2.0 // High scold justification
              ));
          s.pendingJustifications.add(JustificationEvent(
            description: "Lost an animal",
            type: JustificationType.scold,
            expiryTurn: currentTurn + 2,
            magnitude: 1.0,
          ));
          individualResults.add(IndividualShepherdingResult(
            soldierId: s.id,
            soldierName: s.name,
            performanceRating: 0.0,
            eventDescription: "Lost an animal",
          ));
        }
      } else {
        String poorMsg = "The herd did not find enough good pasture today.";
        events.add(poorMsg);
        gameState.logEvent(
          poorMsg,
          category: EventCategory.general,
          severity: EventSeverity.normal,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
        );
        // Don't update lastGrazedTurn, so they are still "hungry" tomorrow

        for (var s in shepherds) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Poor grazing results.",
              isPositive: false,
              magnitude: 0.5));
          s.pendingJustifications.add(JustificationEvent(
            description: "Poor grazing results",
            type: JustificationType.scold,
            expiryTurn: currentTurn + 2,
            magnitude: 0.3,
          ));
          individualResults.add(IndividualShepherdingResult(
            soldierId: s.id,
            soldierName: s.name,
            performanceRating: 0.3,
            eventDescription: "Poor grazing results",
          ));
        }
      }
    }

    // Apply fatigue
    for (var s in shepherds) {
      s.exhaustion = (s.exhaustion + 1.0).clamp(0, 5.0);
      s.stress = (s.stress - 0.1)
          .clamp(0, 5.0); // Time with animals can be de-stressing
    }
    return milkProduced;
  }

  void _applyMinorDamage(Aravt aravt, List<Soldier> soldiers,
      GameState gameState, List<String> events,
      {double chance = 0.5, double severityMultiplier = 1.0}) {
    for (var s in soldiers) {
      if (s.status != SoldierStatus.alive) continue;

      if (_random.nextDouble() < chance) {
        int damage = (1 + _random.nextInt(3) * severityMultiplier).round();
        s.bodyHealthCurrent = max(0, s.bodyHealthCurrent - damage);

        if (s.bodyHealthCurrent <= 0) {
          s.status = SoldierStatus.killed;
          String deathMsg =
              "${s.name} died from wounds during the wolf attack.";
          events.add(deathMsg);
          gameState.logEvent(
            deathMsg,
            category: EventCategory.health,
            severity: EventSeverity.critical,
            soldierId: s.id,
            isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
          );
        } else {
          // Log the injury so it shows up in reports
          String injuryMsg = "${s.name} was wounded by wolves.";
          events.add(injuryMsg);
          gameState.logEvent(
            injuryMsg,
            category: EventCategory.health,
            severity: EventSeverity.normal,
            soldierId: s.id,
            isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
          );
        }
      }
    }
  }
}
