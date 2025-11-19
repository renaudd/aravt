import 'dart:math';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_models.dart';


/// Service for handling the decision-making logic of an Aravt Captain.
class AravtCaptainService {
 final Random _random = Random();


 /// Resolves all Aravt Captain decisions for all aravts in the game.
 Future<void> resolveAravtCaptainTurns(GameState gameState) async {
   // 1. Identify Player's Aravt to skip it
   String? playerAravtId;
   if (gameState.player != null) {
     playerAravtId = gameState.player!.aravt;
   }


   // Get all aravts from all hordes
   List<Aravt> allAravts = [
     ...gameState.aravts,
     ...gameState.npcAravts1,
     ...gameState.npcAravts2,
   ];


   for (var aravt in allAravts) {
     // [GEMINI-FIX] Skip player's aravt so we don't overwrite their manual duty assignments
     if (aravt.id == playerAravtId) continue;


     final Soldier? captain = gameState.findSoldierById(aravt.captainId);
     if (captain == null || captain.status != SoldierStatus.alive) {
       // print("AI CAPTAIN ERROR: Could not find active captain for Aravt ${aravt.id}");
       continue;
     }


     // Get all active soldier objects in this aravt
     final List<Soldier> soldiersInAravt = aravt.soldierIds
         .map((id) => gameState.findSoldierById(id))
         .whereType<Soldier>()
         .where((s) => s.status == SoldierStatus.alive && !s.isImprisoned)
         .toList();


     if (soldiersInAravt.isEmpty) continue;


     // Run the 3 sub-tasks
     _resolveDutyAssignments(captain, aravt, soldiersInAravt, gameState);
     _resolveMemberManagement(captain, aravt, soldiersInAravt, gameState);
     _resolvePersonalInteractions(captain, aravt, soldiersInAravt, gameState);
   }
 }


 /// 1. AI for Re-assigning Intra-Aravt Duties
 void _resolveDutyAssignments(Soldier captain, Aravt aravt,
     List<Soldier> soldiersInAravt, GameState gameState) {
   // Clear old duties first for NPCs to ensure fresh optimal assignments
   // We use preferredDuties as "Assigned Duties" for NPCs for now.
   for (var member in soldiersInAravt) {
     // Don't clear the captain's own self-assigned duties if any
     if (member.id != captain.id) {
       member.preferredDuties.clear();
     }
   }


   // 1. Assign a Cook (Survival critical) - Patience & Animal Handling
   _assignBestFit(soldiersInAravt, AravtDuty.cook,
       (s) => (s.patience + s.animalHandling).toDouble());


   // 2. Assign a Medic if anyone has skill - Int & Knowledge (Surgeon bonus)
   _assignBestFit(
       soldiersInAravt,
       AravtDuty.medic,
       (s) =>
           (s.specialSkills.contains(SpecialSkill.surgeon) ? 10.0 : 0.0) +
           s.intelligence +
           s.knowledge);


   // 3. Assign a Scout/Outrider - Perception & Horsemanship
 //  _assignBestFit(soldiersInAravt, AravtDuty.scout,
 //      (s) => (s.perception + s.horsemanship).toDouble());


   // 4. Assign Quartermaster - Honesty & Intelligence
  // _assignBestFit(soldiersInAravt, AravtDuty.quartermaster,
  //     (s) => (s.honesty + s.intelligence).toDouble());


   // 5. Assign Chronicler (if literate/smart) - Knowledge & Intelligence
   _assignBestFit(soldiersInAravt, AravtDuty.chronicler,
       (s) => (s.knowledge + s.intelligence).toDouble());
 }


