// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
