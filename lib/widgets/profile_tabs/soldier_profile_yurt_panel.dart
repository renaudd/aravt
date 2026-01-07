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

// widgets/profile_tabs/soldier_profile_yurt_panel.dart
import 'package:flutter/material.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:google_fonts/google_fonts.dart';

class SoldierProfileYurtPanel extends StatelessWidget {
  final Soldier soldier;
  const SoldierProfileYurtPanel({super.key, required this.soldier});

  @override
  Widget build(BuildContext context) {
    // TODO: This should show yurt location and list yurt-mates
    return Center(
      child: Text(
        'Yurt Panel for ${soldier.name}\n(Yurt ID: ${soldier.yurtId ?? 'None'})\n(UI Placeholder)',
        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );
  }
}
