// lib/models/combat_models.dart
import 'dart:math';
import 'package:aravt/models/soldier_data.dart';

/// Represents the specific location an attack hits.
enum HitLocation { head, body, leftArm, rightArm, leftLeg, rightLeg }

/// Helper to get HitLocation from a string name, with a fallback.
HitLocation hitLocationFromName(String? name) {
  for (final loc in HitLocation.values) {
    if (loc.name == name) {
      return loc;
    }
  }
  return HitLocation.body; // Default fallback
}

/// Represents a specific injury sustained by a soldier.
class Injury {
  final String name;
  final HitLocation location;
  final int severity; // 1 (minor) to 4 (critical)
  final int turnSustained;

  // Damage effects
  final int hpDamageMin, hpDamageMax;
  final double bleedingRate; // HP damage per turn
  final int stunDuration; // Turns stunned

  // Critical effects
  final bool causesUnconsciousness;
  final bool causesLimbLoss;

  final bool isTreated;

  // --- NEW: This field stores who caused the injury ---
  final String inflictedBy;
  // --- END NEW ---

  Injury({
    required this.name,
    required this.location,
    required this.severity,
    required this.turnSustained,
    required this.hpDamageMin,
    required this.hpDamageMax,
    this.bleedingRate = 0.0,
    this.stunDuration = 0,
    this.causesUnconsciousness = false,
    this.causesLimbLoss = false,
    this.isTreated = false,
    this.inflictedBy = "Unknown", // Default value
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location.name,
        'severity': severity,
        'turnSustained': turnSustained,
        'hpDamageMin': hpDamageMin,
        'hpDamageMax': hpDamageMax,
        'bleedingRate': bleedingRate,
        'stunDuration': stunDuration,
        'causesUnconsciousness': causesUnconsciousness,
        'causesLimbLoss': causesLimbLoss,
        'isTreated': isTreated,
        'inflictedBy': inflictedBy, // <-- ADDED
      };

  factory Injury.fromJson(Map<String, dynamic> json) {
    return Injury(
      name: json['name'],
      location: hitLocationFromName(json['location']),
      severity: json['severity'],
      turnSustained: json['turnSustained'],
      hpDamageMin: json['hpDamageMin'],
      hpDamageMax: json['hpDamageMax'],
      bleedingRate: json['bleedingRate'] ?? 0.0,
      stunDuration: json['stunDuration'] ?? 0,
      causesUnconsciousness: json['causesUnconsciousness'] ?? false,
      causesLimbLoss: json['causesLimbLoss'] ?? false,
      isTreated: json['isTreated'] ?? false,
      inflictedBy: json['inflictedBy'] ?? 'Unknown', // <-- ADDED
    );
  }

  int get rolledHpDamage =>
      hpDamageMin + Random().nextInt(hpDamageMax - hpDamageMin + 1);

  @override
  String toString() => "$name (${location.name})";
}

/// Final result of the combat.
enum CombatResult {
  playerVictory,
  playerDefeat,
  mutualDestruction,
  playerRout, // Player side fled
  enemyRout, // Enemy side fled
  mutualRout
}

/// Helper to get CombatResult from a string name
CombatResult combatResultFromName(String? name) {
  for (final val in CombatResult.values) {
    if (val.name == name) return val;
  }
  return CombatResult.mutualRout; // Default
}
