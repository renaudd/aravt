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

// lib/models/material_flow.dart

import 'package:aravt/models/game_date.dart';

enum MaterialType {
  ironOre,
  iron,
  weapon,
  wood,
  lumber,
  arrow,
  milk,
  cheese,
  hide,
  leather,
  meat,
  grain,
  flour,
  bread,
}

enum MaterialEndState {
  consumed,
  lost,
  traded,
  equipped,
  stockpiled,
  spoiled,
}

class FabricationTarget {
  final int targetReserve;
  final double processingRatio; // 0.0 to 1.0

  FabricationTarget({
    required this.targetReserve,
    required this.processingRatio,
  });

  Map<String, dynamic> toJson() => {
        'targetReserve': targetReserve,
        'processingRatio': processingRatio,
      };

  factory FabricationTarget.fromJson(Map<String, dynamic> json) {
    return FabricationTarget(
      targetReserve: json['targetReserve'] as int,
      processingRatio: (json['processingRatio'] as num).toDouble(),
    );
  }
}

class MaterialFlowEntry {
  final GameDate date;
  final MaterialType material;
  final double quantity;
  final MaterialEndState endState;
  final int refinementLevel; // 0=raw, 1=processed, 2=fabricated, etc.
  final String? notes;

  MaterialFlowEntry({
    required this.date,
    required this.material,
    required this.quantity,
    required this.endState,
    required this.refinementLevel,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'material': material.name,
        'quantity': quantity,
        'endState': endState.name,
        'refinementLevel': refinementLevel,
        'notes': notes,
      };

  factory MaterialFlowEntry.fromJson(Map<String, dynamic> json) {
    return MaterialFlowEntry(
      date: GameDate.fromJson(json['date'] as Map<String, dynamic>),
      material: MaterialType.values.firstWhere(
        (e) => e.name == json['material'],
        orElse: () => MaterialType.ironOre,
      ),
      quantity: (json['quantity'] as num).toDouble(),
      endState: MaterialEndState.values.firstWhere(
        (e) => e.name == json['endState'],
        orElse: () => MaterialEndState.stockpiled,
      ),
      refinementLevel: json['refinementLevel'] as int,
      notes: json['notes'] as String?,
    );
  }
}
