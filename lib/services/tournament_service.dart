import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/game_data/item_templates.dart'; // For horse names
import 'package:aravt/models/combat_models.dart'; // For SoldierStatus


class TournamentService {
 final Random _random = Random();


 Future<TournamentResult> runTournament({
   required String name,
   required GameDate date,
   required List<TournamentEventType> events,
   required List<Aravt> participatingAravts,
   required GameState gameState,
 }) async {
   print(
       "Starting Tournament: $name with ${participatingAravts.length} aravts.");


   final Map<TournamentEventType, EventResult> results = {};
   final Map<String, int> standings = {
     for (var a in participatingAravts) a.id: 0
   };


   for (final eventType in events) {
     // print("Running event: ${eventType.name}");
     EventResult? result;
     switch (eventType) {
       case TournamentEventType.archery:
         result = _runArchery(participatingAravts, gameState);
         break;
       case TournamentEventType.horseRace:
         result = _runHorseRace(participatingAravts, gameState);
         break;
       case TournamentEventType.wrestling:
         result = _runWrestling(participatingAravts, gameState);
         break;
       case TournamentEventType.horseArchery:
         result = _runHorseArchery(participatingAravts, gameState);
         break;
       case TournamentEventType.buzkashi:
         result = _runBuzkashi(participatingAravts, gameState);
         break;
     }


     if (result != null) {
       results[eventType] = result;
       _updateStandings(standings, result, eventType, gameState);
     }
   }


   String? winnerId;
   int maxScore = -1;
   standings.forEach((aravtId, score) {
     if (score > maxScore) {
       maxScore = score;
       winnerId = aravtId;
     }
   });


   return TournamentResult(
     name: name,
     date: date.copy(),
     eventResults: results,
     finalAravtStandings: standings,
     winnerAravtId: winnerId,
   );
 }


 void _updateStandings(Map<String, int> standings, EventResult result,
     TournamentEventType type, GameState gameState) {
   void award(String aravtId, int points) {
     standings[aravtId] = (standings[aravtId] ?? 0) + points;
   }


   const Map<int, int> individualPoints = {
     0: 50,
     1: 30,
     2: 20,
     3: 15,
     4: 10
   };
   const Map<int, int> teamPoints = {0: 100, 1: 60, 2: 40, 3: 20};


   if (result is ScoreBasedEventResult ||
       result is RaceEventResult ||
       result is WrestlingEventResult) {
     List<int> rankings = (result is ScoreBasedEventResult)
         ? result.rankings
         : (result is RaceEventResult)
             ? result.rankings
             : (result as WrestlingEventResult).rankings;


     for (int i = 0; i < min(rankings.length, 5); i++) {
       int points = individualPoints[i] ?? 5;
       final soldier = _findSoldierAnywhere(rankings[i], gameState);
       if (soldier != null) {
         award(soldier.aravt, points);
       }
     }
   } else if (result is BuzkashiEventResult) {
     for (int i = 0; i < min(result.rankings.length, 4); i++) {
       award(result.rankings[i], teamPoints[i] ?? 10);
     }
   }
 }


 // --- HELPER: Find soldier across ALL lists to avoid "Unknown" ---
 Soldier? _findSoldierAnywhere(int id, GameState gameState) {
   // Try the fast lookup first
   var s = gameState.findSoldierById(id);
   if (s != null) return s;


   // If not found, perform exhaustive search
   final allLists = [
     gameState.horde,
     gameState.npcHorde1,
     gameState.npcHorde2,
     gameState.garrisonSoldiers,
   ];
   for (var list in allLists) {
     for (var soldier in list) {
       if (soldier.id == id) return soldier;
     }
   }
   return null;
 }


 List<Soldier> _getAllSoldiers(List<Aravt> aravts, GameState gameState) {
   List<Soldier> participants = [];
   for (var aravt in aravts) {
     for (var id in aravt.soldierIds) {
       final s = _findSoldierAnywhere(id, gameState);
       if (s != null && s.status == SoldierStatus.alive && !s.isImprisoned) {
         participants.add(s);
       }
     }
   }
   return participants;
 }


 // --- INDIVIDUAL EVENTS ---


