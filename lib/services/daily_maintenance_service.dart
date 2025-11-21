import 'dart:math';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/disease_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

class DailyMaintenanceService {
  final Random _random = Random();

  Future<void> resolveDailyMaintenance(GameState gameState) async {
    print("Step 10.5: Resolving daily maintenance (Cook, Equerry)...");

    for (final aravt in gameState.aravts) {
      final members = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      // --- COOK ROLE ---
      final cookId = aravt.dutyAssignments[AravtDuty.cook];
      if (cookId != null) {
        final cook = gameState.findSoldierById(cookId);
        if (cook != null && cook.status == SoldierStatus.alive) {
          // Calculate Meal Quality (0-10 scale roughly)
          final mealQuality = (cook.knowledge +
                  cook.judgment +
                  cook.hygiene +
                  cook.experience) /
              4.0;

          if (mealQuality >= 7) {
            // Good meal: Reduce stress and exhaustion
            for (final s in members) {
              s.stress = (s.stress - 0.5).clamp(0.0, 100.0);
              s.exhaustion = (s.exhaustion - 0.5).clamp(0.0, 100.0);
            }
            // Optional: Log critical success
            if (mealQuality >= 9 && _random.nextDouble() < 0.1) {
              gameState.logEvent(
                "The cook ${cook.name} prepared a legendary meal for Aravt ${aravt.id}!",
                category: EventCategory.general,
                severity: EventSeverity.high,
              );
            }
          } else if (mealQuality < 3) {
            // Bad meal: Risk of Dysentery
            if (_random.nextDouble() < 0.2) {
              // 20% chance of outbreak
              for (final s in members) {
                if (_random.nextDouble() < 0.3) {
                  // 30% chance per soldier
                  if (s.currentDisease == null) {
                    s.currentDisease = Disease(
                      type: DiseaseType.dysentery,
                      contagiousness: DiseaseContagiousness.medium,
                      severity: 3,
                      turnContracted: gameState.turn.turnNumber,
                    );
                    gameState.logEvent(
                      "${s.name} has contracted dysentery from a bad meal.",
                      category: EventCategory.health,
                      severity: EventSeverity.high,
                      soldierId: s.id,
                    );
                  }
                }
              }
            }
          }
        }
      }

      // --- EQUERRY ROLE ---
      final equerryId = aravt.dutyAssignments[AravtDuty.equerry];
      if (equerryId != null) {
        final equerry = gameState.findSoldierById(equerryId);
        if (equerry != null && equerry.status == SoldierStatus.alive) {
          // Calculate Horse Care Quality
          final horseCare = (equerry.animalHandling + equerry.patience) / 2.0;

          if (horseCare >= 5) {
            // Good care: Reduce exhaustion for everyone (easier travel)
            for (final s in members) {
              s.exhaustion = (s.exhaustion - 0.5).clamp(0.0, 100.0);
            }
          }
        }
      }
    }
  }
}
