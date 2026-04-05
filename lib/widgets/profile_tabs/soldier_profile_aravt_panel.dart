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

// lib/widgets/profile_tabs/soldier_profile_aravt_panel.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/aravt_models.dart';

class SoldierProfileAravtPanel extends StatefulWidget {
  final Soldier soldier;
  const SoldierProfileAravtPanel({super.key, required this.soldier});

  @override
  State<SoldierProfileAravtPanel> createState() =>
      _SoldierProfileAravtPanelState();
}

class _SoldierProfileAravtPanelState extends State<SoldierProfileAravtPanel> {
  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final aravt = gameState.findAravtById(widget.soldier.aravt);

    if (aravt == null) {
      return Center(
          child: Text("No Aravt assigned.",
              style: GoogleFonts.cinzel(color: Colors.white54)));
    }

    final bool isPlayerAravt = aravt.soldierIds.contains(gameState.player?.id);
    final soldiers = aravt.soldierIds
        .map((id) => gameState.findSoldierById(id))
        .whereType<Soldier>()
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.soldier.desiresRoleAppointment)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.blue[900]!.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.blue[700]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${widget.soldier.name} has petitioned for a formal role. Assigning them a duty (preferably a preferred one in green) will satisfy them.",
                        style: GoogleFonts.cinzel(
                            fontSize: 12, color: Colors.blue[100]),
                      ),
                    ),
                  ],
                ),
              ),
            Text("Aravt: ${aravt.id}",
                style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Duty Roster",
                    style: GoogleFonts.cinzel(
                        color: const Color(0xFFE0D5C1), fontSize: 18)),
                if (isPlayerAravt)
                  Text("(Interact to Assign)",
                      style: GoogleFonts.cinzel(
                          color: Colors.white38, fontSize: 12)),
              ],
            ),
            const Divider(color: Colors.white24),
            if (isPlayerAravt)
              _buildEditableDutyMatrix(aravt, soldiers)
            else
              _buildReadOnlyDutyList(aravt, gameState),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyDutyList(Aravt aravt, GameState gameState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AravtDuty.values.map((duty) {
        final assigneeId = aravt.dutyAssignments[duty];
        final assignee = gameState.findSoldierById(assigneeId ?? -1);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text("${duty.name}: ",
                  style: GoogleFonts.cinzel(color: Colors.white70)),
              Text(assignee?.name ?? "Unassigned",
                  style: GoogleFonts.cinzel(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditableDutyMatrix(Aravt aravt, List<Soldier> soldiers) {
    const duties = AravtDuty.values;

    // Full duty names — staggered header renders them without clipping
    const Map<AravtDuty, String> dutyFullName = {
      AravtDuty.medic: 'Medic',
      AravtDuty.chronicler: 'Chronicler',
      AravtDuty.cook: 'Cook',
      AravtDuty.tuulch: 'Tuulch',
      AravtDuty.disciplinarian: 'Disciplinarian',
      AravtDuty.chaplain: 'Chaplain',
      AravtDuty.drillSergeant: 'Drill Sergeant',
      AravtDuty.lieutenant: 'Lieutenant',
      AravtDuty.equerry: 'Equerry',
    };

    final headerStyle = GoogleFonts.cinzel(
        color: const Color(0xFFE0D5C1),
        fontWeight: FontWeight.bold,
        fontSize: 9);

    return LayoutBuilder(builder: (context, constraints) {
      final double totalWidth = constraints.maxWidth;
      // Name column ~27%; remaining split evenly across 9 duty columns
      final double nameColWidth = totalWidth * 0.27;
      final double dutyColWidth = (totalWidth - nameColWidth) / duties.length;

      // Staggered two-row header: even-indexed duties in the top half,
      // odd-indexed in the bottom half.  Each label uses OverflowBox so the
      // full name is visible even though the column is narrower than the text;
      // because adjacent columns live in opposite rows they never collide.
      Widget headerRow() {
        const double rowHalf = 18.0; // half-height per stagger row
        const double totalHeaderH = rowHalf * 2;

        return SizedBox(
          height: totalHeaderH,
          child: Row(
            children: [
              // Soldier label — aligned to the centre of the full header height
              SizedBox(
                width: nameColWidth,
                height: totalHeaderH,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Soldier', style: headerStyle),
                ),
              ),
              ...duties.asMap().entries.map((entry) {
                final int i = entry.key;
                final AravtDuty d = entry.value;
                final bool isTop = i.isEven;
                return SizedBox(
                  width: dutyColWidth,
                  height: totalHeaderH,
                  child: Align(
                    alignment:
                        isTop ? Alignment.topCenter : Alignment.bottomCenter,
                    child: OverflowBox(
                      // Allow the text to be up to 3× the column width;
                      // neighbours are in the opposite row so no collision.
                      maxWidth: dutyColWidth * 3,
                      maxHeight: rowHalf,
                      alignment: Alignment.center,
                      child: Text(
                        dutyFullName[d] ?? d.name,
                        style: headerStyle,
                        textAlign: TextAlign.center,
                        softWrap: false,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }

      Widget dataRow(Soldier s) => Container(
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: nameColWidth,
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            s.name,
                            style: GoogleFonts.cinzel(
                                color: s.isPlayer
                                    ? const Color(0xFFE0D5C1)
                                    : Colors.white,
                                fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.desiresRoleAppointment)
                          const Padding(
                            padding: EdgeInsets.only(left: 2.0),
                            child: Icon(Icons.star_rate_rounded,
                                color: Colors.blueAccent, size: 10),
                          ),
                      ],
                    ),
                  ),
                ),
                ...duties.map((duty) {
                  final isAssigned = aravt.dutyAssignments[duty] == s.id;
                  Color? cellColor;
                  if (s.preferredDuties.contains(duty)) {
                    cellColor = Colors.green.withValues(alpha: 0.3);
                  } else if (s.despisedDuties.contains(duty)) {
                    cellColor = Colors.red.withValues(alpha: 0.3);
                  }
                  final isDisabled =
                      duty == AravtDuty.lieutenant && s.id == aravt.captainId;

                  return SizedBox(
                    width: dutyColWidth,
                    height: 36,
                    child: Container(
                      color: cellColor,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: isAssigned,
                          activeColor: const Color(0xFFE0D5C1),
                          checkColor: Colors.black,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: isDisabled
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      aravt.dutyAssignments[duty] = s.id;
                                      if (s.desiresRoleAppointment) {
                                        s.desiresRoleAppointment = false;
                                      }
                                    } else if (aravt.dutyAssignments[duty] ==
                                        s.id) {
                                      aravt.dutyAssignments.remove(duty);
                                    }
                                  });
                                },
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow(),
          const Divider(color: Colors.white24, height: 6),
          ...soldiers.map((s) => dataRow(s)),
          // Buffer so the last row scrolls fully clear of the nav widget
          const SizedBox(height: 80),
        ],
      );
    });
  }
}
