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

