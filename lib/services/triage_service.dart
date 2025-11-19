// services/triage_service.dart
// import 'dart:math'; // Removed (Unused)
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/triage_models.dart';
// import 'package:aravt/models/game_date.dart'; // Removed (Unused, imported by triage_models)
import 'package:aravt/providers/game_state.dart';
// import 'package:aravt/models/horde_data.dart'; // Removed (Unused)
import 'package:aravt/models/game_event.dart';

class TriageService {
  /// Runs the post-combat triage simulation.
  /// This will advance the GameState clock by several hours.
  Future<void> beginTriage(GameState gameState, CombatReport report) async {
    // 1. Gather Patients (Player horde only)
    final List<TriageCase> patients = [];
    for (final summary in report.playerSoldiers) {
      if (summary.finalStatus == SoldierStatus.wounded ||
          summary.finalStatus == SoldierStatus.unconscious) {
        // Find the "live" soldier object
        final Soldier? soldier =
            gameState.findSoldierById(summary.originalSoldier.id);
        if (soldier != null && soldier.injuries.isNotEmpty) {
          patients
              .add(TriageCase(soldier: soldier, initialInjuries: soldier.injuries));
        }
      }
    }

    if (patients.isEmpty) {
      gameState.logEvent("No wounded survivors require triage.",
          category: EventCategory.health);
      return;
    }

    // 2. Gather Surgeons (Player horde only)
    final List<SurgeonWorkload> surgeons = [];

    // --- FIX 1: Changed 'gameState.playerHorde.soldiers' to 'gameState.horde' ---
    for (final soldier in gameState.horde) {
      if (soldier.status == SoldierStatus.alive && // Must be alive
          soldier.specialSkills.contains(SpecialSkill.surgeon)) {
        surgeons.add(SurgeonWorkload(soldier: soldier));
      }
    }

    if (surgeons.isEmpty) {
      gameState.logEvent("No surgeons are available to treat the wounded!",
          category: EventCategory.health, severity: EventSeverity.critical);
      // Run one bleed-out tick for the hour spent finding no one
      _processBleedOut(gameState, patients);
      return;
    }

    gameState.logEvent(
        "Triage begins: ${patients.length} wounded, ${surgeons.length} surgeons available.",
        category: EventCategory.health,
        severity: EventSeverity.high);

    // 3. Calculate Initial Priority for all patients
    _recalculateAllPriorities(patients, gameState);

    // 4. Run the simulation
    await _runTriageSimulation(gameState, patients, surgeons);

    // 5. Finalize: Update soldier injury lists
    for (final patient in patients) {
      if (patient.status == TriageStatus.Recovering ||
          patient.status == TriageStatus.Stabilized) {
        // Replace the soldier's injury list with the new list of treated injuries
        patient.soldier.injuries = patient.treatedInjuries;
      } else if (patient.status == TriageStatus.DiedWhileWaiting) {
        // The bleed-out process already updated their health,
        // but we'll set their status explicitly.
        patient.soldier.status = SoldierStatus.killed;
      }
      // If still 'Waiting', their injuries remain untreated.
    }

    gameState.logEvent("Triage complete.", category: EventCategory.health);
  }

