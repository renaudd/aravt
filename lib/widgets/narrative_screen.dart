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
  final String? imagePath; // --- NEW: Optional image path ---

  const NarrativeScreen({
    Key? key,
    required this.title,
    required this.bodyText,
    required this.onContinue,
    this.imagePath, // --- NEW ---
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The title of the scene
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel( // Using Google Fonts
                  color: Colors.amber[100],
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // --- NEW: Image Display Logic ---
              if (imagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: AspectRatio(
                    // 1024 / 577 is approx 1.774
                    aspectRatio: 1024 / 577, 
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.asset(
                        imagePath!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 40), // Original spacing if no image
              // --- END NEW ---

              // The main body text of the narrative
              Expanded(
                child: SingleChildScrollView( // Added for long text
                  child: Text(
                    bodyText,
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.cinzel( // Using Google Fonts
                      color: Colors.grey[300],
                      fontSize: 18,
                      height: 1.5,
                    ),
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
                  style: GoogleFonts.cinzel(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
