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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ABOUT ARAVT',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/title.png', height: 100),
                  const SizedBox(height: 24),
                  Text(
                    'Version 1.0.0',
                    style: GoogleFonts.cinzel(
                        fontSize: 18, color: Colors.amber[100]),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Aravt is a historical strategy and social simulation game set on the Mongolian steppe. Lead your nomadic horde through a vast, procedurally generated world, managing resources, engaging in tactical combat, and building deep relationships with your soldiers.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Aravt',
                        applicationVersion: '1.0.0',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset('assets/images/title.png',
                              height: 50),
                        ),
                        applicationLegalese: '© 2025 Google LLC',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: Text('VIEW THIRD-PARTY NOTICES',
                        style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('BACK',
                        style: GoogleFonts.cinzel(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
