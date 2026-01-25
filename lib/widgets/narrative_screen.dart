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

// new narrative
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts for consistency

/// A reusable screen for displaying narrative text, with an optional image.
///
/// It takes a [title], [bodyText], an [onContinue] callback, and an
/// optional [imagePath] to display a scene image.
class NarrativeScreen extends StatelessWidget {
  final String title;
  final String bodyText;
  final VoidCallback onContinue;
  final String? imagePath;

  const NarrativeScreen({
    Key? key,
    required this.title,
    required this.bodyText,
    required this.onContinue,
    this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title of the scene
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    // Using Google Fonts
                    color: Colors.amber[100],
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (imagePath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 400, // Limit max height to prevent overflow
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          imagePath!,
                          fit: BoxFit.contain, // Changed from cover to contain
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 40), // Original spacing if no image

                // The main body text of the narrative
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    bodyText,
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.cinzel(
                      // Using Google Fonts
                      color: Colors.grey[300],
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24), // Spacer

                // The action button to proceed
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onContinue,
                  child: Text(
                    'Continue...',
                    style:
                        GoogleFonts.cinzel(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
