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

// lib/services/tournament_service.dart
import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/game_data/item_templates.dart'; // For horse names
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/justification_event.dart';

class TournamentService {
  final Random _random = Random();

  void startTournament({
    required String name,
    required GameDate date,
    required List<TournamentEventType> events,
    required List<Aravt> participatingAravts,
    required GameState gameState,
  }) {
    print(
        "Starting Tournament: $name with ${participatingAravts.length} aravts.");

    // Create ActiveTournament
    gameState.activeTournament = ActiveTournament(
      name: name,
      startDate: date.copy(),
      events: events,
      participatingAravts: participatingAravts,
      currentDay: 1,
      dailyResults: {},
      currentStandings: {for (var a in participatingAravts) a.id: 0},
    );

    for (var aravt in participatingAravts) {
      if (aravt.task != null) {
        print("Cancelling task for Aravt ${aravt.id} due to tournament.");
        aravt.task = null;
      }
      aravt.persistentAssignment = null;
      aravt.persistentAssignmentLocationId = null;

      // Teleport to player camp (or just ensure they are "here")
      // This prevents "traveling" status during tournament
      final playerCamp = gameState.findPoiByIdWorld('camp-player');
      if (playerCamp != null && playerCamp.position != null) {
        aravt.hexCoords = playerCamp.position;
      }
    }

    gameState.logEvent(
      "The $name has begun! Day 1 events are starting.",
      category: EventCategory.games,
      severity: EventSeverity.high,
    );
  }

  Future<TournamentResult?> processDailyStage(GameState gameState) async {
    final active = gameState.activeTournament;
    if (active == null) return null;

    print(
        "TOURNAMENT DEBUG: Processing Day ${active.currentDay} of ${active.duration}.");

    // Check if tournament is over
    if (active.currentDay > active.duration) {
      print("TOURNAMENT DEBUG: Tournament duration exceeded. Concluding.");
      return _concludeTournament(gameState);
    }

    // Define Schedule
    List<TournamentEventType> todaysEvents = [];
    switch (active.currentDay) {
      case 1:
        if (active.events.contains(TournamentEventType.archery)) {
          todaysEvents.add(TournamentEventType.archery);
        }
        break;
      case 2:
        if (active.events.contains(TournamentEventType.horseArchery)) {
          todaysEvents.add(TournamentEventType.horseArchery);
        }
        break;
      case 3:
        if (active.events.contains(TournamentEventType.wrestling)) {
          todaysEvents.add(TournamentEventType.wrestling);
        }
        if (active.events.contains(TournamentEventType.horseRace)) {
          todaysEvents.add(TournamentEventType.horseRace);
        }
        break;
      case 4:
        if (active.events.contains(TournamentEventType.buzkashi)) {
          todaysEvents.add(TournamentEventType.buzkashi);
        }
        break;
    }

    // Run Events
    List<EventResult> dayResults = [];
    for (final eventType in todaysEvents) {
      EventResult? result;
      switch (eventType) {
        case TournamentEventType.archery:
          result = _runArchery(active.participatingAravts, gameState);
          break;
        case TournamentEventType.horseRace:
          result = _runHorseRace(active.participatingAravts, gameState);
          break;
        case TournamentEventType.wrestling:
          result = _runWrestling(active.participatingAravts, gameState);
          break;
        case TournamentEventType.horseArchery:
          result = _runHorseArchery(active.participatingAravts, gameState);
          break;
        case TournamentEventType.buzkashi:
          result = _runBuzkashi(active.participatingAravts, gameState);
          break;
      }

      if (result != null) {
        dayResults.add(result);
        _updateStandings(active.currentStandings, result, eventType, gameState);
      }
    }

    // Store Daily Results
    active.dailyResults[active.currentDay] = dayResults;

    // Generate Detailed Daily Report
    final StringBuffer report = StringBuffer();
    report.writeln(
        "=== DAY ${active.currentDay} OF ${active.duration} OF ${active.name.toUpperCase()} ===\n");

    int eventIndex = 0;
    for (final result in dayResults) {
      if (eventIndex < todaysEvents.length) {
        final eventType = todaysEvents[eventIndex];
        report.writeln(_formatEventReport(eventType, result, gameState));
        report.writeln("");
      }
      eventIndex++;
    }

    report.writeln("CURRENT STANDINGS:");
    final sortedStandings = active.currentStandings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (int i = 0; i < sortedStandings.length; i++) {
      final aravt = active.participatingAravts.firstWhere(
        (a) => a.id == sortedStandings[i].key,
        orElse: () => active.participatingAravts.first,
      );
      final score = sortedStandings[i].value;
      report.writeln("  ${i + 1}. ${aravt.id}: $score points");
    }

    // Store the formatted report
    active.dailyReports[active.currentDay] = report.toString();

    // Log as Critical Event (for immediate visibility)
    gameState.logEvent(
      "Day ${active.currentDay} of ${active.name} is complete. Check the Games Tab for details.",
      category: EventCategory.games,
      severity: EventSeverity.normal,
    );

    // Advance Day or Finish
    active.currentDay++;
    if (active.currentDay > active.duration) {
      return _concludeTournament(gameState);
    }

    return null; // Tournament continues
  }