 void _assignBestFit(
     List<Soldier> members, AravtDuty duty, double Function(Soldier) scorer) {
   Soldier? bestCandidate;
   double bestScore = -1.0;


   for (var member in members) {
     // Don't assign multiple duties to the same person if possible
     if (member.preferredDuties.isNotEmpty) continue;
     // Skip if they DESPISE this duty
     if (member.despisedDuties.contains(duty)) continue;


     double score = scorer(member);
     // Bonus if they PREFER this duty
     if (member.preferredDuties.contains(duty)) score += 5.0;


     if (score > bestScore && score > 3.0) {
       // Minimal competence threshold
       bestScore = score;
       bestCandidate = member;
     }
   }


   if (bestCandidate != null) {
     bestCandidate.preferredDuties.add(duty);
   }
 }


 /// 2. AI for Member Management (Stockade/Expel)
 void _resolveMemberManagement(Soldier captain, Aravt aravt,
     List<Soldier> soldiersInAravt, GameState gameState) {
   for (var soldier in soldiersInAravt) {
     if (soldier.id == captain.id) continue;


     final rel = captain.getRelationship(soldier.id);
     bool shouldImprison = false;
     String reason = "";


     // Check for bad traits + low respect/high strictness
     if (soldier.attributes.contains(SoldierAttribute.murderer) ||
         soldier.attributes.contains(SoldierAttribute.bully)) {
       // If captain is perceptive OR strict, they might act. Low chance per day to avoid instant jailing.
       if ((captain.perception > 6 || captain.temperament < 4) &&
           _random.nextDouble() < 0.05) {
         shouldImprison = true;
         reason = "suspicious behavior";
       }
     }


     // Check for insubordination (low loyalty + strict captain)
     if (rel.loyalty < 1.5 &&
         captain.temperament < 4 &&
         _random.nextDouble() < 0.05) {
       shouldImprison = true;
       reason = "insubordination";
     }


     if (shouldImprison && !soldier.isImprisoned) {
       gameState.imprisonSoldier(soldier);
       gameState.logEvent(
           "${captain.name} imprisoned ${soldier.name} for $reason.",
           category: EventCategory.general,
           severity: EventSeverity.high);
     } else if (soldier.isImprisoned && _random.nextDouble() < 0.1) {
       // 10% chance per day to release if they were already imprisoned
       gameState.imprisonSoldier(soldier); // Toggles it off
       gameState.logEvent(
           "${captain.name} released ${soldier.name} from the stockade.",
           category: EventCategory.general);
     }
   }
 }


 /// 3. AI for Personal Interactions (Gifting)
 void _resolvePersonalInteractions(Soldier captain, Aravt aravt,
     List<Soldier> soldiersInAravt, GameState gameState) {
   // Only charismatic captains bother with this
   if (captain.charisma < 6) return;


   for (var soldier in soldiersInAravt) {
     if (soldier.id == captain.id) continue;


     final rel = soldier.getRelationship(captain.id);
     // If they already admire the captain, maybe reward them to cement loyalty
     // Very low chance per day to keep it rare.
     if (rel.admiration > 4.0 && _random.nextDouble() < 0.02) {
       _attemptGift(captain, soldier, gameState);
     }
   }
 }


 void _attemptGift(Soldier captain, Soldier recipient, GameState gameState) {
   // Find a suitable gift in captain's inventory
   InventoryItem? gift;


   // 1. Look for preferred gift type that is also a treasure
   try {
     gift = captain.personalInventory.firstWhere(
       (i) =>
           i.itemType.name == recipient.giftTypePreference.name &&
           i.valueType == ValueType.Treasure,
     );
   } catch (e) {
     // 2. Fallback to any treasure
     try {
       gift = captain.personalInventory
           .firstWhere((i) => i.valueType == ValueType.Treasure);
     } catch (e2) {
       // No suitable gifts
     }
   }


   if (gift != null) {
     captain.personalInventory.remove(gift);
     recipient.personalInventory.add(gift);


     // Boost relationships significantly
     recipient.getRelationship(captain.id).updateLoyalty(0.5);
     recipient.getRelationship(captain.id).updateAdmiration(0.5);


     gameState.logEvent(
         "${captain.name} gifted ${gift.name} to ${recipient.name} as a reward for their faithful service.",
         category: EventCategory.general,
         severity: EventSeverity.low);
   }
 }
}

