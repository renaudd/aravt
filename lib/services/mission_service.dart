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

import 'package:aravt/models/mission_models.dart';
import 'package:aravt/providers/game_state.dart';

class MissionService {
  static void assignMission(GameState gameState, Mission mission) {
    gameState.missions.add(mission);
    // Update Aravt task
    // final aravt =
    //     gameState.aravts.firstWhere((a) => a.id == mission.assignedAravtId);
    // For now, we set it to a placeholder task or handle it in NextTurnService
    // aravt.task = ...
  }

  static void cancelMission(GameState gameState, String missionId) {
    gameState.missions.removeWhere((m) => m.id == missionId);
    // Reset Aravt task
  }

  static void updateMissionStatus(
      GameState gameState, String missionId, MissionStatus newStatus) {
    final missionIndex =
        gameState.missions.indexWhere((m) => m.id == missionId);
    if (missionIndex != -1) {
      final oldMission = gameState.missions[missionIndex];
      gameState.missions[missionIndex] = Mission(
        id: oldMission.id,
        type: oldMission.type,
        assignedAravtId: oldMission.assignedAravtId,
        status: newStatus,
        startDate: oldMission.startDate,
        tradeData: oldMission.tradeData,
        emissaryData: oldMission.emissaryData,
      );
    }
  }
}
