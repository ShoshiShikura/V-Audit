import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/team.dart';
import '../db/database_helper.dart';
import 'company_name_screen.dart';
import '../screens/app_drawer.dart';

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
  final _ppeController = TextEditingController();
  String _competency = 'Competent';
  List<String> _competencyFailures = [];
  bool _showSaved = false;
  bool _typeOfTeamRed = false;
  bool _ppeRed = false;
  double _savedOpacity = 0.0; // For animation
  DateTime? _auditDate;

  // Type of Team dropdown overlay
  final FocusNode _typeFocusNode = FocusNode();
  final LayerLink _typeFieldLink = LayerLink();
  OverlayEntry? _typeOverlayEntry;
  List<String> _typeOptions = [];
  List<String> _filteredTypeOptions = [];
  String _documentType = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadDocumentType();
    _loadTeams();
    _typeController.addListener(_autoSave);
    _typeController.addListener(_filterTypeOptions);
    _ppeController.addListener(_autoSave);
    _typeFocusNode.addListener(_handleTypeFocusChange);
  }

  @override
  void dispose() {
    _typeController.removeListener(_autoSave);
    _typeController.removeListener(_filterTypeOptions);
    _ppeController.removeListener(_autoSave);
    _typeController.dispose();
    _ppeController.dispose();
    _typeFocusNode.dispose();
    _removeTypeOverlay();
    super.dispose();
  }

  Future<void> _loadDocumentType() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'documents',
      columns: ['type', 'createdDate'],
      where: 'id = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final type = (result.first['type'] as String? ?? '').toUpperCase();
      final createdDate = result.first['createdDate'] as String?;
      setState(() {
        _documentType = type;
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
      _ppeController.text = data['ppe'] != null ? data['ppe'] as String : '';
      setState(() {
        _typeOfTeamRed = (data['typeOfTeamRed'] ?? 0) == 1;
        _ppeRed = (data['ppeRed'] ?? 0) == 1;
      });
    } else {
      _typeController.text = '';
      _ppeController.text = '';
      setState(() {
        _typeOfTeamRed = false;
        _ppeRed = false;
      });
    }
    await _calculateCompetency(team);
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
    final result = await db.query(
      'summary_team',
      where: 'teamId = ?',
      whereArgs: [id],
      limit: 1,
    );
    final row = {
      'teamId': id,
      'typeOfTeam': _typeController.text,
      'ppe': _ppeController.text,
      'competency': _competency,
      'typeOfTeamRed': _typeOfTeamRed ? 1 : 0,
      'ppeRed': _ppeRed ? 1 : 0,
    };
    if (result.isEmpty) {
      await db.insert(
        'summary_team',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace, // Add this
      );
    } else {
      await db
          .update('summary_team', row, where: 'teamId = ?', whereArgs: [id]);
    }
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
            const SizedBox(height: 16),
            const Text('PPE', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _ppeController,
              maxLength: 255,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => _autoSave(),
            ),
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
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Highlight TYPE OF TEAM as red in PDF'),
              value: _typeOfTeamRed,
              onChanged: (val) {
                setState(() => _typeOfTeamRed = val ?? false);
                _autoSave();
              },
            ),
            CheckboxListTile(
              title: const Text('Highlight PPE as red in PDF'),
              value: _ppeRed,
              onChanged: (val) {
                setState(() => _ppeRed = val ?? false);
                _autoSave();
              },
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
