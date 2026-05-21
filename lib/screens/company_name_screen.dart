import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../models/team.dart';
import '../db/database_helper.dart';
import 'summary_team_screen.dart';
import 'finding_summary_screen.dart';
import '../screens/app_drawer.dart';
import 'package:path_provider/path_provider.dart';

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

class CompanyNameScreen extends StatefulWidget {
  final String documentId;
  final String userId;
  final String role;

  const CompanyNameScreen({
    super.key,
    required this.documentId,
    required this.userId,
    required this.role,
  });

  @override
  State<CompanyNameScreen> createState() => _CompanyNameScreenState();
}

class _CompanyNameScreenState extends State<CompanyNameScreen> {
  List<Team> _teams = [];
  Team? _selectedTeam;
  List<String> _teamMembers = [];
  List<String> _selectedMembers = [];
  String? _attachmentPath;
  String? _capturedAtIso;
  double? _latitude;
  double? _longitude;
  double? _altitude;
  final _remarkController = TextEditingController();
  bool _showSaved = false;
  Team? _lastLoadedTeam; // Track last loaded team for UI sync
  double _savedOpacity = 0.0;
  DateTime? _auditDate;

  // Auto-calculated remark data
  String _autoRemark = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // For image picker
  final ImagePicker _picker = ImagePicker();
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB recommended

