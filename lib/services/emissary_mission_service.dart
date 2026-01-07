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
import 'package:aravt/models/soldier_data.dart';

// final aravt = gameState.aravts.firstWhere((a) => a.id == mission.assignedAravtId);

class EmissaryMissionService {
  static double calculateSuccessProbability(
      List<EmissaryTerm> terms, Soldier emissary) {
    double baseProb = 0.5;
    // Adjust based on emissary skills (Charisma, Leadership, etc.)
    baseProb += (emissary.charisma - 5) * 0.05;
    baseProb += (emissary.leadership - 5) * 0.05;

    // Penalize for too many terms
    if (terms.length > 3) {
      baseProb -= (terms.length - 3) * 0.1;
    }

    // Term-specific adjustments (simplified for now)
    for (var term in terms) {
      switch (term) {
        case EmissaryTerm.demandTribute:
        case EmissaryTerm.demandSubmission:
          baseProb -= 0.2; // Harder
          break;
        case EmissaryTerm.offerTribute:
        case EmissaryTerm.provideAid:
          baseProb += 0.2; // Easier
          break;
        default:
          break;
      }
    }

    return baseProb.clamp(0.0, 1.0);
  }
}
