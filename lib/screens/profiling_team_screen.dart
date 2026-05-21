import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/worker.dart';
import 'summary_team_screen.dart';
import '../db/database_helper.dart';
import 'document_team_screen.dart';
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

class ProfilingTeamScreen extends StatefulWidget {
  final Team team;
  final int maxPersons;
  final String userId;
  final String role;

  const ProfilingTeamScreen({
    super.key,
    required this.team,
    required this.maxPersons,
    required this.userId,
    required this.role,
  });

  @override
  State<ProfilingTeamScreen> createState() => _ProfilingTeamScreenState();
}

class _ProfilingTeamScreenState extends State<ProfilingTeamScreen> {
  int _selectedPerson = 1;
  String _attendance = 'Present';
  DateTime? _ntsmpDate;
  DateTime? _aespDate;
  DateTime? _agtesDate;
  DateTime? _csmeDate;
  DateTime? _oykDate;
  String _poleProficiency = 'Yes';
  DateTime? _ca2aDate;
  DateTime? _ca2cDate;
  DateTime? _auditDate; // Store audit date for expiry checking

  final _nameController = TextEditingController();
  final _icController = TextEditingController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _showSaved = false; // Add this for the saved message
  double _savedOpacity = 0.0; // For animation
  String _documentStatus = 'draft';

  // Worker picker functionality
  List<Worker> _workers = [];
  List<Worker> _filteredWorkers = [];
  final FocusNode _nameFocusNode = FocusNode();
  final LayerLink _nameFieldLink = LayerLink();
  OverlayEntry? _nameOverlayEntry;

  Future<void> _savePersonFields(int person, {bool showSaved = true}) async {
    final db = DatabaseHelper();
    final data = {
      'name': _nameController.text,
      'ic': _icController.text,
      'attendance': _attendance,
      'ntsmpDate': _ntsmpDate,
      'aespDate': _aespDate,
      'agtesDate': _agtesDate,
      'csmeDate': _csmeDate,
      'oykDate': _oykDate,
      'poleProficiency': _poleProficiency,
      'ca2aDate': _ca2aDate,
      'ca2cDate': _ca2cDate,
    };
    await db.saveProfilingPerson(
      documentId: widget.team.documentId,
      teamId: widget.team.id,
      personIndex: person,
      data: data,
    );
    if (mounted && showSaved) {
      setState(() => _showSaved = true);
      _savedOpacity = 1.0;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedOpacity = 0.0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAllTeams();
    _loadAuditDate();
    _loadDocumentStatus();
    _loadWorkers();
    _loadAndSetPersonFields(_selectedPerson);
    _nameController.addListener(_autoSaveCurrentPerson);
    _icController.addListener(_autoSaveCurrentPerson);
    _nameController.addListener(_filterWorkers);
    _nameFocusNode.addListener(_handleNameFocusChange);
  }

  Future<void> _loadDocumentStatus() async {
    final db = await DatabaseHelper().database;
    final docResult = await db.query('documents',
        where: 'id = ?', whereArgs: [widget.team.documentId], limit: 1);
    if (docResult.isNotEmpty) {
      if (mounted) {
        setState(() {
          _documentStatus = docResult.first['status'] as String? ?? 'draft';
        });
      }
    }
  }

  bool get _isLocked => SessionManager.isAdministrator(widget.role) || _documentStatus == 'pending' || _documentStatus == 'approved';

  // Load audit date from document
  Future<void> _loadAuditDate() async {
    final db = await DatabaseHelper().database;
    final docResult = await db.query('documents',
        where: 'id = ?', whereArgs: [widget.team.documentId], limit: 1);
    if (docResult.isNotEmpty) {
      setState(() {
        _auditDate = DateTime.parse(docResult.first['createdDate'] as String);
      });
    }
  }

  // Load and set fields for a person index, and update UI
  Future<void> _loadAndSetPersonFields(int person) async {
    final db = DatabaseHelper();
    final data = await db.getProfilingPerson(widget.team.id, person);
    if (mounted) {
      setState(() {
        _selectedPerson = person;
        _nameController.text = data != null ? (data['name'] ?? '') : '';
        _icController.text = data != null ? (data['ic'] ?? '') : '';
        _attendance =
            data != null ? (data['attendance'] ?? 'Present') : 'Present';
        _ntsmpDate = (data != null && data['ntsmpDate'] != null)
            ? DateTime.tryParse(data['ntsmpDate'])
            : null;
        _aespDate = (data != null && data['aespDate'] != null)
            ? DateTime.tryParse(data['aespDate'])
            : null;
        _agtesDate = (data != null && data['agtesDate'] != null)
            ? DateTime.tryParse(data['agtesDate'])
            : null;
        _csmeDate = (data != null && data['csmeDate'] != null)
            ? DateTime.tryParse(data['csmeDate'])
            : null;
        _oykDate = (data != null && data['oykDate'] != null)
            ? DateTime.tryParse(data['oykDate'])
            : null;
        _poleProficiency =
            data != null ? (data['poleProficiency'] ?? 'Yes') : 'Yes';
        _ca2aDate = (data != null && data['ca2aDate'] != null)
            ? DateTime.tryParse(data['ca2aDate'])
            : null;
        _ca2cDate = (data != null && data['ca2cDate'] != null)
            ? DateTime.tryParse(data['ca2cDate'])
            : null;
      });
    }
  }

  // Save current person fields to DB and show saved message
  Future<void> _autoSaveCurrentPerson() async {
    final db = DatabaseHelper();
    await db.saveProfilingPerson(
      documentId: widget.team.documentId,
      teamId: widget.team.id,
      personIndex: _selectedPerson,
      data: {
        'name': _nameController.text,
        'ic': _icController.text,
        'attendance': _attendance,
        'ntsmpDate': _ntsmpDate,
        'aespDate': _aespDate,
        'agtesDate': _agtesDate,
        'csmeDate': _csmeDate,
        'oykDate': _oykDate,
        'poleProficiency': _poleProficiency,
        'ca2aDate': _ca2aDate,
        'ca2cDate': _ca2cDate,
      },
    );
    setState(() {
      _showSaved = true;
      _savedOpacity = 1.0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedOpacity = 0.0);
    });
  }

