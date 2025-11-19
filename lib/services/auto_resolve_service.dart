// services/auto_resolve_service.dart


import 'dart:math';


import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';


/// This service probabilistically resolves a combat encounter
/// without running the full turn-by-turn simulation.
/// Used for NPC vs. NPC battles.
class AutoResolveService {
  final Random _random = Random();


  /// Resolves a combat and returns a generated CombatReport.
  CombatReport resolveCombat({
    required GameState gameState,
    required List<Aravt> attackerAravts,
    required List<Soldier> allAttackerSoldiers,
    required List<Aravt> defenderAravts,
    required List<Soldier> allDefenderSoldiers,
  }) {
    print("Auto-Resolving Combat...");


    // 1. Get the full list of participants
    final List<Soldier> attackers =
        _getSoldiersFromAravts(attackerAravts, allAttackerSoldiers);
    final List<Soldier> defenders =
        _getSoldiersFromAravts(defenderAravts, allDefenderSoldiers);


    // 2. Calculate combat strength for each side
    double attackerStrength = _calculateCombatStrength(attackers);
    double defenderStrength = _calculateCombatStrength(defenders);


    // 3. Determine Winner
    attackerStrength *= (0.8 + _random.nextDouble() * 0.4); // 80% - 120%
    defenderStrength *= (0.8 + _random.nextDouble() * 0.4); // 80% - 120%


    bool attackerWon = attackerStrength > defenderStrength;
    CombatResult result =
        attackerWon ? CombatResult.playerVictory : CombatResult.playerDefeat;


    // 4. Calculate casualty *counts*
    int attackerKilledCount = 0;
    int attackerWoundedCount = 0;
    int defenderKilledCount = 0;
    int defenderWoundedCount = 0;
    List<Soldier> captives = [];


    if (attackerWon) {
      // Attacker wins, defenders suffer more
      defenderKilledCount =
          (defenders.length * (_random.nextDouble() * 0.3 + 0.1))
              .round(); // 10-40% killed
      defenderWoundedCount =
          (defenders.length * (_random.nextDouble() * 0.4 + 0.2))
              .round(); // 20-60% wounded
      attackerKilledCount =
          (attackers.length * (_random.nextDouble() * 0.1)).round(); // 0-10% killed
      attackerWoundedCount =
          (attackers.length * (_random.nextDouble() * 0.2 + 0.1))
              .round(); // 10-30% wounded
    } else {
      // Defender wins, attackers suffer more
      attackerKilledCount =
          (attackers.length * (_random.nextDouble() * 0.3 + 0.1))
              .round(); // 10-40% killed
      attackerWoundedCount =
          (attackers.length * (_random.nextDouble() * 0.4 + 0.2))
              .round(); // 20-60% wounded
      defenderKilledCount =
          (defenders.length * (_random.nextDouble() * 0.1)).round(); // 0-10% killed
      defenderWoundedCount =
          (defenders.length * (_random.nextDouble() * 0.2 + 0.1))
              .round(); // 10-30% wounded
    }
    
    // Clamp counts to not exceed total soldiers
    attackerKilledCount = attackerKilledCount.clamp(0, attackers.length);
    attackerWoundedCount = (attackerWoundedCount).clamp(0, attackers.length - attackerKilledCount);
    defenderKilledCount = defenderKilledCount.clamp(0, defenders.length);
    defenderWoundedCount = (defenderWoundedCount).clamp(0, defenders.length - defenderKilledCount);


    // 5. Apply status and create casualty lists
    // Shuffle lists to randomize who is a casualty
    attackers.shuffle(_random);
    defenders.shuffle(_random);


    final List<Soldier> attackerCasualtiesKilled = [];
    final List<Soldier> attackerCasualtiesWounded = [];
    final List<Soldier> defenderCasualtiesKilled = [];
    final List<Soldier> defenderCasualtiesWounded = [];
    final List<Soldier> livingAttackers = [];
    final List<Soldier> livingDefenders = [];


    // Process Attackers
    for (int i = 0; i < attackers.length; i++) {
      final s = attackers[i];
      if (i < attackerKilledCount) {
        s.status = SoldierStatus.killed;
        attackerCasualtiesKilled.add(s);
      } else if (i < attackerKilledCount + attackerWoundedCount) {
        s.status = SoldierStatus.wounded;
        attackerCasualtiesWounded.add(s);
        livingAttackers.add(s); // Wounded soldiers are "living"
      } else {
        s.status = SoldierStatus.alive;
        livingAttackers.add(s);
      }
    }


    // Process Defenders
    for (int i = 0; i < defenders.length; i++) {
      final s = defenders[i];
      if (i < defenderKilledCount) {
        s.status = SoldierStatus.killed;
        defenderCasualtiesKilled.add(s);
      } else if (i < defenderKilledCount + defenderWoundedCount) {
        s.status = SoldierStatus.wounded;
        defenderCasualtiesWounded.add(s);
        if (attackerWon) {
          captives.add(s); // Add wounded defenders as captives
        } else {
          livingDefenders.add(s); // Wounded but not captured
        }
      } else {
        s.status = SoldierStatus.alive;
        livingDefenders.add(s);
      }
    }


    // 6. Probabilistically assign casualties to victors
    final List<Soldier> allAttackerCasualties = [
      ...attackerCasualtiesKilled,
      ...attackerCasualtiesWounded
    ];
    final List<Soldier> allDefenderCasualties = [
      ...defenderCasualtiesKilled,
      ...defenderCasualtiesWounded
    ];


    final Map<int, List<Soldier>> attackerDefeatMap = _assignCasualties(
        livingAttackers, allDefenderCasualties);
    final Map<int, List<Soldier>> defenderDefeatMap = _assignCasualties(
        livingDefenders, allAttackerCasualties);


    // 7. Generate simplified report summaries
    List<CombatReportSoldierSummary> attackerSummaries = attackers.map((s) {
      return CombatReportSoldierSummary(
        originalSoldier: s,
        finalStatus: s.status, // Use the status we just set
        injuriesSustained: [], // TODO: Add actual Injury
        defeatedSoldiers: attackerDefeatMap[s.id] ?? [], // <-- NEW
        wasUnconscious: s.status == SoldierStatus.wounded,
      );
    }).toList();


    List<CombatReportSoldierSummary> defenderSummaries = defenders.map((s) {
      return CombatReportSoldierSummary(
        originalSoldier: s,
        finalStatus: s.status, // Use the status we just set
        injuriesSustained: [], // TODO: Add actual Injury
        defeatedSoldiers: defenderDefeatMap[s.id] ?? [], // <-- NEW
        wasUnconscious: s.status == SoldierStatus.wounded,
      );
    }).toList();


    // 8. Generate Loot Report
    // This is now handled by the new LootDistributionService
    // We create an empty report here, as the loot service will
    // modify soldier inventories directly.
    LootReport lootObtained = LootReport.empty();
    LootReport lootLost = LootReport.empty();


    // 9. Create the final report
    final CombatReport report = CombatReport(
      id: 'auto-report-${_random.nextInt(99999)}',
      date: gameState.gameDate,
      result: result,
      playerSoldiers: attackerSummaries,
      enemySoldiers: defenderSummaries,
      lootObtained: lootObtained,
      lootLost: lootLost,
      captives: captives,
    );


    // 10. Add report to game log
    gameState.addCombatReport(report);
    gameState.logEvent(
      "A battle was automatically resolved. ${attackerWon ? 'Attackers' : 'Defenders'} were victorious.",
      isPlayerKnown: false,
      category: EventCategory.combat,
      severity: EventSeverity.high,
    );


    return report;
  }


