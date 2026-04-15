import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/document.dart';

import '../services/pdf_service.dart';
import '../services/audit_data_transfer_service.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'document_team_screen.dart';
import 'app_drawer.dart';

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Type Badge ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final int count;

  const _TypeBadge({required this.type, required this.count});

  Color get _color {
    switch (type.toUpperCase()) {
      case 'CM':
        return const Color(0xFF4CAF50);
      case 'PM':
        return const Color(0xFFFF9800);
      case 'ND':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type.toUpperCase(),
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report Document Card ─────────────────────────────────────────────────────

class _ReportDocumentCard extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const _ReportDocumentCard({
    required this.reportData,
    required this.onTap,
    required this.onAction,
  });

  Color _getTeamTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CM':
        return const Color(0xFF4CAF50);
      case 'PM':
        return const Color(0xFFFF9800);
      case 'ND':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = reportData['document'] as Document;
    final teamCount = reportData['teamCount'] as int? ?? 0;
    final teamType = doc.type;
    final teamTypeColor = _getTeamTypeColor(teamType);
    final auditDateStr =
        '${doc.createdDate.day.toString().padLeft(2, '0')}/'
        '${doc.createdDate.month.toString().padLeft(2, '0')}/'
        '${doc.createdDate.year}';
    final lastModifiedStr = DateFormat('yyyy-MM-dd').format(doc.lastModified);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: type badge + title + actions
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: teamTypeColor.withValues(alpha: 0.1),
                  radius: 20,
                  child: Text(
                    teamType.toUpperCase(),
                    style: TextStyle(
                      color: teamTypeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onAction,
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'export_pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 8),
                          Text('Export PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export_data',
                      child: Row(
                        children: [
                          Icon(Icons.download, color: Color(0xFFFF9800), size: 18),
                          SizedBox(width: 8),
                          Text('Export Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info chips row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _infoChip(Icons.calendar_today, auditDateStr, Colors.blue),
                _infoChip(Icons.person, doc.auditor, Colors.deepPurple),
                _infoChip(Icons.groups, '$teamCount teams', Colors.teal),
                _infoChip(Icons.location_on, doc.location, Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            // Footer
            Row(
              children: [
                Icon(Icons.account_circle, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Owner: ${doc.ownerId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text(
                  'Modified: $lastModifiedStr',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── View Reports Screen ──────────────────────────────────────────────────────

class ViewReportsScreen extends StatefulWidget {
  final String userId;
  final String role;

  const ViewReportsScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  // Data
  List<Document> _allDocuments = [];
  List<Map<String, dynamic>> _reportItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, int> _typeCounts = {};
  List<String> _availableAuditors = [];
  List<String> _availableCompanies = [];
  bool _isLoading = true;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'recent';
  final List<String> _selectedTypes = [];
  String? _selectedAuditor;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // View state
  bool _isGroupedByCompany = false;
  Map<String, List<Map<String, dynamic>>> _groupedItems = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper();
    final allDocs = await db.getAllDocuments();
    final typeCounts = await db.getDocumentCountByType();
    final auditors = await db.getUniqueAuditors();
    final companies = await db.getUniqueCompaniesFromDocuments();

    // Build report items with team counts
    final items = <Map<String, dynamic>>[];
    for (final doc in allDocs) {
      final teamCount = await db.getTeamCountForDocument(doc.id);
      items.add({
        'document': doc,
        'teamCount': teamCount,
      });
    }

    setState(() {
      _allDocuments = allDocs;
      _reportItems = items;
      _filteredItems = List.from(items);
      _typeCounts = typeCounts;
      _availableAuditors = auditors;
      _availableCompanies = companies;
      _isLoading = false;
    });

    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredItems = _reportItems.where((item) {
        final doc = item['document'] as Document;

        // Text search
        if (query.isNotEmpty) {
          final searchable = [
            doc.title,
            doc.description,
            doc.auditor,
            doc.location,
            doc.ownerId,
          ].join(' ').toLowerCase();
          if (!searchable.contains(query)) return false;
        }

        // Type filter
        if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(doc.type)) {
          return false;
        }

        // Auditor filter
        if (_selectedAuditor != null && doc.auditor != _selectedAuditor) {
          return false;
        }

        // Date range filter
        if (_filterStartDate != null && doc.createdDate.isBefore(_filterStartDate!)) {
          return false;
        }
        if (_filterEndDate != null &&
            doc.createdDate.isAfter(_filterEndDate!.add(const Duration(days: 1)))) {
          return false;
        }

        return true;
      }).toList();

      _sortItems();
      _groupItems();
    });
  }

  void _sortItems() {
    _filteredItems.sort((a, b) {
      final docA = a['document'] as Document;
      final docB = b['document'] as Document;
      switch (_sortBy) {
        case 'recent':
          return docB.lastModified.compareTo(docA.lastModified);
        case 'oldest':
          return docA.lastModified.compareTo(docB.lastModified);
        case 'title':
          return docA.title.toLowerCase().compareTo(docB.title.toLowerCase());
        case 'company':
          return docA.description.toLowerCase().compareTo(docB.description.toLowerCase());
        case 'auditor':
          return docA.auditor.toLowerCase().compareTo(docB.auditor.toLowerCase());
        default:
          return 0;
      }
    });
  }

  void _groupItems() {
    _groupedItems = {};
    for (final item in _filteredItems) {
      final doc = item['document'] as Document;
      final key = _isGroupedByCompany ? doc.description : doc.auditor;
      final groupKey = key.isNotEmpty ? key : 'Unknown';
      _groupedItems.putIfAbsent(groupKey, () => []).add(item);
    }
    // Sort keys
    final sortedKeys = _groupedItems.keys.toList()..sort();
    _groupedItems = Map.fromEntries(
      sortedKeys.map((k) => MapEntry(k, _groupedItems[k]!)),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _onReportTap(Map<String, dynamic> item) {
    final doc = item['document'] as Document;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentTeamScreen(
          documentId: doc.id,
          userId: widget.userId,
          role: widget.role,
        ),
      ),
    );
  }

  Future<void> _onReportAction(String action, Map<String, dynamic> item) async {
    final doc = item['document'] as Document;
    final currentContext = context;

    if (action == 'export_pdf') {
      try {
        final pdfBytes = await PdfService().generateFullAuditPdf(doc.id);
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      } catch (e) {
        if (!currentContext.mounted) return;
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } else if (action == 'export_data') {
      await _exportDocumentData(doc);
    }
  }

  Future<void> _exportDocumentData(Document doc) async {
    final currentContext = context;
    try {
      final db = await DatabaseHelper().database;
      final docId = doc.id;

      final teams = await db.query('teams', where: 'documentId = ?', whereArgs: [docId]);
      final profilingData = await db.query('profiling_team', where: 'documentId = ?', whereArgs: [docId]);
      final teamIds = teams.map((t) => t['id'] as String).toList();
      final summaryData = teamIds.isNotEmpty
          ? await db.query('summary_team',
              where: 'teamId IN (${List.filled(teamIds.length, '?').join(',')})',
              whereArgs: teamIds)
          : [];
      final companyNameData = teamIds.isNotEmpty
          ? await db.query('company_name',
              where: 'teamId IN (${List.filled(teamIds.length, '?').join(',')})',
              whereArgs: teamIds)
          : [];
      final findingData = await db.query('finding_summary', where: 'documentId = ?', whereArgs: [docId]);

      // Collect images
      Map<String, dynamic> imageFiles = {};
      for (final companyRow in companyNameData) {
        final teamId = companyRow['teamId'] as String;
        final attachmentPath = companyRow['attachmentPath'] as String?;
        if (attachmentPath != null && attachmentPath.isNotEmpty) {
          final imageFile = File(attachmentPath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final fileName = attachmentPath.split('/').last;
            imageFiles[teamId] = {'fileName': fileName, 'data': base64Encode(imageBytes)};
          }
        }
      }

      final exportData = {
        'meta': {
          'senderName': widget.userId,
          'timestamp': DateTime.now().toIso8601String(),
          'docId': docId,
          'docTitle': doc.title,
          'docType': doc.type,
          'docCompany': doc.description,
          'exportVersion': '1.1.0',
        },
        'document': doc.toMap(),
        'teams': teams,
        'profilingData': profilingData,
        'summaryData': summaryData,
        'companyNameData': companyNameData,
        'findingData': findingData,
        'imageFiles': imageFiles,
        'missingImages': <String>[],
      };

      final exportEnvelope = await AuditDataTransferService.buildExportFileContent(exportData);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audit_${docId}_${DateTime.now().millisecondsSinceEpoch}.auditdata';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(exportEnvelope);

      if (!currentContext.mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Audit Data Export: ${doc.title}');
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Failed to export: $e')),
      );
    }
  }

  // ── Bottom Sheets ───────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
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
              _sheetHandle(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              for (final option in [
                {'key': 'recent', 'label': 'Most Recent', 'icon': Icons.schedule},
                {'key': 'oldest', 'label': 'Oldest First', 'icon': Icons.history},
                {'key': 'title', 'label': 'Title (A-Z)', 'icon': Icons.sort_by_alpha},
                {'key': 'company', 'label': 'Company (A-Z)', 'icon': Icons.business},
                {'key': 'auditor', 'label': 'Auditor (A-Z)', 'icon': Icons.person},
              ])
                ListTile(
                  dense: true,
                  leading: Icon(option['icon'] as IconData,
                      color: _sortBy == option['key'] ? const Color(0xFF4B1EFF) : Colors.grey.shade600,
                      size: 20),
                  title: Text(option['label'] as String, style: const TextStyle(fontSize: 15)),
                  trailing: _sortBy == option['key']
                      ? const Icon(Icons.check, color: Color(0xFF4B1EFF), size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = option['key'] as String;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTypes.clear();
                                _selectedAuditor = null;
                                _filterStartDate = null;
                                _filterEndDate = null;
                              });
                              setModalState(() {});
                              _applyFilters();
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFF4B1EFF))),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Type filter
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Team Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        children: ['CM', 'PM', 'ND'].map((type) {
                          final selected = _selectedTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedTypes.add(type);
                                } else {
                                  _selectedTypes.remove(type);
                                }
                              });
                              setModalState(() {});
                              _applyFilters();
                            },
                            selectedColor: const Color(0xFF4B1EFF).withValues(alpha: 0.15),
                            checkmarkColor: const Color(0xFF4B1EFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        }).toList(),
                      ),
                    ),
                    // Auditor filter
                    if (_availableAuditors.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text('Auditor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedAuditor,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Auditors')),
                            ..._availableAuditors.map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAuditor = val);
                            setModalState(() {});
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                    // Date range filter
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Audit Date Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _filterStartDate = picked);
                                  setModalState(() {});
                                  _applyFilters();
                                }
                              },
                              child: _dateBox('From', _filterStartDate),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterEndDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _filterEndDate = picked);
                                  setModalState(() {});
                                  _applyFilters();
                                }
                              },
                              child: _dateBox('To', _filterEndDate),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date) {
    final text = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 13, color: date != null ? Colors.black87 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 3,
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalAudits = _allDocuments.length;
    final uniqueCompanies = _availableCompanies.length;
    final uniqueAuditors = _availableAuditors.length;

    return Scaffold(
      drawer: AppDrawer(
        currentPage: 'reports',
        userId: widget.userId,
        role: widget.role,
      ),
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Stats cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audit Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _StatCard(
                                  icon: Icons.assessment,
                                  label: 'Total Audits',
                                  value: totalAudits.toString(),
                                  color: const Color(0xFF4B1EFF),
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.business,
                                  label: 'Companies',
                                  value: uniqueCompanies.toString(),
                                  color: const Color(0xFFE67E22),
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.people,
                                  label: 'Auditors',
                                  value: uniqueAuditors.toString(),
                                  color: const Color(0xFF16A085),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Type breakdown chips
                          if (_typeCounts.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _typeCounts.entries
                                  .map((e) => _TypeBadge(type: e.key, count: e.value))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Search + filter bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search audits...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: _showSortSheet,
                                  tooltip: 'Sort',
                                ),
                                IconButton(
                                  icon: Badge(
                                    isLabelVisible: _selectedTypes.isNotEmpty ||
                                        _selectedAuditor != null ||
                                        _filterStartDate != null,
                                    smallSize: 8,
                                    backgroundColor: const Color(0xFF4B1EFF),
                                    child: const Icon(Icons.tune),
                                  ),
                                  onPressed: _showFilterSheet,
                                  tooltip: 'Filter',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Group toggle + count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isGroupedByCompany ? Icons.business : Icons.person,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isGroupedByCompany ? 'Group by Company' : 'Group by Auditor',
                                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  Switch(
                                    value: _isGroupedByCompany,
                                    onChanged: (val) => setState(() {
                                      _isGroupedByCompany = val;
                                      _groupItems();
                                    }),
                                    activeThumbColor: const Color(0xFF4B1EFF),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Results header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Results (${_filteredItems.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Document list
                  if (_filteredItems.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No audit reports found',
                                style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  else if (_groupedItems.length > 1)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final groupKey = _groupedItems.keys.elementAt(index);
                          final groupItems = _groupedItems[groupKey]!;
                          return _buildGroupSection(groupKey, groupItems);
                        },
                        childCount: _groupedItems.length,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _filteredItems[index];
                            return _ReportDocumentCard(
                              reportData: item,
                              onTap: () => _onReportTap(item),
                              onAction: (action) => _onReportAction(action, item),
                            );
                          },
                          childCount: _filteredItems.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupSection(String groupKey, List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8, top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4B1EFF).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4B1EFF).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  _isGroupedByCompany ? Icons.business : Icons.person,
                  size: 18,
                  color: const Color(0xFF4B1EFF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF4B1EFF),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B1EFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFF4B1EFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => _ReportDocumentCard(
                reportData: item,
                onTap: () => _onReportTap(item),
                onAction: (action) => _onReportAction(action, item),
              )),
        ],
      ),
    );
  }
}