  List<Team> _allTeams = [];

  Future<void> _loadAllTeams() async {
    final teams =
        await DatabaseHelper().getTeamsByDocumentId(widget.team.documentId);
    setState(() {
      _allTeams = teams;
    });
  }

  Future<void> _loadWorkers() async {
    final currentContext = context;
    try {
      final workers = await DatabaseHelper().getWorkers();
      setState(() {
        _workers = workers.where((w) => w.status == 'active').toList();
        _filteredWorkers = _workers;
      });
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to load workers: $e')),
        );
      }
    }
  }

  void _handleNameFocusChange() {
    if (!_nameFocusNode.hasFocus) {
      _removeNameOverlay();
    } else {
      _showNameOverlay();
    }
  }

  void _showNameOverlay() {
    _removeNameOverlay();
    if (_filteredWorkers.isEmpty) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _nameOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: renderBox.size.width - 48,
          child: CompositedTransformFollower(
            link: _nameFieldLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _filteredWorkers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No workers found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredWorkers.length,
                        itemBuilder: (context, index) {
                          final worker = _filteredWorkers[index];
                          final maskedIC = _maskIC(worker.ic);
                          return ListTile(
                            title: Text(worker.name),
                            subtitle: Text(maskedIC),
                            onTap: () => _onWorkerSelected(worker),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_nameOverlayEntry!);
    }
  }

  void _removeNameOverlay() {
    _nameOverlayEntry?.remove();
    _nameOverlayEntry = null;
  }

  String _maskIC(String ic) {
    if (ic.length <= 4) return '*' * ic.length;
    return '*' * (ic.length - 4) + ic.substring(ic.length - 4);
  }

  void _filterWorkers() {
    final query = _nameController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredWorkers = _workers;
      } else {
        _filteredWorkers = _workers.where((worker) {
          return worker.name.toLowerCase().contains(query) ||
              worker.userId.toLowerCase().contains(query);
        }).toList();
      }
      final exactMatch = _workers.any((w) => w.name.toLowerCase() == query);
      if (_nameFocusNode.hasFocus &&
          _filteredWorkers.isNotEmpty &&
          !exactMatch) {
        _showNameOverlay();
      } else {
        _removeNameOverlay();
      }
    });
  }

  void _onWorkerSelected(Worker worker) {
    setState(() {
      _nameController.text = worker.name;
      _icController.text = worker.ic;
    });
    _removeNameOverlay();
    _nameFocusNode.unfocus();
  }

  @override
  void dispose() {
    _nameController.removeListener(_autoSaveCurrentPerson);
    _icController.removeListener(_autoSaveCurrentPerson);
    _nameController.removeListener(_filterWorkers);
    _nameFocusNode.removeListener(_handleNameFocusChange);
    _nameController.dispose();
    _icController.dispose();
    _nameFocusNode.dispose();
    _removeNameOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final maxPersons = widget.maxPersons;

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: 'profiling_team',
        userId: widget.userId,
        role: widget.role,
        documentId: widget.team.documentId,
        currentTeam: widget.team,
        teams: _allTeams,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Profiling Team'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Team (readonly)
            TextFormField(
              initialValue: team.label,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Team',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
            // Person dropdown
            DropdownButtonFormField<int>(
              initialValue: _selectedPerson,
              decoration: InputDecoration(
                labelText: 'Person',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: List.generate(
                maxPersons,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Person ${i + 1}'),
                ),
              ),
              onChanged: (val) {
                if (val != null && val != _selectedPerson) {
                  _autoSaveCurrentPerson();
                  _loadAndSetPersonFields(val);
                }
              },
            ),
            const SizedBox(height: 16),
            // Form content wrapper
            AbsorbPointer(
              absorbing: _isLocked,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Attendance radio
                  const Text('Attendance',
                style: TextStyle(fontWeight: FontWeight.w600)),
            RadioGroup<String>(
              groupValue: _attendance,
              onChanged: (val) {
                setState(() => _attendance = val!);
                _autoSaveCurrentPerson();
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Present',
                      title:
                          const Text('Present', style: TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Not present',
                      title: const Text('Not present',
                          style: TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            // Name
            const SizedBox(height: 8),
            CompositedTransformTarget(
              link: _nameFieldLink,
              child: TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                // onChanged removed, handled by controller listener
              ),
            ),
            // IC
            TextFormField(
              controller: _icController,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'IC/Passport Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              // onChanged removed, handled by controller listener
            ),
            // NTSMP Expiry Date
            _ExpiryDateField(
              label: 'NTSMP Expiry Date',
              date: _ntsmpDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _ntsmpDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _ntsmpDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // AESP Expiry Date
            _ExpiryDateField(
              label: 'AESP Expiry Date',
              date: _aespDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _aespDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _aespDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // AGTES Expiry Date
            _ExpiryDateField(
              label: 'AGTES Expiry Date',
              date: _agtesDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _agtesDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _agtesDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // CSME Expiry Date
            _ExpiryDateField(
              label: 'CSME Expiry Date',
              date: _csmeDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _csmeDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _csmeDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // OYK Expiry Date
            _ExpiryDateField(
              label: 'OYK Expiry Date',
              date: _oykDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _oykDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _oykDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // Pole Proficiency radio
            const SizedBox(height: 8),
            const Text('Pole Proficiency',
                style: TextStyle(fontWeight: FontWeight.w600)),
            RadioGroup<String>(
              groupValue: _poleProficiency,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _poleProficiency = val);
                  _autoSaveCurrentPerson();
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Yes',
                      title: const Text('Yes', style: TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'No',
                      title: const Text('No', style: TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            // CA2A Expiry Date
            _ExpiryDateField(
              label: 'CA2A Expiry Date',
              date: _ca2aDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _ca2aDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _ca2aDate = picked);
                  _autoSaveCurrentPerson();
                }
              },
            ),
            // CA2C Expiry Date
            _ExpiryDateField(
              label: 'CA2C Expiry Date',
              date: _ca2cDate,
              auditDate: _auditDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _ca2cDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (!mounted) return;
                  setState(() => _ca2cDate = picked);
                  _autoSaveCurrentPerson();
                }
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
                ],
              ),
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
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentTeamScreen(
                            documentId: widget.team.documentId,
                            userId: widget.userId,
                            role: widget.role,
                          ),
                        ),
                      );
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
                    onPressed: () async {
                      await _savePersonFields(_selectedPerson,
                          showSaved: false);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SummaryTeamScreen(
                            documentId: widget.team.documentId,
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

class _ExpiryDateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateTime? auditDate;
  final VoidCallback onTap;

  const _ExpiryDateField({
    required this.label,
    required this.date,
    required this.auditDate,
    required this.onTap,
  });

  // Helper method to check if a date is expired (before audit date)
  bool _isDateExpired(DateTime? date) {
    if (date == null || auditDate == null) return false;
    return date.isBefore(auditDate!);
  }

  // Helper method to check if a date is expiring soon (within 3 months after audit date)
  bool _isDateExpiringSoon(DateTime? date) {
    if (date == null || auditDate == null) return false;
    if (_isDateExpired(date)) return false;
    final threeMonthsLater = DateTime(
      auditDate!.year,
      auditDate!.month + 3,
      auditDate!.day,
    );
    return date.isBefore(threeMonthsLater);
  }

  // Helper method to format date with expiry indicator
  String _formatDateWithExpiry(DateTime? date) {
    if (date == null) return '';
    if (_isDateExpired(date)) {
      final expired = '${date.day}/${date.month}';
      return 'EXPIRED $expired';
    }
    if (_isDateExpiringSoon(date)) {
      final formatted =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      return formatted;
    }
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _isDateExpired(date);
    final isExpiringSoon = _isDateExpiringSoon(date);
    final isValid = date != null && auditDate != null && !isExpired && !isExpiringSoon;

    // Determine colors
    Color? fillColor;
    Color textColor;
    Widget? statusIcon;

    if (isExpired) {
      fillColor = Colors.red.shade50;
      textColor = Colors.red;
      statusIcon = const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Icon(Icons.error, color: Colors.red, size: 18),
      );
    } else if (isExpiringSoon) {
      fillColor = Colors.amber.shade50;
      textColor = Colors.amber.shade900;
      statusIcon = Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18),
      );
    } else if (isValid) {
      fillColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      statusIcon = const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Icon(Icons.check_circle, color: Colors.green, size: 18),
      );
    } else {
      fillColor = Colors.white;
      textColor = Colors.black;
      statusIcon = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label :',
              style: const TextStyle(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (statusIcon != null) statusIcon,
          SizedBox(
            width: 140,
            child: GestureDetector(
              onTap: onTap,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'MM/YY',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  controller: TextEditingController(
                    text: _formatDateWithExpiry(date),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
