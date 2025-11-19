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

AravtDuty aravtDutyFromName(String? name, [AravtDuty fallback = AravtDuty.cook]) {
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