 // [GEMINI-UPDATED] Archery: 30 arrows, 0-10 points each to reduce ties
 ScoreBasedEventResult _runArchery(List<Aravt> aravts, GameState gameState) {
   final Map<int, int> scores = {};
   final List<Soldier> participants = _getAllSoldiers(aravts, gameState);


   for (final soldier in participants) {
     int totalScore = 0;
     // 30 arrows total (standard round is often 3 ends of 10 arrows or similar)
     for (int i = 0; i < 30; i++) {
       // Base accuracy from skills
       // Perception is key for spotting at 300m, Archery skill for the shot itself.
       double baseAccuracy = (soldier.longRangeArcherySkill * 6.0) +
           (soldier.perception * 3.0) +
           (soldier.patience * 1.0);


       // Add variance (+/- 25 to allow for wind/luck)
       double shotQuality = baseAccuracy + (_random.nextInt(51) - 25);


       // Convert to 0-10 score.
       // A perfect score of 100 base accuracy + 25 luck = 125 / 12.5 = ~10 points.
       int arrowScore = (shotQuality / 12.5).floor().clamp(0, 10);
       totalScore += arrowScore;
     }
     scores[soldier.id] = totalScore;
   }


   // Sort descending by score.
   // Dart's sort is stable, so initial ties might remain, but with 300 max points it's less likely.
   final rankings = scores.keys.toList()
     ..sort((a, b) => scores[b]!.compareTo(scores[a]!));


   return ScoreBasedEventResult(scores: scores, rankings: rankings);
 }


 // [GEMINI-UPDATED] Horse Race: Names horses, uses new entry model
 RaceEventResult _runHorseRace(List<Aravt> aravts, GameState gameState) {
   final List<RaceResultEntry> entries = [];
   final List<Soldier> participants = _getAllSoldiers(aravts, gameState);


   for (final soldier in participants) {
     InventoryItem? horseItem;
     try {
       horseItem = soldier.equippedItems.values
           .firstWhere((i) => i.templateId == 'mnt_horse');
     } catch (e) {
       // No horse found
     }


     double horseSpeed = 5.0;
     String horseName = "On Foot";


     if (horseItem != null) {
       // [GEMINI-NEW] Name nameless horses if they have generic names
       if (horseItem.name == 'Steppe Horse' ||
           horseItem.name.contains('Quality Steppe Horse')) {
         // Generate a new name.
         // Note: In a real persistent system, we'd update the item itself.
         // For this tournament simulation, we'll just use it for the report.
         // [GEMINI-FIX] Use PUBLIC method now
         horseName = ItemDatabase.getRandomHorseName();
       } else {
         horseName = horseItem.name;
       }


       // Cast to Mount to get actual speed if possible, else estimate
       if (horseItem is Mount) {
         horseSpeed = (horseItem as Mount).speed.toDouble() +
             3.0; // Base speed + mount stat
       } else {
         horseSpeed = 8.0 + _random.nextDouble() * 2.0;
       }
     }


     double baseTime = 300.0; // 5 minutes for 5km
     double modifiers = (soldier.horsemanship * 2.5) +
         (soldier.animalHandling * 1.0) +
         (horseSpeed * 4.0) +
         (_random.nextDouble() * 15.0);


     double finalTime = baseTime * (100.0 / (40.0 + modifiers));


     entries.add(RaceResultEntry(
         soldierId: soldier.id, horseName: horseName, time: finalTime));
   }


   // Sort entries by time (ascending)
   entries.sort((a, b) => a.time.compareTo(b.time));


   // Create simple rankings list for points calculation
   final rankings = entries.map((e) => e.soldierId).toList();


   return RaceEventResult(entries: entries, rankings: rankings);
 }


 ScoreBasedEventResult _runHorseArchery(
     List<Aravt> aravts, GameState gameState) {
   final Map<int, int> scores = {};
   final List<Soldier> participants = _getAllSoldiers(aravts, gameState);


   for (final soldier in participants) {
     int totalScore = 0;
     // 15 targets (3 runs of 5)
     for (int i = 0; i < 15; i++) {
       double hitChance = (soldier.mountedArcherySkill * 6.0) +
           (soldier.horsemanship * 3.0) +
           (_random.nextInt(40) - 20);


       if (hitChance > 85)
         totalScore += 10;
       else if (hitChance > 65)
         totalScore += 7;
       else if (hitChance > 45)
         totalScore += 4;
       else if (hitChance > 25) totalScore += 1;
     }
     scores[soldier.id] = totalScore;
   }
   final rankings = scores.keys.toList()
     ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
   return ScoreBasedEventResult(scores: scores, rankings: rankings);
 }


 // --- BRACKET EVENTS ---


