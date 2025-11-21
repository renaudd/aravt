import 'dart:math';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

class TrainingDisciplineService {
  final Random _random = Random();

  Future<void> resolveTrainingAndDiscipline(GameState gameState) async {
    print(
        "Step 10.6: Resolving Training & Discipline (Drill Sergeant, Disciplinarian)...");

    final isDrillDay = gameState.turn.turnNumber % 7 == 0;

    for (final aravt in gameState.aravts) {
      final members = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      // --- DRILL SERGEANT (Weekly) ---
      if (isDrillDay) {
        final drillSergeantId = aravt.dutyAssignments[AravtDuty.drillSergeant];
        if (drillSergeantId != null) {
          final drillSergeant = gameState.findSoldierById(drillSergeantId);
          if (drillSergeant != null &&
              drillSergeant.status == SoldierStatus.alive) {
            // Calculate Drill Quality
            final avgWeaponSkill = (drillSergeant.swordSkill +
                    drillSergeant.spearSkill +
                    drillSergeant.mountedArcherySkill) /
                3.0;

            final drillQuality = (drillSergeant.leadership +
                    drillSergeant.experience +
                    (avgWeaponSkill / 5.0)) /
                3.0;

            if (drillQuality >= 5) {
              // Successful Drill: XP Gain
              int xpGain = 1;
              if (drillQuality >= 8) xpGain = 2;

              for (final s in members) {
                final roll = _random.nextInt(5);
                switch (roll) {
                  case 0:
                    s.swordSkill = (s.swordSkill + xpGain).clamp(0, 100);
                    break;
                  case 1:
                    s.spearSkill = (s.spearSkill + xpGain).clamp(0, 100);
                    break;
                  case 2:
                    s.mountedArcherySkill =
                        (s.mountedArcherySkill + xpGain).clamp(0, 100);
                    break;
                  case 3:
                    s.shieldSkill = (s.shieldSkill + xpGain).clamp(0, 100);
                    break;
                  case 4:
                    s.longRangeArcherySkill =
                        (s.longRangeArcherySkill + xpGain).clamp(0, 100);
                    break;
                }
              }

              gameState.logEvent(
                "Drill Sergeant ${drillSergeant.name} led a rigorous training session for Aravt ${aravt.id}.",
                category: EventCategory.general,
                severity: EventSeverity.normal,
              );
            }
          }
        }
      }

      // --- DISCIPLINARIAN (Daily) ---
      final disciplinarianId = aravt.dutyAssignments[AravtDuty.disciplinarian];
      if (disciplinarianId != null) {
        final disciplinarian = gameState.findSoldierById(disciplinarianId);
        if (disciplinarian != null &&
            disciplinarian.status == SoldierStatus.alive) {
          // Calculate Discipline Quality
          final disciplineQuality = (disciplinarian.strength +
                  disciplinarian.leadership +
                  disciplinarian.judgment) /
              3.0;

          if (disciplineQuality >= 6) {
            // Good Discipline: Order prevails
            for (final s in members) {
              if (s.id == disciplinarian.id) continue;

              if (!s.hordeRelationships.containsKey(disciplinarian.id)) {
                s.hordeRelationships[disciplinarian.id] = RelationshipValues();
              }

              final rel = s.hordeRelationships[disciplinarian.id]!;
              rel.updateRespect(0.05);
              rel.updateFear(0.05);

              // Reduce Stress (Order)
              s.stress = (s.stress - 0.2).clamp(0.0, 100.0);
            }
          } else if (disciplineQuality < 3) {
            // Bad Discipline: Bullying or Incompetence
            for (final s in members) {
              if (s.id == disciplinarian.id) continue;

              // Increase Stress
              s.stress = (s.stress + 0.5).clamp(0.0, 100.0);

              // Lose Respect
              if (!s.hordeRelationships.containsKey(disciplinarian.id)) {
                s.hordeRelationships[disciplinarian.id] = RelationshipValues();
              }
              final rel = s.hordeRelationships[disciplinarian.id]!;
              rel.updateRespect(-0.1);
            }
          }
        }
      }
    }
  }
}