  /// The main hourly simulation loop.
  Future<void> _runTriageSimulation(
    GameState gameState,
    List<TriageCase> patients,
    List<SurgeonWorkload> surgeons,
  ) async {
    bool triageInProgress = true;
    int simulationHours = 0;

    while (triageInProgress) {
      // Emergency stop after 3 days
      if (simulationHours > 72) {
        gameState.logEvent(
            "Triage halted after 72 hours; remaining patients must wait.",
            category: EventCategory.health,
            severity: EventSeverity.critical);
        break;
      }

      // 1. Advance Time
      gameState.gameDate.addHours(1);
      simulationHours++;

      // 2. Bleed-out
      _processBleedOut(gameState, patients);

      // 3. Update Surgeons
      _updateSurgeons(gameState, surgeons, patients);

      // 4. Assign Idle Surgeons
      _assignIdleSurgeons(gameState, surgeons, patients);

      // 5. Check End Condition
      bool patientsWaiting = patients.any((p) =>
          p.status == TriageStatus.Waiting ||
          p.status == TriageStatus.Stabilized);
      bool surgeonsWorking =
          surgeons.any((s) => s.status == SurgeonStatus.InSurgery);

      triageInProgress = patientsWaiting && surgeons.isNotEmpty;

      // If all patients are done (or dead) and surgeons are idle/resting
      if (!patientsWaiting && !surgeonsWorking) {
        triageInProgress = false;
      }
    }
  }

  /// Applies 1 hour of bleeding to all waiting patients.
  void _processBleedOut(GameState gameState, List<TriageCase> patients) {
    // Get a fixed list to iterate over
    final waitingPatients =
        patients.where((p) => p.status == TriageStatus.Waiting).toList();

    for (final patient in waitingPatients) {
      int bleedDamage = patient.currentBleedRate.round();
      if (bleedDamage > 0) {
        patient.soldier.bodyHealthCurrent -= bleedDamage;
        if (patient.soldier.bodyHealthCurrent <= 0) {
          patient.status = TriageStatus.DiedWhileWaiting;
          patient.soldier.status = SoldierStatus.killed; // Mark as dead
          gameState.logEvent(
              "${patient.soldier.name} has bled out and died while waiting for treatment!",
              category: EventCategory.health,
              severity: EventSeverity.critical,
              soldierId: patient.soldier.id);
        }
      }
    }
  }

  /// Checks surgeon rest timers and completes finished surgeries.
  void _updateSurgeons(GameState gameState, List<SurgeonWorkload> surgeons,
      List<TriageCase> patients) {
    for (final surgeon in surgeons) {
      // Check for rest completion
      if (surgeon.status == SurgeonStatus.Resting) {
        if (surgeon.restEndsAt != null &&
            (gameState.gameDate.isAfter(surgeon.restEndsAt!) ||
                gameState.gameDate.isAtSameMomentAs(surgeon.restEndsAt!))) {
          surgeon.status = SurgeonStatus.Idle;
          surgeon.hoursWorkedThisShift = 0;
          surgeon.restEndsAt = null;
          gameState.logEvent(
              "${surgeon.soldier.name} is rested and ready to resume triage.",
              category: EventCategory.health,
              soldierId: surgeon.soldier.id);
        }
      }

      // Check for surgery completion
      if (surgeon.status == SurgeonStatus.InSurgery) {
        if (surgeon.surgeryCompletesAt != null &&
            (gameState.gameDate.isAfter(surgeon.surgeryCompletesAt!) ||
                gameState.gameDate
                    .isAtSameMomentAs(surgeon.surgeryCompletesAt!))) {
          _completeSurgery(gameState, surgeon, patients);
        }
      }
    }
  }

  /// Finds new patients for any idle surgeons.
  void _assignIdleSurgeons(GameState gameState, List<SurgeonWorkload> surgeons,
      List<TriageCase> patients) {
    final idleSurgeons =
        surgeons.where((s) => s.status == SurgeonStatus.Idle).toList();
    if (idleSurgeons.isEmpty) return;

    // Re-calculate priorities every hour to ensure the most critical are seen
    _recalculateAllPriorities(patients, gameState);

    // Sort patients by priority, highest first
    final availablePatients = patients
        .where((p) =>
            p.status == TriageStatus.Waiting ||
            p.status == TriageStatus.Stabilized)
        .toList();
    availablePatients.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    if (availablePatients.isEmpty) return;

    int patientIndex = 0;
    for (final surgeon in idleSurgeons) {
      if (patientIndex < availablePatients.length) {
        final patient = availablePatients[patientIndex];
        _beginSurgery(gameState, surgeon, patient);
        patientIndex++;
      } else {
        break; // No more patients for this surgeon
      }
    }
  }

