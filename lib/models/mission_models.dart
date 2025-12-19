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

import 'package:aravt/models/inventory_item.dart';

enum MissionType {
  trade,
  emissary,
}

enum MissionStatus {
  enRoute,
  atDestination,
  returning,
  completed,
  interrupted,
}

enum EmissaryTerm {
  demandTribute,
  requestAid,
  inviteTrade,
  recruitSoldiers,
  recruitAdvisors,
  learnAboutArea,
  learnNewTechnology,
  offerProtection,
  requestProtection,
  offerTruce,
  demandSubmission,
  learnRelations,
  offerAggressiveAlliance,
  offerDefensiveAlliance,
  proposeUnification,
  surrender,
  offerTribute,
  provideAid,
  presentGifts,
}

class TradeMissionData {
  final String destinationId;
  final List<InventoryItem> goods;
  final String? escortAravtId;

  TradeMissionData({
    required this.destinationId,
    required this.goods,
    this.escortAravtId,
  });

  Map<String, dynamic> toJson() => {
        'destinationId': destinationId,
        'goods': goods.map((e) => e.toJson()).toList(),
        'escortAravtId': escortAravtId,
      };

  factory TradeMissionData.fromJson(Map<String, dynamic> json) {
    return TradeMissionData(
      destinationId: json['destinationId'],
      goods: (json['goods'] as List)
          .map((e) => InventoryItem.fromJson(e))
          .toList(),
      escortAravtId: json['escortAravtId'],
    );
  }
}

class EmissaryMissionData {
  final String destinationId;
  final List<EmissaryTerm> terms;
  final String? escortAravtId;

  EmissaryMissionData({
    required this.destinationId,
    required this.terms,
    this.escortAravtId,
  });

  Map<String, dynamic> toJson() => {
        'destinationId': destinationId,
        'terms': terms.map((e) => e.name).toList(),
        'escortAravtId': escortAravtId,
      };

  factory EmissaryMissionData.fromJson(Map<String, dynamic> json) {
    return EmissaryMissionData(
      destinationId: json['destinationId'],
      terms: (json['terms'] as List)
          .map((e) => EmissaryTerm.values.firstWhere((t) => t.name == e))
          .toList(),
      escortAravtId: json['escortAravtId'],
    );
  }
}

class Mission {
  final String id;
  final MissionType type;
  final String assignedAravtId;
  final MissionStatus status;
  final DateTime startDate;
  final TradeMissionData? tradeData;
  final EmissaryMissionData? emissaryData;

  Mission({
    required this.id,
    required this.type,
    required this.assignedAravtId,
    required this.status,
    required this.startDate,
    this.tradeData,
    this.emissaryData,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'assignedAravtId': assignedAravtId,
        'status': status.name,
        'startDate': startDate.toIso8601String(),
        'tradeData': tradeData?.toJson(),
        'emissaryData': emissaryData?.toJson(),
      };

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'],
      type: MissionType.values.firstWhere((e) => e.name == json['type']),
      assignedAravtId: json['assignedAravtId'],
      status: MissionStatus.values.firstWhere((e) => e.name == json['status']),
      startDate: DateTime.parse(json['startDate']),
      tradeData: json['tradeData'] != null
          ? TradeMissionData.fromJson(json['tradeData'])
          : null,
      emissaryData: json['emissaryData'] != null
          ? EmissaryMissionData.fromJson(json['emissaryData'])
          : null,
    );
  }
}