  TournamentResult _concludeTournament(GameState gameState) {
    final active = gameState.activeTournament!;

    String? winnerId;
    int maxScore = -1;
    active.currentStandings.forEach((aravtId, score) {
      if (score > maxScore) {
        maxScore = score;
        winnerId = aravtId;
      }
    });

    // Flatten results for final report
    Map<TournamentEventType, EventResult> allResults = {};
    active.dailyResults.forEach((day, results) {
      for (var result in results) {
        if (result is ScoreBasedEventResult) {
          if (active.events.contains(TournamentEventType.archery) &&
              !allResults.containsKey(TournamentEventType.archery)) {
            allResults[TournamentEventType.archery] = result;
          } else {
            allResults[TournamentEventType.horseArchery] = result;
          }
        } else if (result is RaceEventResult) {
          allResults[TournamentEventType.horseRace] = result;
        } else if (result is WrestlingEventResult) {
          allResults[TournamentEventType.wrestling] = result;
        } else if (result is BuzkashiEventResult) {
          allResults[TournamentEventType.buzkashi] = result;
        }
      }
    });

    final result = TournamentResult(
      name: active.name,
      date: active.startDate,
      eventResults: allResults,
      finalAravtStandings: active.currentStandings,
      winnerAravtId: winnerId,
      dailyReports: active.dailyReports,
    );

    gameState.activeTournament = null; // Clear active state
    _distributeRewards(result, gameState);
    _updateChampions(result, gameState);
    return result;
  }

  void _updateChampions(TournamentResult result, GameState gameState) {
    // Update champions based on event results
    result.eventResults.forEach((type, eventResult) {
      if (type == TournamentEventType.archery ||
          type == TournamentEventType.horseArchery ||
          type == TournamentEventType.horseRace ||
          type == TournamentEventType.wrestling) {
        int? winnerId;
        if (eventResult is ScoreBasedEventResult &&
            eventResult.rankings.isNotEmpty) {
          winnerId = eventResult.rankings.first;
        } else if (eventResult is RaceEventResult &&
            eventResult.rankings.isNotEmpty) {
          winnerId = eventResult.rankings.first;
        } else if (eventResult is WrestlingEventResult &&
            eventResult.rankings.isNotEmpty) {
          winnerId = eventResult.rankings.first;
        }

        if (winnerId != null) {
          gameState.currentChampions[type] = winnerId;
          final soldier = gameState.findSoldierById(winnerId);
          if (soldier != null) {
            gameState.logEvent(
                "${soldier.name} is now the ${type.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ')} Champion!",
                category: EventCategory.games,
                severity: EventSeverity.high,
                soldierId: soldier.id);
          }
        }
      }
    });
  }

