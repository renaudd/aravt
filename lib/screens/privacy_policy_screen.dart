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

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PRIVACY POLICY',
            style: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Effective Date: April 7, 2026'),
              const SizedBox(height: 16),
              _buildBodyText(
                  'Aravt is a historical strategy and social simulation game. We value your privacy and are committed to protecting any personal information you may provide while using the application.'),
              const SizedBox(height: 24),
              _buildSectionTitle('1. Information Collection'),
              _buildBodyText(
                  'Aravt does not collect or store any personal data from its users. The application does not require an account, and all game progress is stored locally on your device or via your platform\'s local storage.'),
              const SizedBox(height: 16),
              _buildSectionTitle('2. No Advertisements'),
              _buildBodyText(
                  'Aravt does not contain advertisements, and we do not track your behavior for marketing purposes.'),
              const SizedBox(height: 16),
              _buildSectionTitle('3. Third-Party Services'),
              _buildBodyText(
                  'This application does not share any data with third-party services. We do not use analytics or tracking cookies.'),
              const SizedBox(height: 16),
              _buildSectionTitle('4. Data Security'),
              _buildBodyText(
                  'Since no data is collected or transmitted, there is no risk of your personal data being compromised from our systems.'),
              const SizedBox(height: 16),
              _buildSectionTitle('5. Changes to This Policy'),
              _buildBodyText(
                  'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.'),
              const SizedBox(height: 16),
              _buildSectionTitle('6. Contact Us'),
              _buildBodyText(
                  'If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us through the Contact page in the game menu.'),
              const SizedBox(height: 48),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('BACK',
                      style: GoogleFonts.cinzel(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.cinzel(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.amber[100],
      ),
    );
  }

  Widget _buildBodyText(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: Colors.white.withOpacity(0.9),
      ),
    );
  }
}