  Future<Position> _requireCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable it in Settings.',
      );
    }

    // Emulators sometimes don't provide a fresh fix unless a mock location is set.
    // Try a quick last-known position first, then request a current fix.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }

  String _formatCapturedAt(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _formatCoord(double? v) {
    if (v == null) return '';
    return v.toStringAsFixed(6);
  }

  Future<String> _createStampedImage({
    required File originalFile,
    required String teamId,
    required DateTime capturedAtLocal,
    required double latitude,
    required double longitude,
    required double altitude,
  }) async {
    final bytes = await originalFile.readAsBytes();

    // Decode using dart:ui for full Canvas rendering
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final photo = frame.image;

    final w = photo.width.toDouble();
    final h = photo.height.toDouble();

    // --- Font sizes proportional to image width ---
    final timeFontSize = (w * 0.12).clamp(36.0, 200.0);
    final ampmFontSize = (w * 0.05).clamp(16.0, 80.0);
    final dateFontSize = (w * 0.045).clamp(14.0, 72.0);
    final infoFontSize = (w * 0.04).clamp(12.0, 64.0);
    final pad = (w * 0.04).clamp(12.0, 48.0);

    // --- Format date/time strings ---
    final hour12 = capturedAtLocal.hour == 0
        ? 12
        : (capturedAtLocal.hour > 12
            ? capturedAtLocal.hour - 12
            : capturedAtLocal.hour);
    final ampm = capturedAtLocal.hour >= 12 ? 'PM' : 'AM';
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${capturedAtLocal.minute.toString().padLeft(2, '0')}';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr =
        '${months[capturedAtLocal.month - 1]} ${capturedAtLocal.day}, ${capturedAtLocal.year}';
    final dayStr = days[capturedAtLocal.weekday - 1];

    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    final coordStr =
        'Coordinate: ${latitude.abs().toStringAsFixed(6)}°$latDir, ${longitude.abs().toStringAsFixed(6)}°$lngDir';
    final altStr = 'Altitude: ${altitude.toStringAsFixed(1)} m';

    // --- Measure text to compute stamp height ---
    final timePainter = _buildTextPainter(
      timeStr, timeFontSize, FontWeight.w900, Colors.white, w * 0.5,
    );
    final ampmPainter = _buildTextPainter(
      ampm, ampmFontSize, FontWeight.w700, Colors.white, w * 0.2,
    );
    final datePainter = _buildTextPainter(
      '$dateStr  |  $dayStr', dateFontSize, FontWeight.w600, Colors.white, w * 0.8,
    );
    final coordPainter = _buildTextPainter(
      coordStr, infoFontSize, FontWeight.w600, Colors.white, w - pad * 2,
    );
    final altPainter = _buildTextPainter(
      altStr, infoFontSize, FontWeight.w600, Colors.white, w - pad * 2,
    );

    final lineSpacing = pad * 0.5;
    final stampH = pad +
        timePainter.height +
        lineSpacing +
        datePainter.height +
        lineSpacing * 1.5 +
        coordPainter.height +
        lineSpacing +
        altPainter.height +
        pad;
    final stampY = h - stampH;

    // --- Create canvas ---
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Draw original photo
    canvas.drawImage(photo, Offset.zero, Paint());

    // Draw semi-transparent dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, stampY, w, stampH),
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.55),
    );

    // --- Draw text ---
    double curY = stampY + pad;

    // Time (large bold)
    timePainter.paint(canvas, Offset(pad, curY));
    // AM/PM next to time
    ampmPainter.paint(
      canvas,
      Offset(pad + timePainter.width + pad * 0.3, curY + timePainter.height - ampmPainter.height),
    );
    curY += timePainter.height + lineSpacing;

    // Date + Day
    datePainter.paint(canvas, Offset(pad, curY));
    curY += datePainter.height + lineSpacing * 1.5;

    // Thin separator line
    canvas.drawLine(
      Offset(pad, curY),
      Offset(w * 0.6, curY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.5,
    );
    curY += lineSpacing;

    // Coordinate
    coordPainter.paint(canvas, Offset(pad, curY));
    curY += coordPainter.height + lineSpacing;

    // Altitude
    altPainter.paint(canvas, Offset(pad, curY));

    // --- Convert to image bytes ---
    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(w.toInt(), h.toInt());
    final pngData = await resultImage.toByteData(format: ui.ImageByteFormat.png);

    photo.dispose();
    resultImage.dispose();

    if (pngData == null) throw Exception('Failed to render stamped image.');

    // Save
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(appDir.path, 'audit_images'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(outDir.path, 'company_${teamId}_${ts}_stamped.png');
    await File(outPath).writeAsBytes(
      pngData.buffer.asUint8List(),
      flush: true,
    );
    return outPath;
  }

  /// Helper to create a TextPainter for Canvas rendering.
  TextPainter _buildTextPainter(
    String text,
    double fontSize,
    FontWeight weight,
    Color color,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    tp.layout(maxWidth: maxWidth);
    return tp;
  }

  @override
  void initState() {
    super.initState();
    _loadDocumentAuditDate();
    _loadTeams();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentAuditDate() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'documents',
      columns: ['createdDate'],
      where: 'id = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final createdDate = result.first['createdDate'] as String?;
      if (createdDate != null) {
        setState(() {
          _auditDate = DateTime.tryParse(createdDate);
        });
      }
    }
  }

  Future<void> _loadTeams() async {
    final teams =
        await DatabaseHelper().getTeamsByDocumentId(widget.documentId);
    Team? initialTeam;
    setState(() {
      _teams = teams;
      if (_teams.isNotEmpty && _selectedTeam == null) {
        _selectedTeam = _teams.first;
      }
      initialTeam = _selectedTeam;
    });
    if (initialTeam != null) {
      await _loadAllTeamData(initialTeam!);
      _lastLoadedTeam = initialTeam;
    }
  }

  Future<void> _loadAllTeamData(Team team) async {
    await _loadTeamMembers(team);
    await _loadCompanyData(team);
    _lastLoadedTeam = team;

    final availableNames =
        _teamMembers.where((name) => name.isNotEmpty).toSet();
    int maxMembers = 10; // All teams now have 10 persons
    setState(() {
      // Only adjust length, but preserve loaded values
      if (_selectedMembers.length != maxMembers) {
        final old = List<String>.from(_selectedMembers);
        _selectedMembers = List<String>.filled(maxMembers, '', growable: false);
        for (int i = 0; i < maxMembers && i < old.length; i++) {
          _selectedMembers[i] = old[i];
        }
      }
      // Remove any selected member that is not in availableNames
      for (int i = 0; i < _selectedMembers.length; i++) {
        if (_selectedMembers[i].isNotEmpty &&
            !availableNames.contains(_selectedMembers[i])) {
          _selectedMembers[i] = '';
        }
      }
    });
    await _calculateRemark(team);
  }

  /// Auto-generates the remark text from profiling data:
  /// - For each cert, shows "CERT = OK" (≥2 valid), "CERT = N" (1 valid), or "CERT = NONE" (0 valid)
  /// - Only certs that are below 2 are printed
  /// - If any person is absent, shows "[N] NOT PRESENT DURING INSPECTION."
  Future<void> _calculateRemark(Team team) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'profiling_team',
      where: 'teamId = ?',
      whereArgs: [team.id],
    );

    if (rows.isEmpty) {
      setState(() => _autoRemark = '');
      _remarkController.text = '';
      _saveCompanyData();
      return;
    }

    // Certificate columns and their labels
    const certFields = {
      'ntsmpDate': 'NTSMP',
      'aespDate': 'AESP',
      'agtesDate': 'AGTES',
      'csmeDate': 'CSME',
      'oykDate': 'OYK',
      'ca2aDate': 'CA2A',
      'ca2cDate': 'CA2C',
    };

    final lines = <String>[];

    for (final entry in certFields.entries) {
      final field = entry.key;
      final label = entry.value;
      int validCount = 0;

      for (final row in rows) {
        final dateStr = row[field] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _auditDate != null && !date.isBefore(_auditDate!)) {
            validCount++;
          }
        }
      }

      // Only show certs below the minimum of 2
      if (validCount < 2) {
        if (validCount == 0) {
          lines.add('$label = NONE');
        } else {
          lines.add('$label = $validCount ONLY');
        }
      }
    }

    // Count absent members
    int absentCount = 0;
    for (final row in rows) {
      final attendance = (row['attendance'] as String? ?? '').toLowerCase();
      if (attendance == 'not present') {
        absentCount++;
      }
    }
    if (absentCount > 0) {
      lines.add('$absentCount NOT PRESENT DURING INSPECTION.');
    }

    final remark = lines.join('\n');
    setState(() {
      _autoRemark = remark;
      _remarkController.text = remark;
    });
    _saveCompanyData();
  }

  Future<void> _loadTeamMembers(Team team) async {
    final db = DatabaseHelper();
    int maxPersons = 10; // All teams now have 10 persons
    List<String> members = [];
    for (int i = 1; i <= maxPersons; i++) {
      final data = await db.getProfilingPerson(team.id, i);
      // Safely handle null and type for name
      final nameRaw = data != null ? data['name'] : null;
      final name =
          (nameRaw is String && nameRaw.trim().isNotEmpty) ? nameRaw : '';
      members.add(name);
    }
    setState(() {
      _teamMembers = members;
    });
  }

  Future<Map<String, dynamic>?> _getCompanyData(String teamId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'company_name',
      where: 'teamId = ?',
      whereArgs: [teamId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> _loadCompanyData(Team team) async {
    final data = await _getCompanyData(team.id);
    int maxMembers = 10; // All teams now have 10 persons
    List<String> members = List.filled(maxMembers, '');
    String? loadedAttachmentPath;
    String? loadedCapturedAt;
    double? loadedLat;
    double? loadedLng;
    double? loadedAlt;
    String loadedRemark = '';
    if (data != null) {
      // Members
      if (data['members'] != null &&
          data['members'] is String &&
          (data['members'] as String).isNotEmpty) {
        final savedMembers = (data['members'] as String).split('|');
        for (int i = 0; i < maxMembers && i < savedMembers.length; i++) {
          members[i] = savedMembers[i];
        }
      }
      // Attachment path
      loadedAttachmentPath =
          (data['attachmentPath'] != null && data['attachmentPath'] is String)
              ? data['attachmentPath'] as String
              : null;
      if (loadedAttachmentPath != null && loadedAttachmentPath.isEmpty) {
        loadedAttachmentPath = null;
      }
      // Remark
      loadedRemark = (data['remark'] != null && data['remark'] is String)
          ? data['remark'] as String
          : '';

      loadedCapturedAt =
          (data['capturedAt'] != null && data['capturedAt'] is String)
              ? data['capturedAt'] as String
              : null;
      loadedLat = (data['latitude'] is num)
          ? (data['latitude'] as num).toDouble()
          : null;
      loadedLng = (data['longitude'] is num)
          ? (data['longitude'] as num).toDouble()
          : null;
      loadedAlt = (data['altitude'] is num)
          ? (data['altitude'] as num).toDouble()
          : null;
    } else {
      loadedAttachmentPath = null;
      loadedCapturedAt = null;
      loadedLat = null;
      loadedLng = null;
      loadedAlt = null;
      loadedRemark = '';
    }
    setState(() {
      _attachmentPath = loadedAttachmentPath;
      _capturedAtIso = loadedCapturedAt;
      _latitude = loadedLat;
      _longitude = loadedLng;
      _altitude = loadedAlt;
      _selectedMembers = members;
      // Only update the controller if the value is different to avoid cursor jump
      if (_remarkController.text != loadedRemark) {
        _remarkController.text = loadedRemark;
      }
    });
  }

  Future<void> _saveCompanyData() async {
    try {
      if (_selectedTeam == null) return;

      final db = await DatabaseHelper().database;
      final id = _selectedTeam!.id;
      final maxMembers = 10; // All teams now have 10 persons

      // Ensure _selectedMembers is properly initialized
      if (_selectedMembers.isEmpty) {
        _selectedMembers = List<String>.filled(maxMembers, '', growable: false);
      }

      final membersToSave = List<String>.from(_selectedMembers);
      if (membersToSave.length != maxMembers) {
        membersToSave.length = maxMembers;
        membersToSave.fillRange(membersToSave.length, maxMembers, '');
      }

      final row = {
        'teamId': id,
        'attachmentPath': _attachmentPath ?? '',
        'capturedAt': _capturedAtIso,
        'latitude': _latitude,
        'longitude': _longitude,
        'altitude': _altitude,
        'remark': _autoRemark,
        'members': membersToSave.join('|'),
      };
      final result = await db.query(
        'company_name',
        where: 'teamId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) {
        await db.insert('company_name', row);
      } else {
        if (!mounted) return;
        await db.update(
          'company_name',
          row,
          where: 'teamId = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Error saving company data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data:  ${e.toString()}')),
        );
      }
    }
  }

  void _autoSave() {
    _saveCompanyData();
    setState(() {
      _showSaved = true;
      _savedOpacity = 1.0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedOpacity = 0.0);
    });
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const Icon(Icons.camera_alt,
                    color: Color(0xFF4B1EFF), size: 22),
                title: const Text('Take Photo', style: TextStyle(fontSize: 16)),
                onTap: () async {
                  Navigator.pop(context);
                  final picked =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    final file = File(picked.path);
                    final fileSize = await file.length();
                    if (fileSize > maxFileSizeBytes) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('File too large. Max size is 5MB.'),
                        ),
                      );
                      return;
                    }

                    // Enforce "taken on-site": get a fresh GPS fix immediately after capture
                    Position pos;
                    try {
                      pos = await _requireCurrentPosition();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to get location. Please enable GPS and grant permission.\n$e',
                          ),
                        ),
                      );
                      return;
                    }

                    // --- Backup logic start ---
                    try {
                      final appDir = await getApplicationDocumentsDirectory();
                      final backupDir =
                          Directory('${appDir.path}/image_backups');
                      if (!await backupDir.exists()) {
                        await backupDir.create(recursive: true);
                      }
                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                      final teamId = _selectedTeam?.id ?? 'unknown_team';
                      final ext = picked.path.split('.').last;
                      final backupPath =
                          '${backupDir.path}/photo_${teamId}_$timestamp.$ext';
                      await file.copy(backupPath);
                    } catch (e) {
                      debugPrint('Failed to backup image: $e');
                    }
                    // --- Backup logic end ---
                    final teamId = _selectedTeam?.id ?? 'unknown_team';
                    final capturedAtLocal = DateTime.now();

                    String stampedPath;
                    bool stampSucceeded = false;
                    try {
                      stampedPath = await _createStampedImage(
                        originalFile: file,
                        teamId: teamId,
                        capturedAtLocal: capturedAtLocal,
                        latitude: pos.latitude,
                        longitude: pos.longitude,
                        altitude: pos.altitude,
                      );
                      stampSucceeded = true;
                      debugPrint(
                        '[STAMP OK] lat=${pos.latitude}, lng=${pos.longitude}, '
                        'alt=${pos.altitude}, path=$stampedPath',
                      );
                    } catch (e) {
                      stampedPath = picked.path; // fallback (unstamped)
                      debugPrint('[STAMP FAIL] $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Photo saved but stamping failed. PDF will show the original photo.\n$e',
                          ),
                        ),
                      );
                    }

                    setState(() {
                      _attachmentPath = stampedPath;
                      _capturedAtIso =
                          capturedAtLocal.toUtc().toIso8601String();
                      _latitude = pos.latitude;
                      _longitude = pos.longitude;
                      _altitude = pos.altitude;
                    });
                    _autoSave();

                    if (stampSucceeded && mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '📍 Photo stamped — GPS: ${pos.latitude.toStringAsFixed(4)}, '
                            '${pos.longitude.toStringAsFixed(4)}',
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Ensure UI always reflects the selected team ---
    if (_selectedTeam != null && _selectedTeam != _lastLoadedTeam) {
      // This will reload data if the selected team changes (e.g., after hot reload or navigation)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && _selectedTeam != _lastLoadedTeam) {
          await _loadAllTeamData(_selectedTeam!);
        }
      });
    }

    const maxMembers = 10; // All teams now have 10 persons
    final availableNames =
        _teamMembers.where((name) => name.isNotEmpty).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: 'company_name',
        userId: widget.userId,
        role: widget.role,
        documentId: widget.documentId,
        teams: _teams,
      ),
      appBar: AppBar(
        title: const Text('Physical Inspection'),
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
              items: (() {
                int typePriority(String type) {
                  switch (type) {
                    case 'CM':
                      return 0;
                    case 'PM':
                      return 1;
                    case 'ND':
                      return 2;
                    default:
                      return 99;
                  }
                }

                final sortedTeams = List<Team>.from(_teams)
                  ..sort((a, b) {
                    final pa = typePriority(a.type);
                    final pb = typePriority(b.type);
                    if (pa != pb) return pa.compareTo(pb);
                    return a.number.compareTo(b.number);
                  });
                return sortedTeams.map((team) {
                  return DropdownMenuItem<Team>(
                    value: team,
                    child: Text(team.label),
                  );
                }).toList();
              })(),
              onChanged: (team) async {
                if (team != null) {
                  setState(() {
                    _selectedTeam = team;
                    // Initialize _selectedMembers with empty strings
                    _selectedMembers =
                        List<String>.filled(10, '', growable: false);
                    _attachmentPath = null;
                    _capturedAtIso = null;
                    _latitude = null;
                    _longitude = null;
                    _altitude = null;
                    _remarkController.text = '';
                  });
                  await _loadAllTeamData(team);
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Dropdown',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Attachment',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B1EFF),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 18),
                    elevation: 0,
                  ),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 12),
                if (_attachmentPath != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _attachmentPath!.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _attachmentPath = null;
                              _capturedAtIso = null;
                              _latitude = null;
                              _longitude = null;
                              _altitude = null;
                            });
                            _autoSave(); // <-- Auto-save after clearing image
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // --- Image preview section ---
            if (_attachmentPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: File(_attachmentPath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_attachmentPath!),
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 180,
                          height: 180,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image,
                              size: 48, color: Colors.grey),
                        ),
                ),
              ),
            if (_attachmentPath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((_capturedAtIso ?? '').isNotEmpty)
                          Text(
                              'Captured: ${_formatCapturedAt(_capturedAtIso)}'),
                        if (_latitude != null && _longitude != null)
                          Text(
                            'Coordinate: ${_formatCoord(_latitude)}°, ${_formatCoord(_longitude)}°',
                          ),
                        if (_altitude != null)
                          Text('Altitude: ${_altitude!.toStringAsFixed(1)} m'),
                        if ((_capturedAtIso ?? '').isEmpty &&
                            _latitude == null &&
                            _longitude == null &&
                            _altitude == null)
                          const Text(
                            'No GPS tag stored for this image.',
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Team Members',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(maxMembers, (i) {
              if (availableNames.isEmpty) return const SizedBox.shrink();

              // Get current selected value for this dropdown
              String? currentValue;
              if (_selectedMembers.length > i &&
                  _selectedMembers[i].isNotEmpty) {
                currentValue = _selectedMembers[i];
                // If the selected value is not in available names, clear it
                if (!availableNames.contains(currentValue)) {
                  currentValue = null;
                }
              }

              // Create available options for this dropdown
              List<String> availableOptions = [];

              // Always include the current selected value if it exists
              if (currentValue != null) {
                availableOptions.add(currentValue);
              }

              // Add other available names that are not selected in other dropdowns
              for (final name in availableNames) {
                if (name != currentValue && !_selectedMembers.contains(name)) {
                  availableOptions.add(name);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: currentValue,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Select a person',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    ...availableOptions.map((name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      // Ensure _selectedMembers has the right length
                      if (_selectedMembers.length != maxMembers) {
                        final old = List<String>.from(_selectedMembers);
                        _selectedMembers = List<String>.filled(maxMembers, '',
                            growable: false);
                        for (int j = 0; j < maxMembers && j < old.length; j++) {
                          _selectedMembers[j] = old[j];
                        }
                      }
                      _selectedMembers[i] = val ?? '';
                    });
                    _saveCompanyData();
                  },
                  decoration: InputDecoration(
                    labelText: 'Person ${i + 1}',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Remark', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_autoRemark.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  _autoRemark,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All certifications meet requirement. All members present.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
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
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SummaryTeamScreen(
                            documentId: widget.documentId,
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
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FindingSummaryScreen(
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
//   CREATE TABLE company_name (
//     teamId TEXT PRIMARY KEY,
//     attachmentPath TEXT,
//     remark TEXT,
//     members TEXT
//   )
// ''');