  void _distributeRewards(TournamentResult result, GameState gameState) {
    if (result.winnerAravtId == null) return;

    final winnerAravt = gameState.findAravtById(result.winnerAravtId!);
    if (winnerAravt == null) return;

    // 1. Give Horses to Winner Aravt members
    // For now, let's assume we have a pool of horses from expelled soldiers,
    // but since we don't track that pool yet, we'll just create new horses.
    // In a future update, we can track the "Horde Pool".
    for (var soldierId in winnerAravt.soldierIds) {
      final soldier = gameState.findSoldierById(soldierId);
      if (soldier != null) {
        final horse =
            ItemDatabase.createItemInstance('mnt_horse', forcedQuality: 'Good');
        if (horse != null) {
          soldier.personalInventory.add(horse);
          gameState.logEvent(
              "${soldier.name} received a fine horse named ${horse.name} as a tournament reward!",
              category: EventCategory.games,
              soldierId: soldier.id);
        }
      }
    }

    // 2. Give a special gift to the Captain of the winning Aravt
    final captain = gameState.findSoldierById(winnerAravt.captainId);
    if (captain != null) {
      final gift = ItemDatabase.createItemInstance('rel_ring',
          origin: 'Tournament Reward');
      if (gift != null) {
        captain.personalInventory.add(gift);
        gameState.logEvent(
            "${captain.name} received a golden ring for leading the winning Aravt!",
            category: EventCategory.games,
            soldierId: captain.id);
      }
    }
  }

