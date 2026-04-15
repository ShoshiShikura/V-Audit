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
  bool _showSaved = false;
  bool _typeOfTeamRed = false;
  bool _ppeRed = false;
  double _savedOpacity = 0.0; // For animation

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _typeController.addListener(_autoSave);
    _ppeController.addListener(_autoSave);
  }

  @override
  void dispose() {
    _typeController.removeListener(_autoSave);
    _ppeController.removeListener(_autoSave);
    _typeController.dispose();
    _ppeController.dispose();
    super.dispose();
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
        _competency = data['competency'] != null
            ? data['competency'] as String
            : 'Competent';
        _typeOfTeamRed = (data['typeOfTeamRed'] ?? 0) == 1;
        _ppeRed = (data['ppeRed'] ?? 0) == 1;
      });
    } else {
      _typeController.text = '';
      _ppeController.text = '';
      setState(() {
        _competency = 'Competent';
        _typeOfTeamRed = false;
        _ppeRed = false;
      });
    }
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
        onTap: () => FocusScope.of(context).unfocus(),
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
            TextFormField(
              controller: _typeController,
              maxLength: 255,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Input',
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
            RadioGroup<String>(
              groupValue: _competency,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _competency = val);
                  _autoSave();
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Competent',
                      title: const Text('Competent'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Not competent',
                      title: const Text('Not competent'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
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
