import 'dart:math';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

class MoraleNarrativeService {
  final Random _random = Random();

  Future<void> resolveMoraleAndNarrativeRoles(GameState gameState) async {
    print(
        "Step 10.7: Resolving Morale & Narrative Roles (Tuulch, Chaplain)...");

    // Tuulch: Weekly storytelling? Or daily small chance?
    // Let's do Weekly for big event, or Daily small chance.
    // Let's do Daily small chance (20%) for Tuulch to tell a story.

    // Chaplain: Weekly religious service (e.g., every 7 days).
    final isReligiousServiceDay = gameState.turn.turnNumber % 7 == 0;

    for (final aravt in gameState.aravts) {
      final members = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      // --- TUULCH (Daily Chance) ---
      final tuulchId = aravt.dutyAssignments[AravtDuty.tuulch];
      if (tuulchId != null) {
        final tuulch = gameState.findSoldierById(tuulchId);
        if (tuulch != null && tuulch.status == SoldierStatus.alive) {
          // 20% chance to tell a story
          if (_random.nextDouble() < 0.20) {
            // Calculate Story Quality
            // Based on Charisma, Knowledge, and Experience
            final storyQuality =
                (tuulch.charisma + tuulch.knowledge + tuulch.experience) / 3.0;

            if (storyQuality >= 5) {
              // Good Story: Boost Morale (reduce stress), Increase Admiration
              for (final s in members) {
                if (s.id == tuulch.id) continue;

                // Reduce Stress
                s.stress = (s.stress - 1.0).clamp(0.0, 100.0);

                // Increase Admiration
                if (!s.hordeRelationships.containsKey(tuulch.id)) {
                  s.hordeRelationships[tuulch.id] = RelationshipValues();
                }
                s.hordeRelationships[tuulch.id]!.updateAdmiration(0.1);
              }

              gameState.logEvent(
                "Tuulch ${tuulch.name} told a captivating epic around the campfire, lifting everyone's spirits.",
                category: EventCategory.general,
                severity: EventSeverity.normal,
              );
            }
          }
        }
      }

      // --- CHAPLAIN (Weekly) ---
      if (isReligiousServiceDay) {
        final chaplainId = aravt.dutyAssignments[AravtDuty.chaplain];
        if (chaplainId != null) {
          final chaplain = gameState.findSoldierById(chaplainId);
          if (chaplain != null && chaplain.status == SoldierStatus.alive) {
            // Calculate Service Quality
            // Based on Knowledge, Charisma, and Religion Intensity (if mapped to int? No, it's enum)
            // Let's use Knowledge + Charisma + Wisdom/Judgment
            final serviceQuality =
                (chaplain.knowledge + chaplain.charisma + chaplain.judgment) /
                    3.0;

            if (serviceQuality >= 5) {
              // Good Service: Boost Morale for same religion, maybe convert others?
              for (final s in members) {
                if (s.id == chaplain.id) continue;

                if (s.religionType == chaplain.religionType) {
                  // Same religion: Big stress reduction
                  s.stress = (s.stress - 2.0).clamp(0.0, 100.0);

                  // Increase Respect
                  if (!s.hordeRelationships.containsKey(chaplain.id)) {
                    s.hordeRelationships[chaplain.id] = RelationshipValues();
                  }
                  s.hordeRelationships[chaplain.id]!.updateRespect(0.1);
                } else {
                  // Different religion: Small chance to convert? Or just small stress reduction if tolerant?
                  // For now, just small stress reduction (peaceful vibes)
                  s.stress = (s.stress - 0.5).clamp(0.0, 100.0);
                }
              }

              gameState.logEvent(
                "Chaplain ${chaplain.name} led a moving religious service for Aravt ${aravt.id}.",
                category: EventCategory.general,
                severity: EventSeverity.normal,
              );
            }
          }
        }
      }
    }
  }
}