  void _updateStandings(Map<String, int> standings, EventResult result,
      TournamentEventType type, GameState gameState) {
    void award(String aravtId, int points) {
      standings[aravtId] = (standings[aravtId] ?? 0) + points;
    }

    if (result is ScoreBasedEventResult) {
      // Archery or Horse Archery
      final bool isHorseArchery = type == TournamentEventType.horseArchery;
      for (int i = 0; i < result.rankings.length; i++) {
        final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
        if (soldier == null) continue;

        int points = 0;
        if (isHorseArchery) {
          // Horse Archery Scoring
          if (i == 0)
            points = 80;
          else if (i == 1)
            points = 40;
          else if (i == 2)
            points = 25;
          else if (i == 3)
            points = 15;
          else if (i == 4)
            points = 10;
          else if (i >= result.rankings.length - 3)
            points = -10;
          else if (i >= result.rankings.length - 7) points = -5;
        } else {
          // Archery Scoring
          if (i == 0)
            points = 70;
          else if (i == 1)
            points = 35;
          else if (i == 2)
            points = 20;
          else if (i == 3)
            points = 10;
          else if (i == 4)
            points = 5;
          else if (i >= result.rankings.length - 3)
            points = -10;
          else if (i >= result.rankings.length - 7) points = -5;
        }
        award(soldier.aravt, points);

        //  Add justifications for top/bottom performers
        if (i < 3) {
          // Praise
          double magnitude = 3.0 - i; // 3.0 for 1st, 2.0 for 2nd, 1.0 for 3rd
          soldier.pendingJustifications.add(JustificationEvent(
            type: JustificationType.praise,
            description:
                "Placed ${i + 1}${_getOrdinal(i + 1)} in the ${isHorseArchery ? 'Horse Archery' : 'Archery'} event.",
            magnitude: magnitude,
            expiryTurn: gameState.turn.turnNumber + 5,
          ));
        } else if (result.rankings.length > 5 &&
            i >= result.rankings.length - 3) {
          // Scold (only if more than 5 participants)
          double magnitude = 1.0; // Standard scold
          soldier.pendingJustifications.add(JustificationEvent(
            type: JustificationType.scold,
            description:
                "Placed ${i == result.rankings.length - 1 ? 'last' : 'near last'} in the ${isHorseArchery ? 'Horse Archery' : 'Archery'} event.",
            magnitude: magnitude,
            expiryTurn: gameState.turn.turnNumber + 5,
          ));
        }
      }
    } else if (result is RaceEventResult) {
      for (int i = 0; i < result.rankings.length; i++) {
        final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
        if (soldier == null) continue;

        int points = 0;
        if (i == 0)
          points = 40;
        else if (i == 1)
          points = 35;
        else if (i == 2)
          points = 20;
        else if (i == 3)
          points = 10;
        else if (i == 4)
          points = 5;
        else if (i >= result.rankings.length - 3)
          points = -10;
        else if (i >= result.rankings.length - 7) points = -5;
        award(soldier.aravt, points);

        //  Add justifications
        if (i < 3) {
          soldier.pendingJustifications.add(JustificationEvent(
            type: JustificationType.praise,
            description:
                "Placed ${i + 1}${_getOrdinal(i + 1)} in the Horse Race.",
            magnitude: 3.0 - i,
            expiryTurn: gameState.turn.turnNumber + 5,
          ));
        } else if (result.rankings.length > 5 &&
            i >= result.rankings.length - 3) {
          soldier.pendingJustifications.add(JustificationEvent(
            type: JustificationType.scold,
            description:
                "Placed ${i == result.rankings.length - 1 ? 'last' : 'near last'} in the Horse Race.",
            magnitude: 1.0,
            expiryTurn: gameState.turn.turnNumber + 5,
          ));
        }
      }
    } else if (result is WrestlingEventResult) {
      // 1st, 2nd, 3rd
      for (int i = 0; i < min(result.rankings.length, 3); i++) {
        final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
        if (soldier == null) continue;
        int points = 0;
        if (i == 0)
          points = 50;
        else if (i == 1)
          points = 25;
        else if (i == 2) points = 10;
        award(soldier.aravt, points);

        //  Add justifications
        soldier.pendingJustifications.add(JustificationEvent(
          type: JustificationType.praise,
          description: "Placed ${i + 1}${_getOrdinal(i + 1)} in Wrestling.",
          magnitude: 3.0 - i,
          expiryTurn: gameState.turn.turnNumber + 5,
        ));
      }
      // First round losers: -5 points
      for (final soldierId in result.firstRoundLoserIds) {
        final soldier = _findSoldierAnywhere(soldierId, gameState);
        if (soldier != null) {
          award(soldier.aravt, -5);
        }
      }
    } else if (result is BuzkashiEventResult) {
      for (int i = 0; i < min(result.rankings.length, 3); i++) {
        int points = 0;
        if (i == 0)
          points = 90;
        else if (i == 1)
          points = 30;
        else if (i == 2) points = 15;
        award(result.rankings[i], points);
      }
    }
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // Format detailed event report based on event type
  String _formatEventReport(
      TournamentEventType type, EventResult result, GameState gameState) {
    final StringBuffer report = StringBuffer();

    switch (type) {
      case TournamentEventType.archery:
        report.writeln("ARCHERY COMPETITION\n");
        if (result is ScoreBasedEventResult) {
          // Header
          report.writeln("Rank | Soldier | Aravt | Score | Points");
          report.writeln("-" * 60);

          for (int i = 0; i < result.rankings.length; i++) {
            final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
            if (soldier == null) continue;

            final aravt = gameState.findAravtById(soldier.aravt);
            final aravtName = aravt?.id ?? soldier.aravt;
            final score = result.scores[soldier.id] ?? 0;

            // Calculate points
            int points = 0;
            if (i == 0)
              points = 70;
            else if (i == 1)
              points = 35;
            else if (i == 2)
              points = 20;
            else if (i == 3)
              points = 10;
            else if (i == 4)
              points = 5;
            else if (i >= result.rankings.length - 3)
              points = -10;
            else if (i >= result.rankings.length - 7) points = -5;

            final rankStr = "${i + 1}.";
            final nameStr = soldier.name;
            final aravtStr = aravtName;
            final scoreStr = score.toString();
            final pointsStr = points.toString();

            report.writeln(
                "$rankStr | $nameStr | $aravtStr | $scoreStr | $pointsStr");
          }
          report.writeln("");
        }
        break;

      case TournamentEventType.horseRace:
        report.writeln("HORSE RACE\n");
        if (result is RaceEventResult) {
          // Header
          report.writeln("Rank | Horse | Soldier | Aravt | Time | Points");
          report.writeln("-" * 75);

          for (int i = 0; i < result.rankings.length; i++) {
            final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
            if (soldier == null) continue;

            final entry = result.entries.firstWhere(
                (e) => e.soldierId == soldier.id,
                orElse: () => RaceResultEntry(
                    soldierId: -1, horseName: 'Unknown', time: 9999));
            final aravt = gameState.findAravtById(soldier.aravt);
            final aravtName = aravt?.id ?? soldier.aravt;

            // Calculate points
            int points = 0;
            if (i == 0)
              points = 40;
            else if (i == 1)
              points = 35;
            else if (i == 2)
              points = 20;
            else if (i == 3)
              points = 10;
            else if (i == 4)
              points = 5;
            else if (i >= result.rankings.length - 3)
              points = -10;
            else if (i >= result.rankings.length - 7) points = -5;

            int minutes = (entry.time / 60).floor();
            double seconds = entry.time % 60;
            String timeText =
                "$minutes:${seconds.toStringAsFixed(2).padLeft(5, '0')}";

            final rankStr = "${i + 1}.";
            final horseStr = entry.horseName;
            final nameStr = soldier.name;
            final aravtStr = aravtName;
            final timeStr = timeText;
            final pointsStr = points.toString();

            report.writeln(
                "$rankStr | $horseStr | $nameStr | $aravtStr | $timeStr | $pointsStr");
          }
          report.writeln("");
        }
        break;

      case TournamentEventType.wrestling:
        report.writeln("WRESTLING TOURNAMENT\n");
        if (result is WrestlingEventResult) {
          // Tree-like representation for Wrestling
          report.writeln("Tournament Bracket:");
          for (final round in result.rounds) {
            report.writeln("\n--- ${round.name} ---");
            for (final match in round.matches) {
              final s1 = _findSoldierAnywhere(match.soldier1Id, gameState);
              final s2 = _findSoldierAnywhere(match.soldier2Id, gameState);
              final winner = _findSoldierAnywhere(match.winnerId, gameState);

              final s1Name = s1?.name ?? 'Unknown';
              final s2Name = s2?.name ?? 'Unknown';
              final winnerName = winner?.name ?? 'Unknown';

              // Visual bracket representation
              report.writeln("  $s1Name  ──┐");
              report.writeln("              ├──> $winnerName");
              report.writeln("  $s2Name  ──┘");
              report.writeln("");
            }
          }
          report.writeln("\n");

          report.writeln("Final Rankings:");
          for (int i = 0; i < result.rankings.length; i++) {
            final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
            if (soldier == null) continue;

            final aravt = gameState.findAravtById(soldier.aravt);
            final aravtName = aravt?.id ?? soldier.aravt;

            // Calculate points for report
            int points = 0;
            if (i == 0)
              points = 50;
            else if (i == 1)
              points = 25;
            else if (i == 2) points = 10;
            // First round losers not listed in rankings, but handled in text if needed.

            report.writeln(
                "${i + 1}. ${soldier.name} ($aravtName) - $points points");
          }
        }
        break;

      case TournamentEventType.horseArchery:
        report.writeln("HORSE ARCHERY COMPETITION\n");
        if (result is ScoreBasedEventResult) {
          // Header
          report.writeln(
              "Rank | Soldier | Horse | Aravt | Score | Time | Points");
          report.writeln("-" * 80);

          for (int i = 0; i < result.rankings.length; i++) {
            final soldier = _findSoldierAnywhere(result.rankings[i], gameState);
            if (soldier == null) continue;

            // Get horse name
            String horseName = "Unknown Horse";
            try {
              final horseItem = soldier.equippedItems.values
                  .firstWhere((i) => i.templateId == 'mnt_horse');
              horseName = horseItem.name;
            } catch (e) {
              // No horse equipped
            }

            final aravt = gameState.findAravtById(soldier.aravt);
            final aravtName = aravt?.id ?? soldier.aravt;
            final score = result.scores[soldier.id] ?? 0;

            // Calculate points
            int points = 0;
            if (i == 0)
              points = 80;
            else if (i == 1)
              points = 40;
            else if (i == 2)
              points = 25;
            else if (i == 3)
              points = 15;
            else if (i == 4)
              points = 10;
            else if (i >= result.rankings.length - 3)
              points = -10;
            else if (i >= result.rankings.length - 7) points = -5;

            // Flavor completion time (not tracked in logic, but requested for report)
            // Base time 60s + random variance based on score (higher score = slightly faster usually, but let's just randomize)
            double time =
                60.0 + (100 - score / 1.5) + (_random.nextDouble() * 10);
            String timeStr = "${time.toStringAsFixed(1)}s";

            final rankStr = "${i + 1}.";
            final nameStr = soldier.name;
            final horseStr = horseName;
            final aravtStr = aravtName;
            final scoreStr = score.toString();
            final timeStrCol = timeStr;
            final pointsStr = points.toString();

            report.writeln(
                "$rankStr | $nameStr | $horseStr | $aravtStr | $scoreStr | $timeStrCol | $pointsStr");
          }
          report.writeln("");
        }
        break;

      case TournamentEventType.buzkashi:
        report.writeln("BUZKASHI TOURNAMENT\n");
        if (result is BuzkashiEventResult) {
          // Tree-like representation for Buzkashi
          report.writeln("Tournament Bracket:");
          for (final round in result.rounds) {
            report.writeln("\n--- ${round.name} ---");
            for (final match in round.matches) {
              final aravt1 = gameState.findAravtById(match.aravt1Id);
              final aravt2 = gameState.findAravtById(match.aravt2Id);
              final captain1 = aravt1 != null
                  ? gameState.findSoldierById(aravt1.captainId)
                  : null;
              final captain2 = aravt2 != null
                  ? gameState.findSoldierById(aravt2.captainId)
                  : null;
              final team1Name =
                  captain1 != null ? "${captain1.name}'s Team" : match.aravt1Id;
              final team2Name =
                  captain2 != null ? "${captain2.name}'s Team" : match.aravt2Id;
              final winnerName =
                  match.winnerId == match.aravt1Id ? team1Name : team2Name;

              // Visual bracket representation
              report.writeln("  $team1Name (${match.score1})  ──┐");
              report
                  .writeln("                                ├──> $winnerName");
              report.writeln("  $team2Name (${match.score2})  ──┘");
              report.writeln("");

              if (match.goalScorers.isNotEmpty) {
                final scorerNames = match.goalScorers.entries.map((e) {
                  final scorer = _findSoldierAnywhere(e.key, gameState);
                  return "${scorer?.firstName ?? 'Unknown'} (${e.value})";
                }).join(", ");
                report.writeln("      Scorers: $scorerNames");
              }
            }
          }
          report.writeln("\n");

          report.writeln("Final Rankings:");
          for (int i = 0; i < result.rankings.length; i++) {
            final aravt = gameState.findAravtById(result.rankings[i]);
            final teamName = aravt?.id ?? result.rankings[i];

            int points = 0;
            if (i == 0)
              points = 90;
            else if (i == 1)
              points = 30;
            else if (i == 2) points = 15;

            report.writeln("${i + 1}. $teamName - $points points");
          }
        }
        break;
    }

    return report.toString();
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
    // Sort participants: Captains first, then by name
    participants.sort((a, b) {
      if (a.role == SoldierRole.aravtCaptain &&
          b.role != SoldierRole.aravtCaptain) {
        return -1;
      }
      if (a.role != SoldierRole.aravtCaptain &&
          b.role == SoldierRole.aravtCaptain) {
        return 1;
      }
      return a.name.compareTo(b.name);
    });
    return participants;
  }

  // --- INDIVIDUAL EVENTS ---

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
        //  Name nameless horses if they have generic names
        if (horseItem.name == 'Steppe Horse' ||
            horseItem.name.contains('Quality Steppe Horse')) {
          // Generate a new name.
          // Note: In a real persistent system, we'd update the item itself.
          // For this tournament simulation, we'll just use it for the report.

          horseName = ItemDatabase.getRandomHorseName();
        } else {
          horseName = horseItem.name;
        }

        // Cast to Mount to get actual speed if possible, else estimate
        if (horseItem is Mount) {
          horseSpeed =
              horseItem.speed.toDouble() + 3.0; // Base speed + mount stat
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

        if (hitChance > 85) {
          totalScore += 10;
        } else if (hitChance > 65) {
          totalScore += 7;
        } else if (hitChance > 45) {
          totalScore += 4;
        } else if (hitChance > 25) {
          totalScore += 1;
        }
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
        final s2 =
            _findSoldierAnywhere(currentRoundSoldiers[i + 1], gameState)!;

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

    // Track first round losers (from Round 1 matches)
    List<int> firstRoundLosers = [];
    if (rounds.isNotEmpty) {
      for (final match in rounds[0].matches) {
        firstRoundLosers.add(match.winnerId == match.soldier1Id
            ? match.soldier2Id
            : match.soldier1Id);
      }
    }

    return WrestlingEventResult(
        rounds: rounds,
        rankings: rankings,
        firstRoundLoserIds: firstRoundLosers);
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

    double totalWeight =
        capableScorers.fold(0, (sum, s) => sum + s.spearSkill + s.horsemanship);
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
