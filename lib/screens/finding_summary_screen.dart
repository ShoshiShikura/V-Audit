// ignore_for_file: unused_import

import 'dart:io';
import 'dart:async'; // Added for Timer

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../db/database_helper.dart';
import '../models/team.dart';
import '../models/document.dart';
import 'company_name_screen.dart';
import '../services/pdf_service.dart';
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

class FindingSummaryScreen extends StatefulWidget {
  final String documentId;
  final String userId;
  final String role;

  const FindingSummaryScreen({
    super.key,
    required this.documentId,
    required this.userId,
    required this.role,
  });

  @override
  State<FindingSummaryScreen> createState() => _FindingSummaryScreenState();
}

class _FindingSummaryScreenState extends State<FindingSummaryScreen> {
  final TextEditingController _remarkController = TextEditingController();
  bool _showSaved = false;
  double _savedOpacity = 0.0;
  List<Team>? _teams;
  bool _hasLoadedRemark = false;
  Timer? _debounce; // <-- Add debounce timer
  String _documentStatus = 'draft';

  bool get _isLocked => SessionManager.isAdministrator(widget.role) || _documentStatus == 'pending' || _documentStatus == 'approved';

  @override
  void initState() {
    super.initState();
    // Load teams for the drawer ExpansionTile
    DatabaseHelper().getTeamsByDocumentId(widget.documentId).then((teams) {
      setState(() {
        _teams = teams;
      });
    });
    _loadDocumentStatus();
    // Delay loading until after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemark();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel debounce timer
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadRemark() async {
    if (_hasLoadedRemark) return;
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'finding_summary',
      where: 'documentId = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    if (result.isNotEmpty && result.first['remark'] != null) {
      final loadedRemark = result.first['remark'] as String;
      if (_remarkController.text.isEmpty) {
        _remarkController.text = loadedRemark;
      }
    } else {
      if (_remarkController.text.isEmpty) {
        _remarkController.text = '';
      }
    }
    _hasLoadedRemark = true;
  }

  Future<void> _saveRemark() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'finding_summary',
      where: 'documentId = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    final row = {
      'documentId': widget.documentId,
      'remark': _remarkController.text,
    };
    if (result.isEmpty) {
      await db.insert('finding_summary', row);
    } else {
      await db.update('finding_summary', row,
          where: 'documentId = ?', whereArgs: [widget.documentId]);
    }
  }

  Future<void> _exportCoverPage() async {
    final currentContext = context;
    try {
      final pdfBytes =
          await PdfService().generateFullAuditPdf(widget.documentId);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _loadDocumentStatus() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'documents',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [widget.documentId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      setState(() {
        _documentStatus = result.first['status'] as String? ?? 'draft';
      });
    }
  }

  Future<void> _submitForApproval() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit for Approval'),
        content: const Text(
          'This audit will be sent to the administrator for review. '
          'You will not be able to edit it until it is approved or rejected.\n\n'
          'Are you sure you want to submit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper().updateDocumentStatus(widget.documentId, 'pending', rejectionRemark: '');
      setState(() => _documentStatus = 'pending');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit submitted for approval successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Removed: _loadRemark() to prevent resetting the controller on every rebuild
  }

  void _autoSave() async {
    await _saveRemark();
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
      key: GlobalKey<ScaffoldState>(),
      drawer: AppDrawer(
        currentPage: 'finding_summary',
        userId: widget.userId,
        role: widget.role,
        documentId: widget.documentId,
        teams: _teams,
      ),
      appBar: AppBar(
        title: const Text('Finding & Summary'),
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
      body: ListView(
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
          const Text('Remark', style: TextStyle(fontWeight: FontWeight.bold)),
          TextFormField(
            controller: _remarkController,
            readOnly: _isLocked,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter remark...',
            ),
            onChanged: (val) {
              // Debounced auto-save on change
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), () {
                if (mounted) _autoSave();
              });
            },
            onEditingComplete: () {
              _debounce?.cancel();
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
            mainAxisAlignment: MainAxisAlignment.center,
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
                        builder: (_) => CompanyNameScreen(
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
                    backgroundColor: const Color(0xFFFF6F61),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: _exportCoverPage,
                  child: const Text('Export',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
            const SizedBox(height: 16),
            // Submit for Approval button
            if (_documentStatus == 'draft' || _documentStatus == 'rejected')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(
                      _documentStatus == 'rejected' ? 'Resubmit for Approval' : 'Submit for Approval',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: _submitForApproval,
                ),
              )
            else if (_documentStatus == 'pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_top, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            else if (_documentStatus == 'approved')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Approved',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// --- Add this table to your database (in DatabaseHelper._onCreate) ---
// await db.execute('''
//   CREATE TABLE finding_summary (
//     documentId TEXT PRIMARY KEY,
//     remark TEXT
//   )
// ''');