 WrestlingEventResult _runWrestling(List<Aravt> aravts, GameState gameState) {
   List<int> currentRoundSoldiers =
       _getAllSoldiers(aravts, gameState).map((s) => s.id).toList();
   currentRoundSoldiers.shuffle(_random);


   List<WrestlingRound> rounds = [];
   int roundNum = 1;
   while (currentRoundSoldiers.length > 1) {
     List<WrestlingMatch> matches = [];
     List<int> nextRoundSoldiers = [];


     if (currentRoundSoldiers.length % 2 != 0) {
       // Give a bye to the last one randomly
       nextRoundSoldiers.add(currentRoundSoldiers.removeLast());
     }


     for (int i = 0; i < currentRoundSoldiers.length; i += 2) {
       final s1 = _findSoldierAnywhere(currentRoundSoldiers[i], gameState)!;
       final s2 = _findSoldierAnywhere(currentRoundSoldiers[i + 1], gameState)!;


       double s1Power = s1.strength * 2.0 +
           s1.stamina * 1.0 +
           (s1.bodyHealthCurrent * 0.5) +
           _random.nextInt(15);
       double s2Power = s2.strength * 2.0 +
           s2.stamina * 1.0 +
           (s2.bodyHealthCurrent * 0.5) +
           _random.nextInt(15);


       int winnerId = (s1Power >= s2Power) ? s1.id : s2.id;
       matches.add(WrestlingMatch(
           soldier1Id: s1.id, soldier2Id: s2.id, winnerId: winnerId));
       nextRoundSoldiers.add(winnerId);
     }
     rounds.add(WrestlingRound(name: "Round $roundNum", matches: matches));
     currentRoundSoldiers = nextRoundSoldiers;
     roundNum++;
   }


   List<int> rankings = [];
   if (currentRoundSoldiers.isNotEmpty) rankings.add(currentRoundSoldiers[0]);


   return WrestlingEventResult(rounds: rounds, rankings: rankings);
 }


 BuzkashiEventResult _runBuzkashi(List<Aravt> aravts, GameState gameState) {
   List<String> currentRoundAravts = aravts.map((a) => a.id).toList();
   currentRoundAravts.shuffle(_random);


   List<BuzkashiRound> rounds = [];
   int roundNum = 1;


   while (currentRoundAravts.length > 1) {
     List<BuzkashiMatch> matches = [];
     List<String> nextRoundAravts = [];


     if (currentRoundAravts.length % 2 != 0) {
       nextRoundAravts.add(currentRoundAravts.removeLast());
     }


     for (int i = 0; i < currentRoundAravts.length; i += 2) {
       final t1 = gameState.findAravtById(currentRoundAravts[i])!;
       final t2 = gameState.findAravtById(currentRoundAravts[i + 1])!;


       double getTeamPower(Aravt aravt) {
         double power = 0;
         for (var id in aravt.soldierIds) {
           final s = _findSoldierAnywhere(id, gameState);
           if (s != null && s.status == SoldierStatus.alive) {
             power +=
                 (s.spearSkill * 1.5) + s.horsemanship + (s.strength * 0.5);
           }
         }
         return power / max(1, aravt.soldierIds.length);
       }


       double p1 = getTeamPower(t1);
       double p2 = getTeamPower(t2);


       int score1 = 0;
       int score2 = 0;
       Map<int, int> goalScorers = {};


       // 5 chukkas
       for (int chukka = 0; chukka < 5; chukka++) {
         double advantage = (p1 - p2) / 10.0;
         double roll = _random.nextDouble() * 100;


         if (roll < (15 + advantage)) {
           score1++;
           _assignGoal(t1, goalScorers, gameState);
         } else if (roll > (85 + advantage)) {
           score2++;
           _assignGoal(t2, goalScorers, gameState);
         }
       }


       if (score1 == score2) {
         if (_random.nextBool()) {
           score1++;
           _assignGoal(t1, goalScorers, gameState);
         } else {
           score2++;
           _assignGoal(t2, goalScorers, gameState);
         }
       }


       matches.add(BuzkashiMatch(
           aravt1Id: t1.id,
           aravt2Id: t2.id,
           score1: score1,
           score2: score2,
           goalScorers: goalScorers));
       nextRoundAravts.add(score1 > score2 ? t1.id : t2.id);
     }
     rounds.add(BuzkashiRound(name: "Round $roundNum", matches: matches));
     currentRoundAravts = nextRoundAravts;
     roundNum++;
   }


   return BuzkashiEventResult(rounds: rounds, rankings: currentRoundAravts);
 }


 void _assignGoal(Aravt team, Map<int, int> scorers, GameState gameState) {
   List<Soldier> capableScorers = [];
   for (var id in team.soldierIds) {
     final s = _findSoldierAnywhere(id, gameState);
     if (s != null && s.status == SoldierStatus.alive && s.spearSkill >= 3) {
       capableScorers.add(s);
     }
   }


   if (capableScorers.isEmpty) return;


   double totalWeight = capableScorers.fold(
       0, (sum, s) => sum + s.spearSkill + s.horsemanship);
   double roll = _random.nextDouble() * totalWeight;
   double currentWeight = 0;


   for (final s in capableScorers) {
     currentWeight += s.spearSkill + s.horsemanship;
     if (roll < currentWeight) {
       scorers[s.id] = (scorers[s.id] ?? 0) + 1;
       return;
     }
   }
   scorers[capableScorers.first.id] =
       (scorers[capableScorers.first.id] ?? 0) + 1;
 }
}

