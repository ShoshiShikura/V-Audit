import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/session_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../screens/view_users_screen.dart';

import '../screens/add_user_screen.dart';
import 'add_document_screen.dart';
import 'document_team_screen.dart';
import 'company_list_screen.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/edit_document_screen.dart';
import 'app_drawer.dart';
import '../services/audit_data_transfer_service.dart';
import '../models/document.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/permission_handler.dart';
import 'worker_list_screen.dart';

class NoDocumentsFound extends StatelessWidget {
  const NoDocumentsFound({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No documents found'));
  }
}

class CompanyGroupCard extends StatelessWidget {
  final String companyName;
  final List<Map<String, dynamic>> documents;
  final void Function(Map<String, dynamic>) onDocumentTap;
  final void Function(String, Map<String, dynamic>) onDocumentAction;

  const CompanyGroupCard({
    super.key,
    required this.companyName,
    required this.documents,
    required this.onDocumentTap,
    required this.onDocumentAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 0,
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${documents.length} document${documents.length == 1 ? '' : 's'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: documents.map((document) {
            return DocumentCard(
              document: document,
              onTap: () => onDocumentTap(document),
              onAction: (action) => onDocumentAction(action, document),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class DocumentCard extends StatelessWidget {
  final Map<String, dynamic> document;
  final void Function() onTap;
  final void Function(String) onAction;
  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onAction,
  });

  Color _getTeamTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CM':
        return const Color(0xFF4CAF50); // Green
      case 'PM':
        return const Color(0xFFFF9800); // Orange
      case 'ND':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  void _showDocumentActions(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
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
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  document['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.edit,
                  color: const Color(0xFF4B1EFF),
                  size: 20,
                ),
                title: const Text('Edit', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  onAction('edit');
                },
              ),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.picture_as_pdf,
                  color: const Color(0xFF4CAF50),
                  size: 20,
                ),
                title: const Text('Export PDF', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  onAction('export');
                },
              ),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.download,
                  color: const Color(0xFFFF9800),
                  size: 20,
                ),
                title: const Text(
                  'Export Data',
                  style: TextStyle(fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onAction('export_data');
                },
              ),
              const Divider(height: 1, thickness: 0.5),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(Icons.delete, color: Colors.red, size: 20),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onAction('delete');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdDate = document['createdDate'] is DateTime
        ? document['createdDate']
        : DateTime.tryParse(document['createdDate']?.toString() ?? '');
    final createdDateStr = createdDate != null
        ? 'Audit Date: '
            '${createdDate.day.toString().padLeft(2, '0')}/'
            '${createdDate.month.toString().padLeft(2, '0')}/'
            '${createdDate.year}'
        : '';
    final teamType = document['type'] ?? '';
    final teamTypeColor = _getTeamTypeColor(teamType);

    bool isHovered = false;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: StatefulBuilder(
        builder: (context, setCardState) {
          return GestureDetector(
            onTapDown: (_) => setCardState(() => isHovered = true),
            onTapUp: (_) => setCardState(() => isHovered = false),
            onTapCancel: () => setCardState(() => isHovered = false),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: teamTypeColor.withValues(alpha: 0.1),
                    child: Text(
                      teamType.toUpperCase(),
                      style: TextStyle(
                        color: teamTypeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (createdDateStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            createdDateStr,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        if ((document['company'] ?? '').isNotEmpty)
                          Text(
                            document['company'],
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'Last modified: ${document['lastModified']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showDocumentActions(context, document),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String role;
  static const String importFailureMessage =
      'Failed to import data: File is invalid, corrupted, or has been tampered with.';

  const DashboardScreen({super.key, required this.userId, required this.role});

  static void showImportFailureSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(importFailureMessage)),
    );
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  String _sortBy = 'recent'; // 'recent' or 'oldest'

  // Filter state
  List<String> _selectedTeamTypes = [];
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // View state
  bool _isGroupedByCompany = false;
  Map<String, List<Map<String, dynamic>>> _groupedDocuments = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Update _loadDocuments to use real data
  Future<void> _loadDocuments() async {
    final dbDocs = await DatabaseHelper().getDocumentsByUser(widget.userId);
    setState(() {
      _documents = dbDocs.map((doc) {
        return {
          'id': doc.id,
          'title': doc.title,
          'company': doc
              .description, // Assuming 'description' is used for company name
          'createdDate': doc.createdDate, // Add createdDate for display
          'lastModified': DateFormat('yyyy-MM-dd').format(doc.lastModified),
          'type': doc.type,
          'document': doc, // Store the full document object
        };
      }).toList();
      _filteredDocuments = _documents;
      _groupDocuments();
      _sortDocuments();

      // Debug: Available team types
      // final teamTypes = _documents.map((doc) => doc['type']).toSet();
    });
  }

  void _groupDocuments() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final doc in _filteredDocuments) {
      final company = doc['company'] ?? 'Unknown Company';
      if (!grouped.containsKey(company)) {
        grouped[company] = [];
      }
      grouped[company]!.add(doc);
    }

    // Sort companies alphabetically
    final sortedCompanies = grouped.keys.toList()..sort();
    _groupedDocuments = Map.fromEntries(
      sortedCompanies.map((company) => MapEntry(company, grouped[company]!)),
    );
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _documents.where((doc) {
        return doc['title'].toLowerCase().contains(query);
      }).toList();
      _groupDocuments();
      _sortDocuments();
    });
  }

  void _sortDocuments() {
    setState(() {
      _filteredDocuments.sort((a, b) {
        final dateA = DateTime.parse(a['lastModified']);
        final dateB = DateTime.parse(b['lastModified']);
        return _sortBy == 'recent'
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      });
    });
  }

  void _showSortBottomSheet() {
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
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  'Sort Documents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Icon(
                          Icons.sort,
                          color: _sortBy == 'recent'
                              ? const Color(0xFF4B1EFF)
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        title: const Text(
                          'Most Recent First',
                          style: TextStyle(fontSize: 15),
                        ),
                        trailing: _sortBy == 'recent'
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF4B1EFF),
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _sortBy = 'recent';
                            _sortDocuments();
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Icon(
                          Icons.sort_by_alpha,
                          color: _sortBy == 'oldest'
                              ? const Color(0xFF4B1EFF)
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        title: const Text(
                          'Oldest First',
                          style: TextStyle(fontSize: 15),
                        ),
                        trailing: _sortBy == 'oldest'
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF4B1EFF),
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _sortBy = 'oldest';
                            _sortDocuments();
                          });
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToViewUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewUsersScreen(currentUserId: widget.userId),
      ),
    );
  }

  void _onDocumentTap(Map<String, dynamic> document) {
    final doc = document['document'];
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

  // Replace the _onAddNewDocument method
  void _onAddNewDocument() async {
    final newDocument = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddDocumentScreen(userId: widget.userId, role: widget.role),
      ),
    );
    if (!mounted) return;
    if (newDocument != null) {
      _loadDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document ${newDocument.title} created')),
      );
    }
  }

  void _onDocumentAction(String action, Map<String, dynamic> document) async {
    final currentContext = context;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Delete Document',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Are you sure you want to delete "${document['title']}"?',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (confirmed == true) {
        await DatabaseHelper().deleteDocument(document['id']);
        if (!mounted) return;
        _loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document "${document['title']}" deleted')),
        );
      }
      return;
    }
    if (action == 'export') {
      // Export PDF logic (same as Finding & Summary page)
      try {
        final pdfBytes = await PdfService().generateFullAuditPdf(
          document['id'],
        );
        if (!mounted) return;
        // Use printing package to share or preview
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
      }
      return;
    }
    if (action == 'export_excel') {
      // Export Excel logic
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating Excel file...')),
        );

        final excelService = ExcelService();
        final filePath = await excelService.exportAuditToExcel(document['id']);
        if (!mounted) return;
        // Show success message with file location
        final fileName = filePath.split('/').last;
        final isInDownloads = filePath.contains('/Download/');
        final location = isInDownloads ? 'Downloads folder' : 'App storage';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel file saved: $fileName'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () async {
                try {
                  await Share.shareXFiles([
                    XFile(filePath),
                  ], text: 'Audit Excel Export: ${document['title']}');
                  if (!mounted) return;
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share: $e')),
                  );
                }
              },
            ),
          ),
        );

        // Show detailed info dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Excel File Saved'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('File: $fileName'),
                  const SizedBox(height: 8),
                  Text('Location: $location'),
                  const SizedBox(height: 8),
                  Text('Path: $filePath'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () async {
                    final currentContext = context;
                    Navigator.pop(context);
                    try {
                      await Share.shareXFiles([
                        XFile(filePath),
                      ], text: 'Audit Excel Export: ${document['title']}');
                      if (!currentContext.mounted) return;
                    } catch (e) {
                      if (!currentContext.mounted) return;
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text('Failed to share: $e')),
                      );
                    }
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (!currentContext.mounted) return;
        ScaffoldMessenger.of(
          currentContext,
        ).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
      }
      return;
    }
    if (action == 'edit') {
      // Navigate to edit document screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditDocumentScreen(
            documentId: document['id'],
            userId: widget.userId,
            role: widget.role,
          ),
        ),
      ).then((_) {
        // Reload documents after editing
        _loadDocuments();
      });
      return;
    }
    if (action == 'export_data') {
      await _exportDocumentData(document);
      if (!mounted) return;
      return;
    }
    // Placeholder for edit action
    if (!currentContext.mounted) return;
    ScaffoldMessenger.of(
      currentContext,
    ).showSnackBar(SnackBar(content: Text('$action ${document['title']}')));
  }

  Future<void> _exportDocumentData(Map<String, dynamic> document) async {
    final currentContext = context;
    try {
      final userFullName = widget.userId;
      final now = DateTime.now();
      final timestamp = now.toIso8601String();
      final doc = document['document'];
      final docId = doc.id;

      // Get all related data for this document
      final db = await DatabaseHelper().database;

      // Get teams
      final teams = await db.query(
        'teams',
        where: 'documentId = ?',
        whereArgs: [docId],
      );

      // Get profiling data
      final profilingData = await db.query(
        'profiling_team',
        where: 'documentId = ?',
        whereArgs: [docId],
      );

      // Get summary data
      final teamIds = teams.map((t) => t['id'] as String).toList();
      final summaryData = teamIds.isNotEmpty
          ? await db.query(
              'summary_team',
              where:
                  'teamId IN (${List.filled(teamIds.length, '?').join(',')})',
              whereArgs: teamIds,
            )
          : [];

      // Get company name data
      final companyNameData = teamIds.isNotEmpty
          ? await db.query(
              'company_name',
              where:
                  'teamId IN (${List.filled(teamIds.length, '?').join(',')})',
              whereArgs: teamIds,
            )
          : [];

      // Get finding summary
      final findingData = await db.query(
        'finding_summary',
        where: 'documentId = ?',
        whereArgs: [docId],
      );

      // Collect image files and their metadata
      Map<String, dynamic> imageFiles = {};
      List<String> missingImages = [];

      for (final companyRow in companyNameData) {
        final teamId = companyRow['teamId'] as String;
        final attachmentPath = companyRow['attachmentPath'] as String?;

        if (attachmentPath != null && attachmentPath.isNotEmpty) {
          final imageFile = File(attachmentPath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final fileName = attachmentPath.split('/').last;
            imageFiles[teamId] = {
              'fileName': fileName,
              'data': base64Encode(imageBytes),
            };
          } else {
            missingImages.add('$teamId: ${attachmentPath.split('/').last}');
          }
        }
      }

      final exportData = {
        'meta': {
          'senderName': userFullName,
          'timestamp': timestamp,
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
        'missingImages': missingImages,
      };

      final exportEnvelope =
          await AuditDataTransferService.buildExportFileContent(exportData);

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audit_${docId}_${now.millisecondsSinceEpoch}.auditdata';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(exportEnvelope);

      final parentContext = context;

      // Show dialog with export summary
      if (parentContext.mounted) {
        showDialog(
          context: parentContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export Audit Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document: ${doc.title}'),
                Text('Teams: ${teams.length}'),
                Text('Images: ${imageFiles.length}'),
                if (missingImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Missing Images: ${missingImages.length}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('Choose what to do with the exported data file.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'Audit Data Export: ${doc.title}');
                    if (!parentContext.mounted) return;
                  } catch (e) {
                    if (!parentContext.mounted) return;
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                },
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    String savePath;
                    if (Platform.isAndroid) {
                      final hasPermission =
                          await AppPermissions.requestStoragePermission();
                      if (!parentContext.mounted) return;
                      if (!hasPermission) {
                        if (!parentContext.mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Storage permission denied. Cannot save file.',
                            ),
                          ),
                        );
                        return;
                      }
                      final downloadsDir = Directory(
                        '/storage/emulated/0/Download',
                      );
                      if (await downloadsDir.exists()) {
                        savePath = '${downloadsDir.path}/$fileName';
                      } else {
                        if (!parentContext.mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not access public Downloads folder.',
                            ),
                          ),
                        );
                        return;
                      }
                    } else {
                      final downloadsDir =
                          await getApplicationDocumentsDirectory();
                      savePath = '${downloadsDir.path}/$fileName';
                    }
                    final saveFile = File(savePath);
                    await saveFile.writeAsString(exportEnvelope);
                    if (!parentContext.mounted) return;
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('File saved to: $savePath')),
                    );
                  } catch (e) {
                    if (!parentContext.mounted) return;
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Failed to save file: $e')),
                    );
                  }
                },
                child: const Text('Save to Device'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(SnackBar(content: Text('Failed to export data: $e')));
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              List<String> tempSelectedTeamTypes = List.from(
                _selectedTeamTypes,
              );
              DateTime? tempStartDate = _filterStartDate;
              DateTime? tempEndDate = _filterEndDate;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 3,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Text(
                      'Filter Documents',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Team Type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['CM', 'PM', 'ND'].map((type) {
                            final isSelected = tempSelectedTeamTypes.contains(
                              type,
                            );
                            return FilterChip(
                              label: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF4B1EFF),
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.grey.shade100,
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF4B1EFF)
                                    : Colors.grey.shade300,
                              ),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    tempSelectedTeamTypes.add(type);
                                  } else {
                                    tempSelectedTeamTypes.remove(type);
                                  }
                                });
                                // Apply filters immediately when selection changes
                                setState(() {
                                  _selectedTeamTypes = List.from(
                                    tempSelectedTeamTypes,
                                  );
                                  _applyFilters();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Date Range',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        tempStartDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (!mounted) return;
                                  if (picked != null) {
                                    setModalState(() => tempStartDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempStartDate == null
                                            ? 'Start Date'
                                            : '${tempStartDate.day.toString().padLeft(2, '0')}/${tempStartDate.month.toString().padLeft(2, '0')}/${tempStartDate.year}',
                                        style: TextStyle(
                                          color: tempStartDate == null
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempEndDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (!mounted) return;
                                  if (picked != null) {
                                    setModalState(() => tempEndDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempEndDate == null
                                            ? 'End Date'
                                            : '${tempEndDate.day.toString().padLeft(2, '0')}/${tempEndDate.month.toString().padLeft(2, '0')}/${tempEndDate.year}',
                                        style: TextStyle(
                                          color: tempEndDate == null
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedTeamTypes = [];
                                _filterStartDate = null;
                                _filterEndDate = null;
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedTeamTypes = List.from(
                                  tempSelectedTeamTypes,
                                );
                                _filterStartDate = tempStartDate;
                                _filterEndDate = tempEndDate;
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B1EFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredDocuments = _documents.where((doc) {
        // Team type filter
        if (_selectedTeamTypes.isNotEmpty) {
          final docType = (doc['type'] ?? '').toUpperCase();
          final hasMatchingType = _selectedTeamTypes.any(
            (selectedType) => selectedType.toUpperCase() == docType,
          );
          if (!hasMatchingType) {
            return false;
          }
        }
        // Date range filter
        final docDate = DateTime.tryParse(doc['lastModified']);
        if (_filterStartDate != null &&
            (docDate == null || docDate.isBefore(_filterStartDate!))) {
          return false;
        }
        if (_filterEndDate != null &&
            (docDate == null || docDate.isAfter(_filterEndDate!))) {
          return false;
        }
        // Search filter (keep existing search logic)
        final query = _searchController.text.toLowerCase();
        if (query.isNotEmpty && !doc['title'].toLowerCase().contains(query)) {
          return false;
        }
        return true;
      }).toList();
      _groupDocuments();
      _sortDocuments();

      // Debug: Print filter results
      // Selected team types: $_selectedTeamTypes
      // Filtered documents count: ${_filteredDocuments.length}
    });
  }

  void _onImportDocument() async {
    final importContext = context;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);

      if (!file.path.endsWith('.auditdata')) {
        if (!importContext.mounted) return;
        ScaffoldMessenger.of(importContext).showSnackBar(
          const SnackBar(content: Text('Please select a .auditdata file.')),
        );
        return;
      }

      final rawFileText = await file.readAsString();
      dynamic data;
      bool importedFromLegacyFormat = false;
      try {
        final decoded = await AuditDataTransferService.decodeImportFileContent(
          rawFileText,
        );
        data = decoded.data;
        importedFromLegacyFormat = decoded.importedFromLegacyFormat;
      } catch (_) {
        if (!importContext.mounted) return;
        DashboardScreen.showImportFailureSnackBar(importContext);
        return;
      }
      final meta = data['meta'] ?? {};
      final docMap = data['document'];
      final docId = meta['docId'] ?? docMap['id'];

      // Check for duplicate
      final existingDocs = await DatabaseHelper().getDocuments();
      final isDuplicate = existingDocs.any((d) => d.id == docId);

      // Get import summary
      final teams = data['teams'] as List? ?? [];
      final profilingData = data['profilingData'] as List? ?? [];
      final summaryData = data['summaryData'] as List? ?? [];
      final companyNameData = data['companyNameData'] as List? ?? [];
      final findingData = data['findingData'] as List? ?? [];
      final imageFiles = data['imageFiles'] as Map<String, dynamic>? ?? {};
      final missingImages = data['missingImages'] as List? ?? [];

      // Show preview dialog with detailed information
      final currentContext = context;
      if (!currentContext.mounted) return;
      final accepted = await showDialog<bool>(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: const Text('Import Audit Data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sender: ${meta['senderName'] ?? 'Unknown'}'),
                Text('Timestamp: ${meta['timestamp'] ?? ''}'),
                const SizedBox(height: 8),
                Text('Title: ${meta['docTitle'] ?? docMap['title']}'),
                Text('Type: ${meta['docType'] ?? docMap['type']}'),
                Text('Company: ${meta['docCompany'] ?? docMap['description']}'),
                const SizedBox(height: 8),
                Text('Teams: ${teams.length}'),
                Text('Profiling Records: ${profilingData.length}'),
                Text('Summary Records: ${summaryData.length}'),
                Text('Company Records: ${companyNameData.length}'),
                Text('Images: ${imageFiles.length}'),
                if (missingImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Missing Images: ${missingImages.length}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                  const Text(
                    'Note: Missing images will be skipped during import.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (isDuplicate)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'A document with this ID already exists.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            if (!isDuplicate)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted == true && !isDuplicate) {
        // Start import process
        final db = await DatabaseHelper().database;
        if (!mounted) return;
        try {
          await db.transaction((txn) async {
            // --- DELETE EXISTING RELATED DATA FOR THIS DOCUMENT ---
            // Delete teams and get their IDs
            final oldTeams = await txn.query(
              'teams',
              where: 'documentId = ?',
              whereArgs: [docId],
            );
            final oldTeamIds = oldTeams.map((t) => t['id'] as String).toList();
            if (oldTeamIds.isNotEmpty) {
              // Delete profiling_team, summary_team, company_name for these team IDs
              await txn.delete(
                'profiling_team',
                where:
                    'teamId IN (${List.filled(oldTeamIds.length, '?').join(',')})',
                whereArgs: oldTeamIds,
              );
              await txn.delete(
                'summary_team',
                where:
                    'teamId IN (${List.filled(oldTeamIds.length, '?').join(',')})',
                whereArgs: oldTeamIds,
              );
              await txn.delete(
                'company_name',
                where:
                    'teamId IN (${List.filled(oldTeamIds.length, '?').join(',')})',
                whereArgs: oldTeamIds,
              );
            }
            // Delete teams
            await txn.delete(
              'teams',
              where: 'documentId = ?',
              whereArgs: [docId],
            );
            // Delete finding_summary
            await txn.delete(
              'finding_summary',
              where: 'documentId = ?',
              whereArgs: [docId],
            );
            // Delete the document itself (if exists)
            await txn.delete('documents', where: 'id = ?', whereArgs: [docId]);

            // --- INSERT NEW DATA ---
            // Insert document
            final doc = Document.fromMap(docMap);
            final newDoc = Document(
              id: doc.id,
              title: doc.title,
              description: doc.description,
              type: doc.type,
              createdDate: doc.createdDate,
              lastModified: doc.lastModified,
              fileName: doc.fileName,
              isDraft: doc.isDraft,
              ownerId: widget.userId,
              location: doc.location,
              auditor: doc.auditor,
            );
            await txn.insert('documents', newDoc.toMap());

            // Insert teams
            for (final team in teams) {
              await txn.insert('teams', team);
            }

            // Insert profiling data
            for (final profile in profilingData) {
              await txn.insert('profiling_team', profile);
            }

            // Insert summary data
            for (final summary in summaryData) {
              await txn.insert('summary_team', summary);
            }

            // Insert finding data
            for (final finding in findingData) {
              await txn.insert('finding_summary', finding);
            }

            // Insert company name data and restore images
            for (final company in companyNameData) {
              final teamId = company['teamId'] as String;
              final imageFile = imageFiles[teamId];

              if (imageFile != null) {
                // Restore image file
                final fileName = imageFile['fileName'] as String;
                final imageData = base64Decode(imageFile['data'] as String);

                // Save image to app documents directory
                final appDir = await getApplicationDocumentsDirectory();
                final imagesDir = Directory('${appDir.path}/audit_images');
                if (!await imagesDir.exists()) {
                  await imagesDir.create(recursive: true);
                }

                final imagePath = '${imagesDir.path}/$fileName';
                final imageFileObj = File(imagePath);
                await imageFileObj.writeAsBytes(imageData);

                // Update attachment path in company data
                company['attachmentPath'] = imagePath;
              }

              await txn.insert('company_name', company);
            }
          });

          await _loadDocuments();

          // Show success message with details
          String message = 'Document imported successfully!';
          if (missingImages.isNotEmpty) {
            message +=
                '\nNote: ${missingImages.length} images were missing and skipped.';
          }
          if (importedFromLegacyFormat) {
            message +=
                '\nImported from legacy format. Re-export to upgrade security format.';
          }

          if (!importContext.mounted) return;
          ScaffoldMessenger.of(importContext).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (e) {
          if (!importContext.mounted) return;
          ScaffoldMessenger.of(
            importContext,
          ).showSnackBar(SnackBar(content: Text('Failed to import data: $e')));
        }
      }
    } catch (e) {
      if (!importContext.mounted) return;
      ScaffoldMessenger.of(
        importContext,
      ).showSnackBar(SnackBar(content: Text('Failed to import data: $e')));
    }
  }

  Widget _buildGroupedDocumentsList() {
    return ListView.builder(
      itemCount: _groupedDocuments.length,
      itemBuilder: (context, index) {
        final companyName = _groupedDocuments.keys.elementAt(index);
        final documents = _groupedDocuments[companyName]!;
        return CompanyGroupCard(
          companyName: companyName,
          documents: documents,
          onDocumentTap: (document) => _onDocumentTap(document),
          onDocumentAction: (action, document) =>
              _onDocumentAction(action, document),
        );
      },
    );
  }

  Widget _buildRegularDocumentsList() {
    return ListView.builder(
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final document = _filteredDocuments[index];
        return DocumentCard(
          document: document,
          onTap: () => _onDocumentTap(document),
          onAction: (action) => _onDocumentAction(action, document),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        currentPage: 'dashboard',
        userId: widget.userId,
        role: widget.role,
      ),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.userId}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 20),
            // Search and filter bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showSortBottomSheet,
                        tooltip: 'Sort',
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: _showFilterBottomSheet,
                        tooltip: 'Filter',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // View toggle
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isGroupedByCompany ? Icons.business : Icons.list,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isGroupedByCompany
                                ? 'Group by Company'
                                : 'All Documents',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isGroupedByCompany,
                          onChanged: (value) {
                            setState(() {
                              _isGroupedByCompany = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF4B1EFF),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Superadmin-only section
            if (SessionManager.isAdministrator(widget.role)) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToViewUsers,
                      icon: const Icon(Icons.people, color: Colors.white),
                      label: const Text("View Users"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B1EFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddUserScreen(
                              currentUserId: widget.userId,
                              currentUserRole: widget.role,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('Add New User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompanyListScreen(
                              userId: widget.userId,
                              role: widget.role,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.business, color: Colors.white),
                      label: const Text('Company List'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerListScreen(
                              userId: widget.userId,
                              role: widget.role,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.badge, color: Colors.white),
                      label: const Text('Worker List'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A085),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        BackendService.testConnection(context);
                      },
                      icon: const Icon(Icons.cloud_done, color: Colors.white),
                      label: const Text('Test XAMPP Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Text(
              "Documents (${_filteredDocuments.length})",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredDocuments.isEmpty
                  ? const NoDocumentsFound()
                  : _isGroupedByCompany
                      ? _buildGroupedDocumentsList()
                      : _buildRegularDocumentsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _onImportDocument,
            backgroundColor: Colors.green,
            tooltip: 'Import Document',
            heroTag: 'import_fab',
            child: const Icon(Icons.file_upload, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _onAddNewDocument,
            backgroundColor: const Color(0xFF4B1EFF),
            tooltip: 'Add New Document',
            heroTag: 'add_fab',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
