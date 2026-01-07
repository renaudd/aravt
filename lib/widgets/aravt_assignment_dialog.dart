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

import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/interaction_models.dart'; // For DiplomaticTerm
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // For jsonEncode
import '../utils/string_utils.dart';
import 'trade_assignment_configuration.dart';

class AravtAssignmentDialog extends StatefulWidget {
  final String title;
  final String? description;
  final List<AravtAssignment> availableAssignments;
  final List<Aravt> assignedAravts;
  final List<Aravt> availableAravts;
  final Function(AravtAssignment, Set<String>, String?)? onConfirm;

  const AravtAssignmentDialog({
    super.key,
    required this.title,
    this.description,
    required this.availableAssignments,
    required this.assignedAravts,
    required this.availableAravts,
    required this.onConfirm,
  });

  @override
  State<AravtAssignmentDialog> createState() => _AravtAssignmentDialogState();
}

class _AravtAssignmentDialogState extends State<AravtAssignmentDialog> {
  AravtAssignment? _selectedAssignment;
  final Set<String> _selectedAravtIds = {};

  // Configuration State
  bool _isConfiguring = false;
  // Trade
  String? _tradeOptionsJson;
  // Emissary
  final Set<DiplomaticTerm> _selectedTerms = {};

  // Helper to check if we are in config phase
  bool get _activeConfig => _isConfiguring && _selectedAssignment != null;

  @override
  Widget build(BuildContext context) {
    bool canConfirm =
        _selectedAssignment != null && _selectedAravtIds.isNotEmpty;
    
    // For Trade/Emissary, we need to complete configuration
    if (_activeConfig) {
      if (_selectedAssignment == AravtAssignment.Trade) {
        // Always allow confirmation even if empty (sending empty trade is weird but allowed?)
        // Or check if _tradeOptionsJson is not null?
        canConfirm = true;
      } else if (_selectedAssignment == AravtAssignment.Emissary) {
        canConfirm = _selectedTerms.isNotEmpty;
      }
    }

    return AlertDialog(
      backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
      title: Text(
        _selectedAssignment == null
            ? widget.title
            : "Assign to: ${_selectedAssignment!.name}",
        style: GoogleFonts.cinzel(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedAssignment == null) ...[
                if (widget.description != null)
                  Text(widget.description!,
                      style: GoogleFonts.cinzel(color: Colors.white70)),
                const Divider(color: Colors.white24, height: 20),
                Text("Currently Assigned:",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
                if (widget.assignedAravts.isEmpty)
                  Text("None",
                      style: GoogleFonts.cinzel(
                          color: Colors.white54, fontStyle: FontStyle.italic)),
                ...widget.assignedAravts.map((aravt) => Text(
                      "- ${aravt.id} (${aravt.currentAssignment.name})",
                      style: GoogleFonts.cinzel(color: Colors.amber[200]),
                    )),
                const Divider(color: Colors.white24, height: 20),
                Text("Available Assignments:",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
                if (widget.availableAssignments.isEmpty)
                  Text("None",
                      style: GoogleFonts.cinzel(
                          color: Colors.white54, fontStyle: FontStyle.italic)),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: widget.availableAssignments.map((assignment) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: widget.availableAravts.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _selectedAssignment = assignment;
                              });
                            },
                      child: Text(assignment.name, style: GoogleFonts.cinzel()),
                    );
                  }).toList(),
                ),
                if (widget.availableAravts.isEmpty &&
                    widget.availableAssignments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("No aravts available (all are busy).",
                        style: GoogleFonts.cinzel(
                            color: Colors.red[300],
                            fontStyle: FontStyle.italic)),
                  ),
              ] else if (_activeConfig) ...[
                _buildConfigurationStep(context),
              ] else ...[
                // Step 2: Select Aravts
                Text("Select Aravts to assign:",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: ListView(
                    children: widget.availableAravts.map((aravt) {
                      return CheckboxListTile(
                        title: Text(aravt.id,
                            style: GoogleFonts.cinzel(color: Colors.white)),
                        subtitle: Text("Soldiers: ${aravt.soldierIds.length}",
                            style: GoogleFonts.cinzel(color: Colors.white70)),
                        value: _selectedAravtIds.contains(aravt.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedAravtIds.add(aravt.id);
                            } else {
                              _selectedAravtIds.remove(aravt.id);
                            }
                          });
                        },
                        checkColor: Colors.black,
                        activeColor: Colors.amber,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
      actions: [
        if (_selectedAssignment != null)
          TextButton(
            child:
                Text("Back", style: GoogleFonts.cinzel(color: Colors.white70)),
            onPressed: () {
              setState(() {
                if (_activeConfig) {
                  _isConfiguring = false;
                } else if (_selectedAssignment != null) {
                  _selectedAssignment = null;
                  _selectedAravtIds.clear();
                  _tradeOptionsJson = null;
                  _selectedTerms.clear();
                  _isConfiguring = false;
                }
              });
            },
          ),
        TextButton(
          child:
              Text("Close", style: GoogleFonts.cinzel(color: Colors.white70)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (_selectedAssignment != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: !canConfirm
                ? null
                : () {
                    if (!_activeConfig &&
                        _requiresConfig(_selectedAssignment)) {
                      setState(() {
                        _isConfiguring = true;
                      });
                    } else {
                      if (widget.onConfirm != null) {
                        String? optionData;
                        if (_selectedAssignment == AravtAssignment.Trade) {
                          optionData = _tradeOptionsJson;
                        } else if (_selectedAssignment ==
                            AravtAssignment.Emissary) {
                          optionData = jsonEncode({
                            'terms': _selectedTerms.map((e) => e.name).toList()
                          });
                        }

                        widget.onConfirm!(_selectedAssignment!,
                            _selectedAravtIds, optionData);
                        Navigator.of(context).pop();
                      }
                    }
                  },
            child: Text(
                _activeConfig
                    ? "Confirm Assignment"
                    : (_requiresConfig(_selectedAssignment)
                        ? "Next"
                        : "Confirm (${_selectedAravtIds.length})"),
                style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  bool _requiresConfig(AravtAssignment? assignment) {
    return assignment == AravtAssignment.Trade ||
        assignment == AravtAssignment.Emissary;
  }

  Widget _buildConfigurationStep(BuildContext context) {
    if (_selectedAssignment == AravtAssignment.Trade) {
      return SizedBox(
        height: 400, // Fixed height for the complex widget
        child: TradeAssignmentConfiguration(
          selectedAravtIds: _selectedAravtIds.toList(),
          onOptionsChanged: (json) {
            // We don't need setState here if it doesn't affect the UI immediately,
            // but we might want to validate "confirmed" state?
            // Actually, we probably want to enable/disable the confirm button based on selection?
            // For now, let's just store it.
            _tradeOptionsJson = json;
            // Force rebuild to check 'canConfirm' if we want validation?
            // TradeAssignmentConfiguration allows empty cargo, so maybe always valid?
            // If we want to enforce >0 cargo, we need to know.
            // For now, assume valid.
          },
        ),
      );
    } else if (_selectedAssignment == AravtAssignment.Emissary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Diplomatic Terms:",
              style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 250,
            child: ListView(
              children: DiplomaticTerm.values.map((term) {
                return CheckboxListTile(
                  title: Text(toTitleCase(term.name),
                      style: GoogleFonts.cinzel(color: Colors.white)),
                  value: _selectedTerms.contains(term),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedTerms.add(term);
                      } else {
                        _selectedTerms.remove(term);
                      }
                    });
                  },
                  checkColor: Colors.black,
                  activeColor: Colors.amber,
                );
              }).toList(),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
