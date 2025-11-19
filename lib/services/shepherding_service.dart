import 'dart:math';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/herd_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/combat_models.dart'; // For SoldierStatus


class ShepherdingService {
 final Random _random = Random();


 /// Main entry point for a day of shepherding.
 Future<void> resolveShepherding({
   required Aravt aravt,
   required Herd herd,
   required GameState gameState,
 }) async {
   // 1. Identify Shepherds
   List<Soldier> shepherds = [];
   for (var id in aravt.soldierIds) {
     final s = gameState.findSoldierById(id);
     if (s != null &&
         s.status == SoldierStatus.alive &&
         !s.isImprisoned) {
       shepherds.add(s);
     }
   }


   if (shepherds.isEmpty) return;


   // 2. Wolf Attack Check (5% chance)
   bool hadWolfAttack = false;
   if (_random.nextDouble() < 0.05) {
     hadWolfAttack = true;
     await _resolveWolfAttack(aravt, shepherds, herd, gameState);
   }


   // 3. Regular Grazing Resolution
   // Only continue if there are still live shepherds after the potential attack
   bool canStillGraze = shepherds.any(
       (s) => s.status == SoldierStatus.alive && !s.isImprisoned);


   if (canStillGraze) {
     _resolveGrazing(shepherds, herd, gameState, wasAttacked: hadWolfAttack);
   }
 }


 Future<void> _resolveWolfAttack(Aravt aravt, List<Soldier> shepherds,
     Herd herd, GameState gameState) async {
   int wolfCount = _random.nextInt(6) + 3; // 3 to 8 wolves
   gameState.logEvent(
     "A pack of $wolfCount wolves attacks the herd!",
     category: EventCategory.combat,
     severity: EventSeverity.high,
     aravtId: aravt.id,
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


     gameState.logEvent(
       "Your shepherds drove off the wolves, killing $wolvesKilled. Gained ${meat.toStringAsFixed(1)} kg of wolf meat.",
       category: EventCategory.combat,
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
                magnitude: 1.5
            ));
         }
     }


     // Even in victory, might take minor injuries
     _applyMinorDamage(shepherds, gameState, chance: 0.3);


   } else {
     // DEFEAT - Wolves get some cattle
     int cattleLost = min(herd.totalPopulation, wolfCount);
     herd.removeRandomAnimals(cattleLost);


     gameState.logEvent(
       "The wolves overwhelmed your shepherds! $cattleLost cattle were lost.",
       category: EventCategory.combat,
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
                magnitude: 2.0
            ));
         }
     }


     // Higher chance of injury in defeat
     _applyMinorDamage(shepherds, gameState, chance: 0.7, severityMultiplier: 2.0);
   }
 }


 void _resolveGrazing(List<Soldier> shepherds, Herd herd, GameState gameState,
     {bool wasAttacked = false}) {
  
   double totalSkill = 0;
   for (var s in shepherds) {
     // Animal Handling is primary, Patience/Judgment secondary
     totalSkill += (s.animalHandling * 2.0) +
         s.patience +
         s.judgment +
         (s.stamina * 0.5);
   }
  
   // Base difficulty scales with herd size.
   // 20 cattle = difficulty ~15. 100 cattle = difficulty ~75.
   double difficulty = herd.totalPopulation / 20.0 * 15.0;
   if (wasAttacked) {
       difficulty *= 1.5; // Harder to calm herd after attack
   }
   if (difficulty < 5.0) difficulty = 5.0; // Minimum difficulty


   double successRatio = totalSkill / difficulty;
   // Add variance: +/- 20%
   successRatio *= (0.8 + _random.nextDouble() * 0.4);


   int currentTurn = gameState.turn.turnNumber;


   if (successRatio > 1.5) {
     // EXTRA SUCCESSFUL
     herd.lastGrazedTurn = currentTurn;
    
     // Small milk bonus if cattle/goats/sheep
     if (herd.type != AnimalType.Horse) {
         double milk = herd.adultFemales * 0.5 * _random.nextDouble(); // very rough abstract milk yield
          // TODO: Add milk to game state if we track it separately, or just generic food
          // For now, just log it as a 'nice to have' but don't track liquid.
          herd.dailyMilkProduction += milk;
     }


      gameState.logEvent(
       "The herd is well-grazed and content.",
       category: EventCategory.general,
       severity: EventSeverity.low,
     );


     for (var s in shepherds) {
        s.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Excellent job tending the herd.",
            isPositive: true,
            magnitude: 1.0
        ));
     }


   } else if (successRatio > 0.8) {
     // STANDARD SUCCESS
     herd.lastGrazedTurn = currentTurn;
     // No special performance log for standard work
   } else {
     // FAILURE
     if (_random.nextDouble() < 0.2 && herd.totalPopulation > 0) {
        // CRITICAL FAILURE (Lost animal due to incompetence)
        herd.removeRandomAnimals(1);
        gameState.logEvent(
         "An animal wandered off while grazing and was lost.",
         category: EventCategory.general,
         severity: EventSeverity.high,
        );


        for (var s in shepherds) {
            s.performanceLog.add(PerformanceEvent(
                turnNumber: currentTurn,
                description: "Lost an animal while grazing.",
                isPositive: false,
                magnitude: 2.0 // High scold justification
            ));
        }
     } else {
          gameState.logEvent(
           "The herd did not find enough good pasture today.",
           category: EventCategory.general,
           severity: EventSeverity.normal,
          );
          // Don't update lastGrazedTurn, so they are still "hungry" tomorrow
         
          for (var s in shepherds) {
            s.performanceLog.add(PerformanceEvent(
                turnNumber: currentTurn,
                description: "Poor grazing results.",
                isPositive: false,
                magnitude: 0.5
            ));
        }
     }
   }
  
   // Apply fatigue
    for (var s in shepherds) {
       s.exhaustion = (s.exhaustion + 1.0).clamp(0, 10);
       s.stress = (s.stress - 0.1).clamp(0, 10); // Time with animals can be de-stressing
   }
 }


 void _applyMinorDamage(List<Soldier> soldiers, GameState gameState,
     {double chance = 0.5, double severityMultiplier = 1.0}) {
   for (var s in soldiers) {
     if (s.status != SoldierStatus.alive) continue;
    
     if (_random.nextDouble() < chance) {
       int damage = (1 + _random.nextInt(3) * severityMultiplier).round();
       s.bodyHealthCurrent = max(0, s.bodyHealthCurrent - damage);
      
       if (s.bodyHealthCurrent <= 0) {
            s.status = SoldierStatus.killed;
            gameState.logEvent("${s.name} died from wounds during the wolf attack.",
               category: EventCategory.health,
               severity: EventSeverity.critical,
               soldierId: s.id
            );
       } else {
            // Log the injury so it shows up in reports
             gameState.logEvent("${s.name} was wounded by wolves.",
               category: EventCategory.health,
               severity: EventSeverity.normal,
               soldierId: s.id
            );
       }
     }
   }
 }
}