  /// Probabilistically assigns a list of casualties to a list of victors.
  Map<int, List<Soldier>> _assignCasualties(
      List<Soldier> victors, List<Soldier> casualties) {
    final Map<int, List<Soldier>> defeatMap = {};
    if (victors.isEmpty || casualties.isEmpty) {
      return defeatMap;
    }


    // Calculate total strength of the victors
    double totalVictorStrength = 0;
    final Map<int, double> victorStrengths = {};
    for (final victor in victors) {
      final strength = _calculateCombatStrength([victor]);
      victorStrengths[victor.id] = strength;
      totalVictorStrength += strength;
    }


    if (totalVictorStrength == 0) {
      // Fallback: assign randomly if total strength is zero
      for (final casualty in casualties) {
        final randomVictor = victors[_random.nextInt(victors.length)];
        if (!defeatMap.containsKey(randomVictor.id)) {
          defeatMap[randomVictor.id] = [];
        }
        defeatMap[randomVictor.id]!.add(casualty);
      }
      return defeatMap;
    }


    // Assign each casualty based on weighted probability
    for (final casualty in casualties) {
      double roll = _random.nextDouble() * totalVictorStrength;
      double cumulativeStrength = 0;


      for (final victor in victors) {
        cumulativeStrength += victorStrengths[victor.id]!;
        if (roll <= cumulativeStrength) {
          if (!defeatMap.containsKey(victor.id)) {
            defeatMap[victor.id] = [];
          }
          defeatMap[victor.id]!.add(casualty);
          break; // Casualty assigned
        }
      }
    }
    return defeatMap;
  }


  /// Calculates the total combat strength of a list of soldiers.
  double _calculateCombatStrength(List<Soldier> soldiers) {
    if (soldiers.isEmpty) return 0;


    double totalStrength = 0;
    for (final soldier in soldiers) {
      // Base strength from stats
      double soldierStrength = (soldier.strength +
              soldier.longRangeArcherySkill +
              soldier.mountedArcherySkill +
              soldier.spearSkill +
              soldier.swordSkill +
              soldier.shieldSkill +
              soldier.courage +
              soldier.experience) /
          8.0;


      // Bonus/Penalty for health and exhaustion
      double healthModifier =
          (soldier.bodyHealthCurrent / soldier.bodyHealthMax);
      double exhaustionModifier =
          1.0 - (soldier.exhaustion / 10.0 * 0.5); // 50% penalty at max exhaustion


      // TODO: Add equipment bonus
      // double equipmentBonus = _calculateEquipmentBonus(soldier.equippedItems);
      // soldierStrength += equipmentBonus;


      totalStrength +=
          (soldierStrength * healthModifier * exhaustionModifier).clamp(0.1, double.maxFinite); // Ensure non-zero strength
    }
    return totalStrength;
  }


  /// Helper to get all soldiers from a list of aravts.
  List<Soldier> _getSoldiersFromAravts(
      List<Aravt> aravts, List<Soldier> horde) {
    List<Soldier> soldiers = [];
    for (final aravt in aravts) {
      for (final soldierId in aravt.soldierIds) {
        try {
          // Find the soldier *instance* from the main horde list
          soldiers.add(horde.firstWhere((s) => s.id == soldierId));
        } catch (e) {
          print("Warning: Soldier $soldierId in aravt ${aravt.id} not found in horde.");
        }
      }
    }
    // Return only soldiers who are not already killed, captured, etc.
    return soldiers.where((s) => s.status == SoldierStatus.alive && !s.isImprisoned).toList();
  }
}


