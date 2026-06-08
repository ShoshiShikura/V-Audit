import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/team.dart';
import '../db/database_helper.dart';
import 'company_name_screen.dart';
import '../screens/app_drawer.dart';
import '../services/session_manager.dart';

class AnimatedSavedRow extends StatelessWidget {
  final double opacity;
  const AnimatedSavedRow({super.key, required this.opacity});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text('All changes saved', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}

class SummaryTeamScreen extends StatefulWidget {
  final String documentId;
  final String userId;
  final String role;

  const SummaryTeamScreen({
    super.key,
    required this.documentId,
    required this.userId,
    required this.role,
  });

  @override
  State<SummaryTeamScreen> createState() => _SummaryTeamScreenState();
}

class _SummaryTeamScreenState extends State<SummaryTeamScreen> {
  List<Team> _teams = [];
  Team? _selectedTeam;
  final _typeController = TextEditingController();
  String _competency = 'Competent';
  List<String> _competencyFailures = [];
  bool _showSaved = false;
  bool _typeOfTeamRed = false;
  bool _ppeRed = false;
  double _savedOpacity = 0.0; // For animation
  DateTime? _auditDate;

  // Attendance auto-calculation
  int _absentCount = 0;
  String _manpowerWarning = '';

  // PPE checkboxes
  bool _safetyCone = true;
  bool _safetySignage = true;

  // Type of Team dropdown overlay
  final FocusNode _typeFocusNode = FocusNode();
  final LayerLink _typeFieldLink = LayerLink();
  OverlayEntry? _typeOverlayEntry;
  List<String> _typeOptions = [];
  List<String> _filteredTypeOptions = [];
  String _documentStatus = 'draft';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isLocked => SessionManager.isAdministrator(widget.role) || _documentStatus == 'pending' || _documentStatus == 'approved';

  @override
  void initState() {
    super.initState();
    _loadDocumentType();
    _loadTeams();
    _typeController.addListener(_autoSave);
    _typeController.addListener(_filterTypeOptions);
    _typeFocusNode.addListener(_handleTypeFocusChange);
  }

  @override
  void dispose() {
    _typeController.removeListener(_autoSave);
    _typeController.removeListener(_filterTypeOptions);
    _typeController.dispose();
    _typeFocusNode.dispose();
    _removeTypeOverlay();
    super.dispose();
  }

