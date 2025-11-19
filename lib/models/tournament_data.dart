import 'game_date.dart';


enum TournamentEventType {
 archery,
 horseRace,
 wrestling,
 horseArchery,
 buzkashi
}


// --- FUTURE EVENTS ---
class FutureTournament {
 final String name;
 final GameDate date;
 final String description;
 final List<TournamentEventType> events;
 final bool isCritical;


 FutureTournament({
   required this.name,
   required this.date,
   required this.description,
   required this.events,
   this.isCritical = false,
 });


 Map<String, dynamic> toJson() => {
       'name': name,
       'date': date.toJson(),
       'description': description,
       'events': events.map((e) => e.name).toList(),
       'isCritical': isCritical,
     };


 factory FutureTournament.fromJson(Map<String, dynamic> json) {
   return FutureTournament(
     name: json['name'],
     date: GameDate.fromJson(json['date']),
     description: json['description'] ?? '',
     events: (json['events'] as List)
         .map((e) => TournamentEventType.values.firstWhere((v) => v.name == e))
         .toList(),
     isCritical: json['isCritical'] ?? false,
   );
 }
}


// --- PAST RESULTS ---
class TournamentResult {
 final String name;
 final GameDate date;
 final Map<TournamentEventType, EventResult> eventResults;
 final Map<String, int> finalAravtStandings;
 final String? winnerAravtId;


 TournamentResult({
   required this.name,
   required this.date,
   required this.eventResults,
   required this.finalAravtStandings,
   this.winnerAravtId,
 });


 Map<String, dynamic> toJson() => {
       'name': name,
       'date': date.toJson(),
       'eventResults':
           eventResults.map((k, v) => MapEntry(k.name, v.toJson())),
       'finalAravtStandings': finalAravtStandings,
       'winnerAravtId': winnerAravtId,
     };


 factory TournamentResult.fromJson(Map<String, dynamic> json) {
   return TournamentResult(
     name: json['name'],
     date: GameDate.fromJson(json['date']),
     eventResults: (json['eventResults'] as Map<String, dynamic>).map(
       (k, v) => MapEntry(
           TournamentEventType.values.firstWhere((e) => e.name == k),
           EventResult.fromJson(v)),
     ),
     finalAravtStandings:
         Map<String, int>.from(json['finalAravtStandings'] ?? {}),
     winnerAravtId: json['winnerAravtId'],
   );
 }
}


abstract class EventResult {
 Map<String, dynamic> toJson();
 static EventResult fromJson(Map<String, dynamic> json) {
   switch (json['__type']) {
     case 'ScoreBasedEventResult':
       return ScoreBasedEventResult.fromJson(json);
     case 'RaceEventResult':
       return RaceEventResult.fromJson(json);
     case 'WrestlingEventResult':
       return WrestlingEventResult.fromJson(json);
     case 'BuzkashiEventResult':
       return BuzkashiEventResult.fromJson(json);
     default:
       throw Exception('Unknown EventResult type: ${json['__type']}');
   }
 }
}


// For Archery, Horse Archery (points-based individual)
class ScoreBasedEventResult extends EventResult {
 final Map<int, int> scores;
 final List<int> rankings;
 ScoreBasedEventResult({required this.scores, required this.rankings});


 @override
 Map<String, dynamic> toJson() => {
       '__type': 'ScoreBasedEventResult',
       'scores': scores.map((k, v) => MapEntry(k.toString(), v)),
       'rankings': rankings,
     };
 factory ScoreBasedEventResult.fromJson(Map<String, dynamic> json) =>
     ScoreBasedEventResult(
       scores: (json['scores'] as Map<String, dynamic>)
           .map((k, v) => MapEntry(int.parse(k), v as int)),
       rankings: List<int>.from(json['rankings']),
     );
}


// [GEMINI-NEW] Race Result Entry to hold horse names
class RaceResultEntry {
 final int soldierId;
 final String horseName;
 final double time;


 RaceResultEntry(
     {required this.soldierId, required this.horseName, required this.time});


 Map<String, dynamic> toJson() =>
     {'sid': soldierId, 'hName': horseName, 'time': time};


 factory RaceResultEntry.fromJson(Map<String, dynamic> json) =>
     RaceResultEntry(
       soldierId: json['sid'],
       horseName: json['hName'] ?? 'Unknown Horse',
       time: (json['time'] as num).toDouble(),
     );
}


// [GEMINI-UPDATED] RaceEventResult uses new entry list
class RaceEventResult extends EventResult {
 final List<RaceResultEntry> entries;
 // We still keep rankings (list of soldier IDs) for easy point calculation
 final List<int> rankings;