  /// Calculates the priority for every patient in the queue.
  void _recalculateAllPriorities(
      List<TriageCase> patients, GameState gameState) {
    // --- FIX 2: Changed 'gameState.playerAravts' to 'gameState.aravts' ---
    final Set<int> captainIds =
        gameState.aravts.map((a) => a.captainId).toSet();

    // --- FIX 3: Changed 'gameState.playerHordeData?.leaderId' to 'gameState.player?.id' ---
    final int leaderId = gameState.player?.id ?? -1;

    for (final patient in patients) {
      // Only recalculate for those still waiting
      if (patient.status == TriageStatus.Waiting ||
          patient.status == TriageStatus.Stabilized) {
        int score = 0;
        if (patient.soldier.id == leaderId) {
          score += 10000; // Leader is top priority
        } else if (captainIds.contains(patient.soldier.id)) {
          score += 5000; // Captains are next
        }

        // Prioritize stabilization
        score += (patient.currentBleedRate * 100).round();
        // Then prioritize severity
        score += patient.totalSeverity * 10;
        // Then prioritize low health
        score += (100 -
            patient.soldier
                .bodyHealthCurrent); // Assuming 100 is a rough max

        patient.priorityScore = score;
      }
    }
  }

  /// Starts a new operation on a patient.
  void _beginSurgery(
      GameState gameState, SurgeonWorkload surgeon, TriageCase patient) {
    // Find the single most critical injury to treat first
    // Pri 1: Stop bleeding
    // Pri 2: Highest severity
    final Injury injuryToTreat;
    final List<Injury> bleeds =
        patient.untreatedInjuries.where((i) => i.bleedingRate > 0).toList();

    if (bleeds.isNotEmpty) {
      bleeds.sort((a, b) => b.bleedingRate.compareTo(a.bleedingRate));
      injuryToTreat = bleeds.first;
    } else {
      // No bleeds, treat most severe
      patient.untreatedInjuries.sort((a, b) => b.severity.compareTo(a.severity));
      injuryToTreat = patient.untreatedInjuries.first;
    }

    final int hours = _calculateHoursOfWork(surgeon, injuryToTreat);

    surgeon.status = SurgeonStatus.InSurgery;
    surgeon.currentPatient = patient;
    surgeon.surgeryCompletesAt = gameState.gameDate.copy()..addHours(hours);

    patient.status = TriageStatus.InSurgery;

    gameState.logEvent(
      "${surgeon.soldier.name} begins operating on ${patient.soldier.name} (treating ${injuryToTreat.name}). Estimated $hours hours.",
      category: EventCategory.health,
      soldierId: surgeon.soldier.id,
    );
  }