  Future<void> _loadDocumentType() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'documents',
      columns: ['type', 'createdDate', 'status'],
      where: 'id = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final type = (result.first['type'] as String? ?? '').toUpperCase();
      final createdDate = result.first['createdDate'] as String?;
      final status = result.first['status'] as String? ?? 'draft';
      setState(() {
        _documentStatus = status;
        _typeOptions = [
          '$type FIBER OVERHEAD',
          '$type FIBER UNDERGROUND',
        ];
        _filteredTypeOptions = List.from(_typeOptions);
        if (createdDate != null) {
          _auditDate = DateTime.tryParse(createdDate);
        }
      });
    }
  }

  // ── Type of Team overlay ──

  void _handleTypeFocusChange() {
    if (!_typeFocusNode.hasFocus) {
      _removeTypeOverlay();
    } else {
      _showTypeOverlay();
    }
  }

  void _showTypeOverlay() {
    _removeTypeOverlay();
    if (_filteredTypeOptions.isEmpty) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _typeOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: renderBox.size.width - 48,
          child: CompositedTransformFollower(
            link: _typeFieldLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredTypeOptions.length,
                  itemBuilder: (context, index) {
                    final option = _filteredTypeOptions[index];
                    return ListTile(
                      title: Text(option),
                      dense: true,
                      onTap: () => _onTypeSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_typeOverlayEntry!);
    }
  }

  void _removeTypeOverlay() {
    _typeOverlayEntry?.remove();
    _typeOverlayEntry = null;
  }

  void _filterTypeOptions() {
    final query = _typeController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTypeOptions = List.from(_typeOptions);
      } else {
        _filteredTypeOptions = _typeOptions
            .where((o) => o.toLowerCase().contains(query))
            .toList();
      }
      final exactMatch = _typeOptions.any((o) => o.toLowerCase() == query);
      if (_typeFocusNode.hasFocus &&
          _filteredTypeOptions.isNotEmpty &&
          !exactMatch) {
        _showTypeOverlay();
      } else {
        _removeTypeOverlay();
      }
    });
  }

  void _onTypeSelected(String type) {
    _typeController.text = type;
    _removeTypeOverlay();
    _typeFocusNode.unfocus();
    _autoSave();
  }

  Future<void> _loadTeams() async {
    final teams =
        await DatabaseHelper().getTeamsByDocumentId(widget.documentId);
    setState(() {
      _teams = teams;
      if (_teams.isNotEmpty && _selectedTeam == null) {
        _selectedTeam = _teams.first;
      }
    });
    if (_selectedTeam != null) {
      await _loadTeamSummary(_selectedTeam!);
    }
  }

  Future<void> _loadTeamSummary(Team team) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'summary_team',
      where: 'teamId = ?',
      whereArgs: [team.id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final data = result.first;
      _typeController.text =
          data['typeOfTeam'] != null ? data['typeOfTeam'] as String : '';
      final ppeText = data['ppe'] as String? ?? '';
      setState(() {
        _typeOfTeamRed = (data['typeOfTeamRed'] ?? 0) == 1;
        _ppeRed = (data['ppeRed'] ?? 0) == 1;
        // Restore checkbox states from saved PPE text
        _safetyCone = !ppeText.contains('SAFETY CONE');
        _safetySignage = !ppeText.contains('SIGNBOARD');
      });
    } else {
      _typeController.text = '';
      setState(() {
        _typeOfTeamRed = false;
        _ppeRed = false;
        _safetyCone = true;
        _safetySignage = true;
      });
    }
    await _calculateAttendance(team);
    await _calculateCompetency(team);
  }

  /// Queries all profiling persons for [team] and counts how many are absent.
  Future<void> _calculateAttendance(Team team) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'profiling_team',
      where: 'teamId = ?',
      whereArgs: [team.id],
    );

    int absent = 0;
    for (final row in rows) {
      final attendance = (row['attendance'] as String? ?? '').toLowerCase();
      if (attendance == 'not present') {
        absent++;
      }
    }

    setState(() {
      _absentCount = absent;
      if (absent > 0) {
        _typeOfTeamRed = true;
        _manpowerWarning =
            'NOT MEET MINIMUM MANPOWER REQUIREMENT. $absent PERSON NOT PRESENT DURING TEAM INSPECTION';
      } else {
        _typeOfTeamRed = false;
        _manpowerWarning = '';
      }
    });
    _updatePpeState();
    _saveTeamSummary();
  }

  /// Builds the PPE text and red flag from the two checkboxes.
  void _updatePpeState() {
    final issues = <String>[];
    if (!_safetyCone) {
      issues.add('SAFETY CONE DID NOT MEET MINIMUM REQUIREMENT.');
    }
    if (!_safetySignage) {
      issues.add('SIGNBOARD NOT COMPLY TO SAFETY SIGNAGE.');
    }
    setState(() {
      _ppeRed = issues.isNotEmpty;
    });
  }

  /// Returns the PPE text to persist based on checkbox state.
  String _buildPpeText() {
    final issues = <String>[];
    if (!_safetyCone) {
      issues.add('SAFETY CONE DID NOT MEET MINIMUM REQUIREMENT.');
    }
    if (!_safetySignage) {
      issues.add('SIGNBOARD NOT COMPLY TO SAFETY SIGNAGE.');
    }
    return issues.join('\n');
  }

  /// Queries all profiling persons for [team] and checks that at least 2
  /// members hold a non-expired date for every certificate type.
  Future<void> _calculateCompetency(Team team) async {
    if (_auditDate == null) return;
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'profiling_team',
      where: 'teamId = ?',
      whereArgs: [team.id],
    );

    // Certificate columns and their human-readable labels
    const certFields = {
      'ntsmpDate': 'NTSMP',
      'aespDate': 'AESP',
      'agtesDate': 'AGTES',
      'csmeDate': 'CSME',
      'oykDate': 'OYK',
      'ca2aDate': 'CA2A',
      'ca2cDate': 'CA2C',
    };

    final failures = <String>[];

    for (final entry in certFields.entries) {
      final field = entry.key;
      final label = entry.value;
      int validCount = 0;

      for (final row in rows) {
        final dateStr = row[field] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && !date.isBefore(_auditDate!)) {
            validCount++;
          }
        }
      }

      if (validCount < 2) {
        failures.add(label);
      }
    }

    final competency = failures.isEmpty ? 'Competent' : 'Not competent';
    setState(() {
      _competency = competency;
      _competencyFailures = failures;
    });
    // Persist the auto-calculated competency
    _saveTeamSummary();
  }

  Future<void> _saveTeamSummary() async {
    if (_selectedTeam == null) return;
    final db = await DatabaseHelper().database;
    final id = _selectedTeam!.id;
    final row = {
      'teamId': id,
      'typeOfTeam': _typeController.text,
      'ppe': _buildPpeText(),
      'competency': _competency,
      'typeOfTeamRed': _typeOfTeamRed ? 1 : 0,
      'ppeRed': _ppeRed ? 1 : 0,
    };
    await db.insert(
      'summary_team',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void _autoSave() {
    _saveTeamSummary();
    setState(() {
      _showSaved = true;
      _savedOpacity = 1.0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedOpacity = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: 'summary_team',
        userId: widget.userId,
        role: widget.role,
        documentId: widget.documentId,
        teams: _teams,
      ),
      appBar: AppBar(
        // No back arrow
        title: const Text('Summary Team'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeTypeOverlay();
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            // Locked banner
            if (_isLocked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _documentStatus == 'approved'
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _documentStatus == 'approved'
                          ? Icons.check_circle
                          : SessionManager.isAdministrator(widget.role)
                              ? Icons.visibility
                              : Icons.lock,
                      color: _documentStatus == 'approved'
                          ? Colors.green
                          : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        SessionManager.isAdministrator(widget.role)
                            ? 'Admin view: Read-only mode.'
                            : 'This document is $_documentStatus and cannot be edited.',
                        style: TextStyle(
                          color: _documentStatus == 'approved'
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Team', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<Team>(
              initialValue: _selectedTeam,
              items: _teams.map((team) {
                return DropdownMenuItem(
                  value: team,
                  child: Text(team.label),
                );
              }).toList(),
              onChanged: (team) async {
                setState(() => _selectedTeam = team);
                if (team != null) await _loadTeamSummary(team);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Dropdown',
              ),
            ),
            const SizedBox(height: 16),
            // Form content wrapper
            AbsorbPointer(
              absorbing: _isLocked,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Type of Team',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            CompositedTransformTarget(
              link: _typeFieldLink,
              child: TextFormField(
                controller: _typeController,
                focusNode: _typeFocusNode,
                maxLength: 255,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Search and select type...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.search),
                ),
                onTap: () {
                  if (_typeOptions.isNotEmpty) _showTypeOverlay();
                },
                onChanged: (val) => _autoSave(),
              ),
            ),
            // Manpower attendance status
            if (_absentCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _manpowerWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('PPE', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Meet safety cone requirement'),
                    value: _safetyCone,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() => _safetyCone = val ?? true);
                      _updatePpeState();
                      _autoSave();
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Comply to safety signage'),
                    value: _safetySignage,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() => _safetySignage = val ?? true);
                      _updatePpeState();
                      _autoSave();
                    },
                  ),
                ],
              ),
            ),
            if (_ppeRed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_safetyCone)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'SAFETY CONE DID NOT MEET MINIMUM REQUIREMENT.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (!_safetySignage)
                      Text(
                        'SIGNBOARD NOT COMPLY TO SAFETY SIGNAGE.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Competency',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _competency == 'Competent'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _competency == 'Competent'
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _competency == 'Competent'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _competency == 'Competent'
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _competency,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _competency == 'Competent'
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (_competencyFailures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...(_competencyFailures.map((cert) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'DOES NOT MEET MINIMUM $cert REQUIREMENT. MIN 2 $cert',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))),
                  ],
                  if (_competencyFailures.isEmpty && _selectedTeam != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'All certificates meet minimum requirement (≥2 valid).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_showSaved) AnimatedSavedRow(opacity: _savedOpacity),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'All changes are saved automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B1EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Previous: go back
                    },
                    child: const Text('Previous',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B1EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyNameScreen(
                            documentId: widget.documentId,
                            userId: widget.userId,
                            role: widget.role,
                          ),
                        ),
                      );
                    },
                    child: const Text('Next',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Add this table to your database (in DatabaseHelper._onCreate) ---
// await db.execute('''
//   CREATE TABLE summary_team (
//     teamId TEXT PRIMARY KEY,
//     typeOfTeam TEXT,
//     ppe TEXT,
//     competency TEXT
//   )
// ''');
