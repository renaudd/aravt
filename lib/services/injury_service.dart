// lib/services/injury_service.dart

import 'dart:math';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/inventory_item.dart'; // For DamageType

class InjuryService {
  static final Random _random = Random();

  /// Determines where a blow lands based on standard probabilities.
  static HitLocation determineHitLocation() {
    int roll = _random.nextInt(100);
    if (roll < 10) return HitLocation.head;      // 10%
    else if (roll < 50) return HitLocation.body; // 40%
    else if (roll < 65) return HitLocation.leftArm; // 15%
    else if (roll < 80) return HitLocation.rightArm; // 15%
    else if (roll < 90) return HitLocation.leftLeg;  // 10%
    else return HitLocation.rightLeg;                // 10%
  }

  /// The core medical lookup table. 
  /// Takes raw penetrating damage and converts it into a specific Injury.
  static Injury? calculateInjury({
    required double damage,
    required HitLocation location,
    required DamageType damageType,
    required String attackerName,
    required int currentTurn,
  }) {
    int severity = 1;
    if (damage >= 7) severity = 4;
    else if (damage >= 4) severity = 3;
    else if (damage >= 2) severity = 2;

    // Severity 1 injuries are just HP loss, no specific Injury object needed yet.
    if (severity == 1) return null;

    String name = "Injury";
    int hpMin = 1, hpMax = 1;
    double bleed = 0.0;
    int stun = 0;
    bool unconscious = false;
    bool limbLoss = false;

    switch (location) {
      case HitLocation.head:
        if (severity == 4) {
          name = (damageType == DamageType.Slashing)
              ? "Decapitation"
              : (damageType == DamageType.Blunt ? "Head Crushed" : "Skewered Brain");
          hpMin = 10; hpMax = 10; unconscious = true; limbLoss = true;
        } else if (severity == 3) {
          if (damageType == DamageType.Piercing) {
            name = "Arrow/Spear Eye/Temple"; hpMin = 4; hpMax = 7; bleed = 0.5; unconscious = true;
          } else if (damageType == DamageType.Slashing) {
            name = "Skull Fracture (Open)"; hpMin = 3; hpMax = 6; bleed = 1.0; unconscious = true;
          } else {
            name = "Depressed Skull Fracture"; hpMin = 5; hpMax = 8; unconscious = true; stun = 2;
          }
        } else {
          if (damageType == DamageType.Piercing) {
            name = "Lost Eye/Punctured Cheek"; hpMin = 2; hpMax = 4; bleed = 0.3;
          } else if (damageType == DamageType.Slashing) {
            name = "Lost Ear/Deep Facial Cut"; hpMin = 1; hpMax = 3; bleed = 0.2;
          } else {
            name = "Broken Jaw/Mod Concussion"; hpMin = 2; hpMax = 4; stun = 1;
          }
        }
        break;
      case HitLocation.body:
        if (severity == 4) {
          name = (damageType == DamageType.Slashing)
              ? "Cut in Half"
              : (damageType == DamageType.Blunt ? "Organs Pulped" : "Impaled Heart");
          hpMin = 10; hpMax = 10; unconscious = true; limbLoss = true; // "Limb loss" here means instant death pretty much
        } else if (severity == 3) {
          if (damageType == DamageType.Piercing) {
            name = "Punctured Lung/Liver"; hpMin = 4; hpMax = 7; bleed = 1.0; unconscious = _random.nextDouble() < 0.5;
          } else if (damageType == DamageType.Slashing) {
            name = "Disemboweled"; hpMin = 4; hpMax = 7; bleed = 1.5; unconscious = true;
          } else {
            name = "Crushed Chest/Spleen Rupture"; hpMin = 5; hpMax = 8; bleed = 0.8; unconscious = true; stun = 1;
          }
        } else {
          if (damageType == DamageType.Piercing) {
            name = "Minor Organ Puncture"; hpMin = 2; hpMax = 4; bleed = 0.4;
          } else if (damageType == DamageType.Slashing) {
            name = "Deep Flesh Cut (Torso)"; hpMin = 1; hpMax = 3; bleed = 0.3;
          } else {
            name = "Broken Ribs"; hpMin = 1; hpMax = 3; stun = 1;
          }
        }
        break;
      case HitLocation.leftArm:
      case HitLocation.rightArm:
        if (severity == 4) {
          name = (damageType == DamageType.Slashing || damageType == DamageType.Blunt)
              ? "Arm Severed/Obliterated"
              : "Arm Impaled (Joint)";
          hpMin = 8; hpMax = 10; bleed = 2.0; limbLoss = true; unconscious = _random.nextDouble() < 0.3;
        } else if (severity == 3) {
          if (damageType == DamageType.Piercing) {
            name = "Impaled Bone (Arm)"; hpMin = 4; hpMax = 7; bleed = 0.6; stun = 1;
          } else if (damageType == DamageType.Slashing) {
            name = "Severed Tendons (Arm)"; hpMin = 3; hpMax = 6; bleed = 1.2;
          } else {
            name = "Shattered Bone (Arm)"; hpMin = 4; hpMax = 7; stun = 2;
          }
        } else {
          if (damageType == DamageType.Piercing) {
            name = "Impaled Flesh (Arm)"; hpMin = 2; hpMax = 4; bleed = 0.2;
          } else if (damageType == DamageType.Slashing) {
            name = "Deep Muscle Cut (Arm)"; hpMin = 1; hpMax = 3; bleed = 0.3;
          } else {
            name = "Fractured Bone (Arm)"; hpMin = 1; hpMax = 3; stun = 1;
          }
        }
        break;
      case HitLocation.leftLeg:
      case HitLocation.rightLeg:
        if (severity == 4) {
          name = (damageType == DamageType.Slashing || damageType == DamageType.Blunt)
              ? "Leg Severed/Obliterated"
              : "Leg Impaled (Joint)";
          hpMin = 8; hpMax = 10; bleed = 2.0; limbLoss = true; unconscious = _random.nextDouble() < 0.3;
        } else if (severity == 3) {
          if (damageType == DamageType.Piercing) {
            name = "Impaled Bone (Leg)"; hpMin = 4; hpMax = 7; bleed = 0.7; stun = 1;
          } else if (damageType == DamageType.Slashing) {
            name = "Severed Tendons (Leg)"; hpMin = 3; hpMax = 6; bleed = 1.3;
          } else {
            name = "Shattered Bone (Leg)"; hpMin = 4; hpMax = 7; stun = 2;
          }
        } else {
          if (damageType == DamageType.Piercing) {
            name = "Impaled Flesh (Leg)"; hpMin = 2; hpMax = 4; bleed = 0.2;
          } else if (damageType == DamageType.Slashing) {
            name = "Deep Muscle Cut (Leg)"; hpMin = 1; hpMax = 3; bleed = 0.3;
          } else {
            name = "Fractured Bone (Leg)"; hpMin = 1; hpMax = 3; stun = 1;
          }
        }
        break;
    }
    
    return Injury(
      name: name,
      location: location,
      severity: severity,
      turnSustained: currentTurn,
      hpDamageMin: hpMin,
      hpDamageMax: hpMax,
      bleedingRate: bleed,
      stunDuration: stun,
      causesUnconsciousness: unconscious,
      causesLimbLoss: limbLoss,
      inflictedBy: attackerName,
    );
  }
}