  /// Completes a finished operation.
  void _completeSurgery(GameState gameState, SurgeonWorkload surgeon,
      List<TriageCase> patients) {
    final TriageCase patient = surgeon.currentPatient!;
    
    // --- Removed Unused Variables ---
    
    final Injury originalInjury;
    // Find the injury that was being treated
    if (patient.untreatedInjuries.any((i) => i.bleedingRate > 0)) {
      // Find the highest bleeding injury
      var bleedingInjuries =
          patient.untreatedInjuries.where((i) => i.bleedingRate > 0).toList();
      bleedingInjuries.sort((a, b) => b.bleedingRate.compareTo(a.bleedingRate));
      originalInjury = bleedingInjuries.first;
    } else {
      // Find the most severe injury
      var severeInjuries = patient.untreatedInjuries.toList();
      severeInjuries.sort((a, b) => b.severity.compareTo(a.severity));
      originalInjury = severeInjuries.first;
    }

    final int calculatedHours = _calculateHoursOfWork(surgeon, originalInjury);

    surgeon.hoursWorkedThisShift += calculatedHours;

    // Move the injury from untreated to treated
    final Injury treatedInjury = patient.untreatedInjuries
        .removeAt(patient.untreatedInjuries.indexOf(originalInjury));

    // Create the new "treated" version
    patient.treatedInjuries.add(Injury(
      name: "${treatedInjury.name} (Treated)",
      location: treatedInjury.location,
      severity: treatedInjury.severity.clamp(1, 3), // Reduce severity post-op
      turnSustained: treatedInjury.turnSustained,
      hpDamageMin: 0,
      hpDamageMax: 0,
      bleedingRate: 0.0, // Bleeding is stopped
      stunDuration: 0,
      causesUnconsciousness: false, // Patient may still be unconscious
      causesLimbLoss: treatedInjury.causesLimbLoss, // Fact remains
    ));

    gameState.logEvent(
      "${surgeon.soldier.name} finished operating on ${patient.soldier.name} (treated ${originalInjury.name}).",
      category: EventCategory.health,
      soldierId: surgeon.soldier.id,
    );

    // Reset surgeon
    surgeon.currentPatient = null;
    surgeon.surgeryCompletesAt = null;

    // Check patient status
    if (patient.untreatedInjuries.isEmpty) {
      patient.status = TriageStatus.Recovering;
      gameState.logEvent(
          "${patient.soldier.name} is fully treated and recovering.",
          category: EventCategory.health,
          soldierId: patient.soldier.id);
    } else if (patient.currentBleedRate > 0) {
      patient.status = TriageStatus.Waiting; // Still bleeding, back to queue
      gameState.logEvent(
          "${patient.soldier.name} is stabilized, but still has bleeding injuries.",
          category: EventCategory.health,
          severity: EventSeverity.normal,
          soldierId: patient.soldier.id);
    } else {
      patient.status = TriageStatus.Stabilized; // No more bleeding, but needs ops
      gameState.logEvent(
          "${patient.soldier.name} is stabilized, but requires further operations.",
          category: EventCategory.health,
          soldierId: patient.soldier.id);
    }

    // Check surgeon fatigue
    if (surgeon.hoursWorkedThisShift >= 16) {
      surgeon.status = SurgeonStatus.Resting;
      surgeon.restEndsAt = gameState.gameDate.copy()..addHours(8);
      gameState.logEvent(
        "${surgeon.soldier.name} has worked for ${surgeon.hoursWorkedThisShift} hours and must rest for 8 hours.",
        category: EventCategory.health,
        severity: EventSeverity.normal,
        soldierId: surgeon.soldier.id,
      );
    } else {
      surgeon.status = SurgeonStatus.Idle; // Ready for next patient
    }
  }

  /// Calculates the hours of work for a single operation.
  int _calculateHoursOfWork(SurgeonWorkload surgeon, Injury injury) {
    double baseHours = 0;

    // 1. Intervention Type
    if (injury.bleedingRate > 0) {
      baseHours = 2.0 + injury.bleedingRate; // 2-4 hours to stabilize
    } else if (injury.causesLimbLoss) {
      baseHours = 8.0; // Amputation
    } else {
      baseHours = injury.severity * 1.5; // 3-6 hours for other ops
    }

    // 2. Surgeon Skill (Skill 15 = 1.0x, Skill 30 = 0.25x, Skill 3 = 1.6x)
    // (intelligence + perception + patience)
    double skillModifier = 1.0 - (surgeon.surgeonSkill - 15) * 0.05;

    // 3. Equipment & Setting (Defaults for now)
    double equipmentModifier = 1.0; // TODO: Check inventory
    double settingModifier = 1.2; // 20% penalty for field surgery

    int finalHours = (baseHours * skillModifier * equipmentModifier * settingModifier)
        .round()
        .clamp(1, 16); // Min 1 hour, max 16 for a single op

    return finalHours;
  }
}

