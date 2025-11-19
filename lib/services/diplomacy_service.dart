import 'dart:math';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart'; // Correct import
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/providers/game_state.dart';


/// Represents the outcome of an Emissary mission.
class DiplomacyResult {
 final bool wasSuccessful;
 final String report;
 final List<DiplomaticTerm> agreedTerms;
 final Map<int, Soldier> newRecruits;
 // TODO: Add other potential outcomes: new items, relation changes, etc.


 DiplomacyResult({
   required this.wasSuccessful,
   required this.report,
   this.agreedTerms = const [],
   this.newRecruits = const {},
 });
}


/// This service resolves the complex outcomes of Emissary assignments.
class DiplomacyService {
 final Random _random = Random();


 /// Resolves an Emissary task.
 Future<DiplomacyResult> resolveEmissaryTask(
   Aravt emissaryAravt, // [GEMINI-FIX] Updated type to Aravt
   List<Soldier> emissarySoldiers,
   EmissaryTask task,
   Settlement targetSettlement, // Or NPC horde, etc.
   GameState gameState,
 ) async {
   // 1. Get the Captain (the primary diplomat)
   // [GEMINI-FIX] captainId is not nullable in Aravt model
   final Soldier? captain = gameState.findSoldierById(emissaryAravt.captainId);
   if (captain == null) {
     return DiplomacyResult(
         wasSuccessful: false,
         report: "The emissary mission failed as the Aravt has no captain.");
   }


   // 2. Calculate "Diplomacy Score" based on stats
   // (Charisma, Intelligence, Judgment)
   double diplomacyScore = (captain.charisma * 0.5) +
       (captain.intelligence * 0.3) +
       (captain.judgment * 0.2);


   // Add bonus from other members
   for (final soldier in emissarySoldiers) {
     if (soldier.id != captain.id) {
       diplomacyScore += (soldier.charisma * 0.1); // Small bonus
     }
   }


   // 3. Get Target's Disposition
   // TODO: Get relation from targetSettlement.diplomacy[playerHorde.id]
   double targetDisposition = 2.5; // (0-5 scale, 2.5 is neutral)


   // 4. Resolve each term
   List<DiplomaticTerm> agreedTerms = [];
   List<String> reportLines = [];
   bool overallSuccess = true;


   for (final term in task.terms) {
     double successChance =
         (diplomacyScore * 10) + (targetDisposition * 10); // Base %


     // Modify chance based on term
     switch (term) {
       case DiplomaticTerm.DemandTribute:
         // Harder, based on fear
         // TODO: Check horde's 'fear' relation
         successChance -= 30;
         break;
       case DiplomaticTerm.RequestAid:
         // Harder, based on admiration
         successChance -= 10;
         break;
       case DiplomaticTerm.OfferTradingAlliance:
         // Easier
         successChance += 20;
         break;
       // TODO: Add logic for all other terms...
       default:
         break;
     }


     // 5. Roll the dice
     if (_random.nextInt(100) < successChance.clamp(5, 95)) {
       agreedTerms.add(term);
       reportLines.add("They agreed to our request: ${term.name}.");
     } else {
       overallSuccess = false;
       reportLines.add("They refused our request: ${term.name}.");
     }
   }


   // 6. Check for catastrophic failure (e.g., execution)
   if (!overallSuccess &&
       targetDisposition < 1.0 &&
       captain.temperament > 7) {
     // TODO: Implement logic for Aravt being attacked or executed
     reportLines
         .add("Their leader was insulted by our terms and we barely escaped!");
   }


   // 7. Consolidate report
   String finalReport =
       "Emissary mission to ${targetSettlement.name} complete.\n" +
           reportLines.join("\n");


   return DiplomacyResult(
       wasSuccessful: overallSuccess,
       report: finalReport,
       agreedTerms: agreedTerms);
 }
}

