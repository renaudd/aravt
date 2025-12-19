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

// models/yurt_data.dart

import 'package:flutter/material.dart'; // For Offset
import 'soldier_data.dart'; // To access Soldier wealth

// Enum to represent the quality/appearance of the yurt
enum YurtQuality { Destitute, Normal, Nice, Opulent }

YurtQuality _yurtQualityFromName(String? name) {
  for (final value in YurtQuality.values) {
    if (value.name == name) return value;
  }
  return YurtQuality.Normal;
}

class Yurt {
  final String id;
  final List<int> occupantIds;
  final YurtQuality quality;
  Offset? position;
  double? scale;

  Yurt({
    required this.id,
    required this.occupantIds,
    required this.quality,
    this.position,
    this.scale,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'occupantIds': occupantIds,
        'quality': quality.name,
        'position':
            position != null ? {'dx': position!.dx, 'dy': position!.dy} : null,
        'scale': scale,
      };

  factory Yurt.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? posJson = json['position'];
    return Yurt(
      id: json['id'],
      occupantIds: List<int>.from(json['occupantIds']),
      quality: _yurtQualityFromName(json['quality']),
      position: posJson != null ? Offset(posJson['dx'], posJson['dy']) : null,
      scale: json['scale'],
    );
  }

  // Helper function to determine quality based on occupants' wealth
  static YurtQuality calculateQuality(List<Soldier> occupants) {
    if (occupants.isEmpty) {
      return YurtQuality.Destitute;
    }

    double totalSupplies =
        occupants.fold(0.0, (sum, s) => sum + s.suppliesWealth);
    double totalTreasure =
        occupants.fold(0.0, (sum, s) => sum + s.treasureWealth);
    double avgSupplies = totalSupplies / occupants.length;
    double avgTreasure = totalTreasure / occupants.length; // Use average

    // Define wealth thresholds
    const double normalSuppliesThreshold = 50.0;
    const double niceSuppliesThreshold = 200.0;
    const double opulentSuppliesThreshold = 500.0;
    const double opulentTreasureThreshold = 100.0; // Avg treasure

    if (avgSupplies >= opulentSuppliesThreshold &&
        avgTreasure >= opulentTreasureThreshold) {
      return YurtQuality.Opulent;
    } else if (avgSupplies >= niceSuppliesThreshold) {
      return YurtQuality.Nice;
    } else if (avgSupplies >= normalSuppliesThreshold) {
      return YurtQuality.Normal;
    } else {
      return YurtQuality.Destitute;
    }
  }

  // Helper to get the correct image path based on quality
  String get imagePath {
    switch (quality) {
      case YurtQuality.Destitute:
        return 'assets/images/destitute_yurt.png';
      case YurtQuality.Normal:
        return 'assets/images/normal_yurt.png';
      case YurtQuality.Nice:
        return 'assets/images/nice_yurt.png';
      case YurtQuality.Opulent:
        return 'assets/images/opulent_yurt.png';
    }
  }

}
