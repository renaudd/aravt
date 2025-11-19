// models/triage_models.dart
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/game_date.dart';

enum TriageStatus {
  Waiting, // In the queue
  InSurgery, // Actively being operated on
  Stabilized, // Bleeding stopped, but requires more operations
  Recovering, // All operations complete
  DiedWhileWaiting // Bled out before help arrived
}

enum SurgeonStatus {
  Idle, // Available for a patient
  InSurgery, // Busy with a patient
  Resting // 16-hour shift is over
}

/// A wrapper for a patient in the triage queue.
class TriageCase {
  final Soldier soldier;
  final List<Injury> untreatedInjuries;
  final List<Injury> treatedInjuries;
  TriageStatus status;
  int priorityScore;

  TriageCase({
    required this.soldier,
    required List<Injury> initialInjuries,
    this.status = TriageStatus.Waiting,
    this.priorityScore = 0,
  })  : untreatedInjuries = List.from(initialInjuries), // Clone the list
        treatedInjuries = [];

  /// Calculates the total bleed rate from all untreated injuries.
  double get currentBleedRate {
    if (status != TriageStatus.Waiting && status != TriageStatus.Stabilized) {
      return 0.0;
    }
    double totalBleed = 0.0;
    for (final injury in untreatedInjuries) {
      totalBleed += injury.bleedingRate;
    }
    return totalBleed;
  }
  
  /// Total severity of all untreated injuries.
  int get totalSeverity {
     int total = 0;
     for (final injury in untreatedInjuries) {
       total += injury.severity;
     }
     return total;
  }
}

/// A wrapper for a surgeon to track their workload and status.
class SurgeonWorkload {
  final Soldier soldier;
  final int surgeonSkill; // Calculated once
  SurgeonStatus status;
  int hoursWorkedThisShift;
  GameDate? restEndsAt;

  // Active operation state
  TriageCase? currentPatient;
  GameDate? surgeryCompletesAt;

  SurgeonWorkload({
    required this.soldier,
    this.status = SurgeonStatus.Idle,
    this.hoursWorkedThisShift = 0,
    this.restEndsAt,
    this.currentPatient,
    this.surgeryCompletesAt,
  }) : // Calculate skill based on stats
       surgeonSkill = (soldier.intelligence + soldier.perception + soldier.patience)
           .clamp(1, 30); // 1-30 scale
}

