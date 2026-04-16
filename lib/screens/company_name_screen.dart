import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
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
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unsupported image format.');
    }

    // Scale up tiny images (e.g. emulator virtual camera) so the stamp is visible.
    const int minStampWidth = 800;
    if (decoded.width < minStampWidth) {
      final scale = minStampWidth / decoded.width;
      decoded = img.copyResize(
        decoded,
        width: minStampWidth,
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Stamp block (bottom-left)
    final stampLines = <String>[
      'Captured: ${_formatCapturedAt(capturedAtLocal.toUtc().toIso8601String())}',
      'Coordinate: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      'Altitude: ${altitude.toStringAsFixed(1)} m',
    ];

    // Use arial14 for smaller images, arial24 for normal+
    final font = decoded.width < 600 ? img.arial14 : img.arial24;
    final pad = ((decoded.width * 0.02).round()).clamp(8, 24);
    final lineGap = 6;
    final lineHeight = (font.lineHeight + lineGap).round();
    final blockH = (pad * 2) + (stampLines.length * lineHeight) - lineGap;

    // Estimate width; keep it reasonable on small images.
    final maxChars =
        stampLines.fold<int>(0, (m, s) => s.length > m ? s.length : m);
    final approxCharW = (font.lineHeight * 0.55).round();
    int blockW = (pad * 2) + (maxChars * approxCharW);
    final minW = (decoded.width * 0.55).round();
    final maxW = (decoded.width * 0.95).round();
    if (blockW < minW) blockW = minW;
    if (blockW > maxW) blockW = maxW;

    final x = pad;
    // Clamp y to 0 so the stamp is always visible even on very small images
    final y = (decoded.height - blockH - pad).clamp(0, decoded.height - 1);

    img.fillRect(
      decoded,
      x1: x,
      y1: y,
      x2: (x + blockW).clamp(0, decoded.width),
      y2: (y + blockH).clamp(0, decoded.height),
      color: img.ColorRgba8(0, 0, 0, 150),
    );

    int textY = y + pad;
    for (final line in stampLines) {
      img.drawString(
        decoded,
        line,
        font: font,
        x: x + pad,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += lineHeight;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(appDir.path, 'audit_images'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(outDir.path, 'company_${teamId}_${ts}_stamped.jpg');
    final jpgBytes = img.encodeJpg(decoded, quality: 90);
    await File(outPath).writeAsBytes(jpgBytes, flush: true);
    return outPath;
  }

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _remarkController.addListener(_autoSave);
  }

  @override
  void dispose() {
    _remarkController.removeListener(_autoSave);
    _remarkController.dispose();
    super.dispose();
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
        'remark': _remarkController.text,
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
        title: const Text('Company Name'),
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
            TextFormField(
              controller: _remarkController,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Enter remark...',
              ),
              onChanged: (val) => _autoSave(),
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