 RaceEventResult({required this.entries, required this.rankings});


 @override
 Map<String, dynamic> toJson() => {
       '__type': 'RaceEventResult',
       'entries': entries.map((e) => e.toJson()).toList(),
       'rankings': rankings,
     };
 factory RaceEventResult.fromJson(Map<String, dynamic> json) =>
     RaceEventResult(
       entries: (json['entries'] as List)
           .map((e) => RaceResultEntry.fromJson(e))
           .toList(),
       rankings: List<int>.from(json['rankings']),
     );
}


// --- BRACKET MODELS ---
class WrestlingMatch {
 final int soldier1Id;
 final int soldier2Id;
 final int winnerId;
 WrestlingMatch(
     {required this.soldier1Id,
     required this.soldier2Id,
     required this.winnerId});
 Map<String, dynamic> toJson() =>
     {'p1': soldier1Id, 'p2': soldier2Id, 'win': winnerId};
 factory WrestlingMatch.fromJson(Map<String, dynamic> json) => WrestlingMatch(
     soldier1Id: json['p1'], soldier2Id: json['p2'], winnerId: json['win']);
}


class WrestlingRound {
 final String name;
 final List<WrestlingMatch> matches;
 WrestlingRound({required this.name, required this.matches});
 Map<String, dynamic> toJson() =>
     {'name': name, 'matches': matches.map((m) => m.toJson()).toList()};
 factory WrestlingRound.fromJson(Map<String, dynamic> json) => WrestlingRound(
     name: json['name'],
     matches: (json['matches'] as List)
         .map((m) => WrestlingMatch.fromJson(m))
         .toList());
}


class WrestlingEventResult extends EventResult {
 final List<WrestlingRound> rounds;
 final List<int> rankings;
 WrestlingEventResult({required this.rounds, required this.rankings});


 @override
 Map<String, dynamic> toJson() => {
       '__type': 'WrestlingEventResult',
       'rounds': rounds.map((r) => r.toJson()).toList(),
       'rankings': rankings,
     };
 factory WrestlingEventResult.fromJson(Map<String, dynamic> json) =>
     WrestlingEventResult(
         rounds: (json['rounds'] as List)
             .map((r) => WrestlingRound.fromJson(r))
             .toList(),
         rankings: List<int>.from(json['rankings']));
}


class BuzkashiMatch {
 final String aravt1Id;
 final String aravt2Id;
 final int score1;
 final int score2;
 final Map<int, int> goalScorers; // SoldierId -> goals scored
 BuzkashiMatch(
     {required this.aravt1Id,
     required this.aravt2Id,
     required this.score1,
     required this.score2,
     required this.goalScorers});
 String get winnerId => score1 > score2 ? aravt1Id : aravt2Id;


 Map<String, dynamic> toJson() => {
       't1': aravt1Id,
       't2': aravt2Id,
       's1': score1,
       's2': score2,
       'goals': goalScorers.map((k, v) => MapEntry(k.toString(), v))
     };
 factory BuzkashiMatch.fromJson(Map<String, dynamic> json) => BuzkashiMatch(
     aravt1Id: json['t1'],
     aravt2Id: json['t2'],
     score1: json['s1'],
     score2: json['s2'],
     goalScorers: (json['goals'] as Map<String, dynamic>)
         .map((k, v) => MapEntry(int.parse(k), v as int)));
}


class BuzkashiRound {
 final String name;
 final List<BuzkashiMatch> matches;
 BuzkashiRound({required this.name, required this.matches});
 Map<String, dynamic> toJson() =>
     {'name': name, 'matches': matches.map((m) => m.toJson()).toList()};
 factory BuzkashiRound.fromJson(Map<String, dynamic> json) => BuzkashiRound(
     name: json['name'],
     matches: (json['matches'] as List)
         .map((m) => BuzkashiMatch.fromJson(m))
         .toList());
}


class BuzkashiEventResult extends EventResult {
 final List<BuzkashiRound> rounds;
 final List<String> rankings;
 BuzkashiEventResult({required this.rounds, required this.rankings});


 @override
 Map<String, dynamic> toJson() => {
       '__type': 'BuzkashiEventResult',
       'rounds': rounds.map((r) => r.toJson()).toList(),
       'rankings': rankings,
     };
 factory BuzkashiEventResult.fromJson(Map<String, dynamic> json) =>
     BuzkashiEventResult(
         rounds: (json['rounds'] as List)
             .map((r) => BuzkashiRound.fromJson(r))
             .toList(),
         rankings: List<String>.from(json['rankings']));
}

