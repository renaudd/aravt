// lib/models/settlement_data.dart

import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/herd_data.dart'; 

enum SettlementGoal {
  Idle,
  ProduceFood, ProduceSupplies, ProduceWealth,
  TrainMilitia, RaidHorde, AttackHorde, SendEmissary,
  // --- NEW GOALS ---
  MineIron, SmeltIron, Blacksmithing,
  FarmingTilling, FarmingSowing, FarmingHarvest,
  ManageHerd,
}

SettlementGoal _settlementGoalFromName(String? name) {
  for (final value in SettlementGoal.values) {
    if (value.name == name) return value;
  }
  return SettlementGoal.Idle;
}

class Settlement {
  final String id;
  final String poiId;
  String name;

  // --- Population & Leadership ---
  String leaderSoldierId; 
  List<String> garrisonAravtIds; // Now a list to support multiple units
  int peasantPopulation;         

  // --- Agriculture & Industry ---
  Herd? cattleHerd;
  double grainStockpile;

  // --- Raw Materials ---
  double ironOreStockpile;
  double hidesStockpile;
  double woodStockpile;
  double waterStockpile; 

  // --- Processed Materials ---
  double smeltedIronStockpile;
  double leatherStockpile;

  // --- General Resources ---
  double foodStockpile;
  double suppliesStockpile;
  double treasureWealth;
  List<InventoryItem> inventory;

  // AI & Diplomacy
  SettlementGoal currentGoal;
  Map<String, RelationshipValues> diplomacy; 

  Settlement({
    required this.id,
    required this.poiId,
    required this.name,
    required this.leaderSoldierId,
    this.garrisonAravtIds = const [],
    this.peasantPopulation = 100,
    this.cattleHerd,
    this.grainStockpile = 500.0,
    this.ironOreStockpile = 0.0,
    this.hidesStockpile = 0.0,
    this.woodStockpile = 100.0,
    this.waterStockpile = 100.0,
    this.smeltedIronStockpile = 0.0,
    this.leatherStockpile = 0.0,
    this.foodStockpile = 200.0,
    this.suppliesStockpile = 100.0,
    this.treasureWealth = 50.0,
    this.inventory = const [],
    this.currentGoal = SettlementGoal.Idle,
    Map<String, RelationshipValues>? diplomacy,
  }) : this.diplomacy = diplomacy ?? {};

  // --- [GEMINI-FIX] Backwards-compatible getters to fix build errors ---
  // These allow old code to still read 'population' and 'militiaStrength'
  // even though the underlying data structure has changed.
  int get population => peasantPopulation;
  // Note: militiaStrength is now just an estimate based on number of garrison units * 20
  int get militiaStrength => garrisonAravtIds.length * 20;
  int get maxMilitia => peasantPopulation ~/ 4; // 25% rule
  // --- END HELPERS ---

  Map<String, dynamic> toJson() => {
    'id': id, 'poiId': poiId, 'name': name,
    'leaderSoldierId': leaderSoldierId,
    'garrisonAravtIds': garrisonAravtIds,
    'peasantPopulation': peasantPopulation,
    'cattleHerd': cattleHerd?.toJson(),
    'grainStockpile': grainStockpile,
    'ironOreStockpile': ironOreStockpile,
    'hidesStockpile': hidesStockpile,
    'woodStockpile': woodStockpile,
    'waterStockpile': waterStockpile,
    'smeltedIronStockpile': smeltedIronStockpile,
    'leatherStockpile': leatherStockpile,
    'foodStockpile': foodStockpile,
    'suppliesStockpile': suppliesStockpile,
    'treasureWealth': treasureWealth,
    'inventory': inventory.map((i) => i.toJson()).toList(),
    'currentGoal': currentGoal.name,
    'diplomacy': diplomacy.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'], poiId: json['poiId'], name: json['name'],
      leaderSoldierId: json['leaderSoldierId'] ?? 'unknown',
      garrisonAravtIds: (json['garrisonAravtIds'] as List<dynamic>? ?? []).cast<String>(),
      peasantPopulation: json['peasantPopulation'] ?? 100,
      cattleHerd: json['cattleHerd'] != null ? Herd.fromJson(json['cattleHerd']) : null,
      grainStockpile: (json['grainStockpile'] ?? 500.0).toDouble(),
      ironOreStockpile: (json['ironOreStockpile'] ?? 0.0).toDouble(),
      hidesStockpile: (json['hidesStockpile'] ?? 0.0).toDouble(),
      woodStockpile: (json['woodStockpile'] ?? 0.0).toDouble(),
      waterStockpile: (json['waterStockpile'] ?? 0.0).toDouble(),
      smeltedIronStockpile: (json['smeltedIronStockpile'] ?? 0.0).toDouble(),
      leatherStockpile: (json['leatherStockpile'] ?? 0.0).toDouble(),
      foodStockpile: (json['foodStockpile'] ?? 200.0).toDouble(),
      suppliesStockpile: (json['suppliesStockpile'] ?? 100.0).toDouble(),
      treasureWealth: (json['treasureWealth'] ?? 50.0).toDouble(),
      inventory: (json['inventory'] as List? ?? []).map((i) => InventoryItem.fromJson(i)).toList(),
      currentGoal: _settlementGoalFromName(json['currentGoal']),
      diplomacy: (json['diplomacy'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, RelationshipValues.fromJson(v))),
    );
  }

  RelationshipValues getRelationship(String hordeId) {
    if (!diplomacy.containsKey(hordeId)) {
      diplomacy[hordeId] = RelationshipValues(admiration: 2.5, respect: 2.5, fear: 1.0, loyalty: 0);
    }
    return diplomacy[hordeId]!;
  }
}

