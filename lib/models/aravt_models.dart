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

// models/aravt_models.dart

/// Defines the intra-aravt duties that can be assigned by a captain.
enum AravtDuty {
  medic,
  chronicler,
  cook,
  tuulch,
  disciplinarian,
  chaplain,
  drillSergeant,
  lieutenant,
  equerry,
}

// --- Helper functions for serialization ---

AravtDuty aravtDutyFromName(String? name,
    [AravtDuty fallback = AravtDuty.cook]) {
  if (name == null) return fallback;
  for (final value in AravtDuty.values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

List<AravtDuty> aravtDutyListFromJson(List<dynamic>? jsonList) {
  if (jsonList == null) return [];
  return jsonList.map((name) => aravtDutyFromName(name as String?)).toList();
}
