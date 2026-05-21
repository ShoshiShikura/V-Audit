import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
import 'app_drawer.dart';
import '../services/session_manager.dart';
import 'document_team_screen.dart';

class ApprovalScreen extends StatefulWidget {
  final String userId;
  final String role;

  const ApprovalScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Document> _pendingDocs = [];
  List<Document> _approvedDocs = [];
  List<Document> _rejectedDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    // Load all documents owned by this auditor
    final rows = await db.query(
      'documents',
      where: 'ownerId = ?',
      whereArgs: [widget.userId],
      orderBy: 'lastModified DESC',
    );

    final docs = rows.map((r) => Document.fromMap(r)).toList();

    // Mark as read
    if (!SessionManager.isAdministrator(widget.role)) {
      await DatabaseHelper().markAuditorDocumentsAsRead(widget.userId);
    }

    if (mounted) {
      setState(() {
        _pendingDocs = docs.where((d) => d.status == 'pending').toList();
        _approvedDocs = docs.where((d) => d.status == 'approved').toList();
        _rejectedDocs = docs.where((d) => d.status == 'rejected').toList();
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildDocumentCard(Document doc) {
    final statusColor = _statusColor(doc.status);
    final auditDateStr =
        '${doc.createdDate.day.toString().padLeft(2, '0')}/'
        '${doc.createdDate.month.toString().padLeft(2, '0')}/'
        '${doc.createdDate.year}';
    final modifiedStr = DateFormat('dd/MM/yyyy HH:mm').format(doc.lastModified);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
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
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    radius: 20,
                    child: Icon(_statusIcon(doc.status),
                        color: statusColor, size: 20),
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
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doc.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      doc.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Info row
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _chip(Icons.calendar_today, auditDateStr, Colors.blue),
                  _chip(Icons.category, doc.type.toUpperCase(), Colors.teal),
                  _chip(Icons.location_on, doc.location, Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last modified: $modifiedStr',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              // Rejection remark
              if (doc.status == 'rejected' &&
                  doc.rejectionRemark.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message,
                              size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Admin Remarks',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doc.rejectionRemark,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
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
          Text(
            text,
            style:
                TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Document> docs, String emptyMsg, IconData emptyIcon) {
    if (docs.isEmpty) {
      return _buildEmptyState(emptyMsg, emptyIcon);
    }
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (context, index) => _buildDocumentCard(docs[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        currentPage: 'approval',
        userId: widget.userId,
        role: widget.role,
      ),
      appBar: AppBar(
        title: const Text('Approval'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4B1EFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4B1EFF),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (_pendingDocs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingDocs.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Approved'),
                  if (_approvedDocs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_approvedDocs.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rejected'),
                  if (_rejectedDocs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_rejectedDocs.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingDocs, 'No pending submissions',
                    Icons.hourglass_empty),
                _buildList(_approvedDocs, 'No approved audits',
                    Icons.check_circle_outline),
                _buildList(
                    _rejectedDocs, 'No rejected audits', Icons.cancel_outlined),
              ],
            ),
    );
  }
}
