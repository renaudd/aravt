import 'package:aravt/models/soldier_data.dart';


/// The specific type of unassigned action a soldier might take.
enum UnassignedActionType {
 // Social & Interpersonal
 barter,
 startFight,
 murderAttempt,
 lodgeRequest,
 socialInteraction, // (insult, compliment, joke)
 gossip,
 giveAdvice,
 proselytize,
 giftItem,
  // Trait & Skill Based
 traitActionSurgeon,   // (e.g., cut hair)
 traitActionFalconer,  // (e.g., bait birds)
 tendHorses,
 playGame,


 // Responsive & Default
 responsiveAction,     // (e.g., mourning, fasting)
 spreadDisease,
 divulgeInfoToPlayer,  // (Default for player's aravt)
 idle,                 // (Does nothing)
}


/// Represents a single possible action in a soldier's "event chart"
/// Each soldier will generate a list of these, and one will be chosen.
class SoldierActionProposal {
 final UnassignedActionType actionType;
 final Soldier soldier;
 final double probability; // A weighting for this action
  // Optional targets or context
 final int? targetSoldierId;
 final String? contextData; // (e.g., item to barter, piece of gossip)


 SoldierActionProposal({
   required this.actionType,
   required this.soldier,
   required this.probability,
   this.targetSoldierId,
   this.contextData,
 });
}



