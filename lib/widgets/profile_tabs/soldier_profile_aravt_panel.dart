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
    final duties = AravtDuty.values;
    // Slightly larger font for horizontal headers
    final headerStyle = GoogleFonts.cinzel(
        color: const Color(0xFFE0D5C1),
        fontWeight: FontWeight.bold,
        fontSize: 11);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 48,
        columnSpacing: 25, // [GEMINI-FIX] More space between columns
        horizontalMargin: 10,
        columns: [
          DataColumn(label: Text('Soldier', style: headerStyle)),
          // [GEMINI-FIX] Removed RotatedBox, now horizontal
          ...duties
              .map((d) => DataColumn(label: Text(d.name, style: headerStyle))),
        ],
        rows: soldiers.map((s) {
          return DataRow(cells: [
            DataCell(Text(s.name,
                style: GoogleFonts.cinzel(
                    color: s.isPlayer ? const Color(0xFFE0D5C1) : Colors.white,
                    fontSize: 12))),
            ...duties.map((duty) {
              final isAssigned = aravt.dutyAssignments[duty] == s.id;

              // [GEMINI-FIX] Much higher opacity for visibility
              Color? cellColor;
              if (s.preferredDuties.contains(duty))
                cellColor = Colors.green.withValues(alpha: 0.3);
              else if (s.despisedDuties.contains(duty))
                cellColor = Colors.red.withValues(alpha: 0.3);

              return DataCell(Container(
                color: cellColor,
                alignment: Alignment.center,
                child: Checkbox(
                    value: isAssigned,
                    activeColor: const Color(0xFFE0D5C1),
                    checkColor: Colors.black,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          aravt.dutyAssignments[duty] = s.id;
                        } else if (aravt.dutyAssignments[duty] == s.id) {
                          aravt.dutyAssignments.remove(duty);
                        }
                      });
                    }),
              ));
            })
          ]);
        }).toList(),
      ),
    );
  }
}
