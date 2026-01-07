// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter_test/flutter_test.dart';
import 'package:aravt/services/tournament_service.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/area_data.dart'; // For HexCoordinates
import 'package:aravt/models/location_data.dart'; // For LocationType

void main() {
  group('TournamentService Lifecycle', () {
    late TournamentService tournamentService;
    late GameState gameState;

    setUp(() {
      tournamentService = TournamentService();
      gameState = GameState();
      // Initialize minimal game state
      // GameState usually initializes gameDate internally or via constructor,
      // but if it's a field we can set, we should check how it's defined.
      // Based on error: "The setter 'gameDate' isn't defined". It might be final or getter only?
      // Let's assume we can't set it easily without a proper constructor or it's initialized in constructor.
      // If we can't set it, we might need to rely on its default.
      // However, startTournament takes a date.

      gameState.aravts = [];
    });

    test('Tournament concludes correctly after duration', () async {
      // Setup
      final startDate = GameDate(1200, 4, 30, hour: 9); // Fixed: hour is named
      final aravt = Aravt(
        id: 'test_aravt',
        captainId: 1,
        soldierIds: [1],
        hexCoords: const HexCoordinates(0, 0),
        color: 'red',
        currentLocationType: LocationType.area,
        currentLocationId: 'steppe',
        // banner removed as it doesn't exist in constructor
      );

      tournamentService.startTournament(
        name: 'Test Tournament',
        date: startDate,
        events: [
          TournamentEventType.archery,
          TournamentEventType.horseArchery,
          TournamentEventType.wrestling,
          TournamentEventType.buzkashi
        ],
        participatingAravts: [aravt],
        gameState: gameState,
      );

      expect(gameState.activeTournament, isNotNull);
      expect(gameState.activeTournament!.currentDay, 1);

      // Day 1 Processing
      await tournamentService.processDailyStage(gameState);
      expect(gameState.activeTournament, isNotNull);
      expect(gameState.activeTournament!.currentDay, 2);

      // Day 2 Processing
      await tournamentService.processDailyStage(gameState);
      expect(gameState.activeTournament, isNotNull);
      expect(gameState.activeTournament!.currentDay, 3);

      // Day 3 Processing
      await tournamentService.processDailyStage(gameState);
      expect(gameState.activeTournament, isNotNull);
      expect(gameState.activeTournament!.currentDay, 4);

      // Day 4 Processing (Should conclude at end)
      await tournamentService.processDailyStage(gameState);

      // ASSERT: Tournament should be concluded (null)
      expect(gameState.activeTournament, isNull);
    });
  });
}
