import 'dart:convert';


class LeaderboardEntry {
 final String playerName;
 final String title; // e.g. "Khan", "Exile"
 final int score;
 final int daysSurvived;
 final String deathReason;
 final DateTime dateAchieved;


 LeaderboardEntry({
   required this.playerName,
   required this.title,
   required this.score,
   required this.daysSurvived,
   required this.deathReason,
   required this.dateAchieved,
 });


 Map<String, dynamic> toJson() => {
       'playerName': playerName,
       'title': title,
       'score': score,
       'daysSurvived': daysSurvived,
       'deathReason': deathReason,
       'dateAchieved': dateAchieved.toIso8601String(),
     };


 factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
   return LeaderboardEntry(
     playerName: json['playerName'],
     title: json['title'] ?? 'Wanderer',
     score: json['score'],
     daysSurvived: json['daysSurvived'],
     deathReason: json['deathReason'],
     dateAchieved: DateTime.parse(json['dateAchieved']),
   );
 }
}


class LeaderboardData {
 List<LeaderboardEntry> entries = [];


 void addEntry(LeaderboardEntry entry) {
   entries.add(entry);
   // Sort descending by score
   entries.sort((a, b) => b.score.compareTo(a.score));
   // Keep top 20 only
   if (entries.length > 20) {
     entries = entries.sublist(0, 20);
   }
 }


 String toJsonString() =>
     jsonEncode({'entries': entries.map((e) => e.toJson()).toList()});


 static LeaderboardData fromJsonString(String jsonString) {
   final data = LeaderboardData();
   try {
     final json = jsonDecode(jsonString);
     if (json['entries'] != null) {
       data.entries = (json['entries'] as List)
           .map((e) => LeaderboardEntry.fromJson(e))
           .toList();
     }
   } catch (e) {
     print("Error parsing leaderboard: $e");
   }
   return data;
 }
}

