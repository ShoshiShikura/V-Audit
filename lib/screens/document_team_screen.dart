import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/team.dart';
import 'profiling_team_screen.dart';
import '../screens/app_drawer.dart';
import '../services/session_manager.dart';

class NoTeamsFound extends StatelessWidget {
  const NoTeamsFound({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No teams added yet.'));
  }
}

class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const TeamCard({
    super.key,
    required this.team,
    required this.onDelete,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                team.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Remove team',
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class DocumentTeamScreen extends StatefulWidget {
  final String documentId;
  final String userId;
  final String role;

  const DocumentTeamScreen({
    super.key,
    required this.documentId,
    required this.userId,
    required this.role,
  });

  @override
  State<DocumentTeamScreen> createState() => _DocumentTeamScreenState();
}

class _DocumentTeamScreenState extends State<DocumentTeamScreen> {
  List<Team> _teams = [];
  bool _isDialogOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _documentTeamType; // Store the document's team type
  bool _showSaved = false; // For entry saved message
  double _savedOpacity = 0.0; // For animation
  String _documentStatus = 'draft'; // Track approval status

  @override
  void initState() {
    super.initState();
    _loadDocumentAndTeams();
  }

  Future<void> _loadDocumentAndTeams() async {
    // Load the document to get its team type and status
    final db = await DatabaseHelper().database;
    final docResult = await db.query('documents',
        where: 'id = ?', whereArgs: [widget.documentId], limit: 1);
    if (docResult.isNotEmpty) {
      _documentTeamType = docResult.first['type'] as String?;
      _documentStatus = docResult.first['status'] as String? ?? 'draft';
    }

    // Load teams
    final teams =
        await DatabaseHelper().getTeamsByDocumentId(widget.documentId);
    setState(() => _teams = teams);
  }

  bool get _isLocked => SessionManager.isAdministrator(widget.role) || _documentStatus == 'pending' || _documentStatus == 'approved';

  // Get available team types based on document team type
  List<String> get _availableTeamTypes {
    switch (_documentTeamType) {
      case 'CM':
        return ['CM', '2ND LEVEL'];
      case 'PM':
        return ['PM'];
      case 'ND':
        return ['ND'];
      default:
        return ['CM', '2ND LEVEL']; // Default fallback
    }
  }

  Future<void> _addTeam(String type) async {
    final count = _teams.where((t) => t.type == type).length + 1;
    final newTeam = Team(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      documentId: widget.documentId,
      type: type,
      label: '$type $count',
      number: count,
    );
    await DatabaseHelper().insertTeam(newTeam);
    await _loadDocumentAndTeams();
    setState(() {
      _showSaved = true;
      _savedOpacity = 1.0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedOpacity = 0.0);
    });
  }

  Future<void> _deleteTeam(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                      'Delete Team',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Are you sure you want to delete this team?',
                      style: TextStyle(
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
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
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
      await DatabaseHelper().deleteTeam(id);
      if (!mounted) return;
      _loadDocumentAndTeams();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort teams based on document team type
    final sortedTeams = List<Team>.from(_teams)
      ..sort((a, b) {
        if (a.type == b.type) {
          return a.number.compareTo(b.number);
        }

        // For CM documents: CM first, then 2ND LEVEL
        if (_documentTeamType == 'CM') {
          if (a.type == 'CM') return -1;
          if (b.type == 'CM') return 1;
          return a.type.compareTo(b.type);
        }

        // For PM and ND documents: just sort by number
        return a.number.compareTo(b.number);
      });
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: 'team_list',
        userId: widget.userId,
        role: widget.role,
        documentId: widget.documentId,
        teams: _teams,
      ),
      appBar: AppBar(
        title: const Text('Team List'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        actions: [],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // Locked banner
          if (_isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _documentStatus == 'approved'
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    _documentStatus == 'approved'
                        ? Icons.check_circle
                        : Icons.lock,
                    size: 20,
                    color: _documentStatus == 'approved'
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _documentStatus == 'approved'
                          ? 'This audit has been approved. Editing is locked.'
                          : 'This audit is pending approval. Editing is locked.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _documentStatus == 'approved'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              width: double.infinity,
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
                onPressed: _isLocked ? null : () {
                  if (_isDialogOpen) return;
                  setState(() => _isDialogOpen = true);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      titlePadding: const EdgeInsets.only(
                          left: 24, right: 8, top: 24, bottom: 0),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_add,
                                  color: Color(0xFF4B1EFF)),
                              const SizedBox(width: 10),
                              const Text(
                                'Select Team Type',
                                style: TextStyle(
                                  color: Color(0xFF4B1EFF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            tooltip: 'Cancel',
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _isDialogOpen = false);
                            },
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._availableTeamTypes.map((type) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: OutlinedButton.icon(
                                  icon: Icon(
                                    type == 'CM'
                                        ? Icons.engineering
                                        : Icons.people,
                                    color: const Color(0xFF4B1EFF),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4B1EFF),
                                    side: const BorderSide(
                                        color: Color(0xFF4B1EFF)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 24),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _addTeam(type);
                                    if (!mounted) return;
                                    setState(() => _isDialogOpen = false);
                                  },
                                  label: Text(type,
                                      style: const TextStyle(fontSize: 16)),
                                ),
                              )),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _isDialogOpen = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ).whenComplete(() => setState(() => _isDialogOpen = false));
                },
                child: const Text(
                  'Add New Team',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: sortedTeams.isEmpty
                ? const NoTeamsFound()
                : ListView.separated(
                    itemCount: sortedTeams.length,
                    separatorBuilder: (context, index) => const Divider(
                      indent: 36,
                      endIndent: 36,
                      height: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                    itemBuilder: (context, index) {
                      final team = sortedTeams[index];
                      return TeamCard(
                        team: team,
                        onDelete: _isLocked ? () {} : () => _deleteTeam(team.id),
                        onTap: () {
                          if (_isLocked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _documentStatus == 'approved'
                                      ? 'This audit has been approved. Editing is locked.'
                                      : 'This audit is pending approval. Editing is locked.',
                                ),
                                backgroundColor: _documentStatus == 'approved'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilingTeamScreen(
                                team: team,
                                maxPersons: 10,
                                userId: widget.userId,
                                role: widget.role,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                if (_showSaved)
                  AnimatedOpacity(
                    opacity: _savedOpacity,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text('All changes saved',
                            style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
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
              ],
            ),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
