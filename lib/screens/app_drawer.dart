import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_screen.dart';
import 'document_team_screen.dart';
import 'profiling_team_screen.dart';
import 'summary_team_screen.dart';
import 'company_name_screen.dart';
import 'finding_summary_screen.dart';
import 'security_settings_screen.dart';
import '../models/team.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'view_reports_screen.dart';
import '../services/session_manager.dart';
import 'manage_templates_screen.dart';
import 'approval_screen.dart';
import '../db/database_helper.dart';

class DrawerHeaderSection extends StatelessWidget {
  final String userId;
  const DrawerHeaderSection({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
        ),
        color: Color(0xFF4B1EFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'V-Audit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE3E6F3),
                radius: 18,
                child: Icon(Icons.person, color: Color(0xFF4B1EFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final String currentPage;
  final String userId;
  final String role;
  final String? documentId;
  final Team? currentTeam;
  final List<Team>? teams;

  const AppDrawer({
    super.key,
    required this.currentPage,
    required this.userId,
    required this.role,
    this.documentId,
    this.currentTeam,
    this.teams,
  });

  @override
  Widget build(BuildContext context) {
    // Helper for navigation
    void navigateTo(String page, {Team? team}) {
      Navigator.pop(context);
      if (page == currentPage && (team == null || team == currentTeam)) return;
      switch (page) {
        case 'dashboard':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(userId: userId, role: role),
            ),
            (route) => false,
          );
          break;
        case 'team_list':
          if (documentId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentTeamScreen(
                    documentId: documentId!, userId: userId, role: role),
              ),
            );
          }
          break;
        case 'profiling_team':
          if (documentId != null && team != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilingTeamScreen(
                  team: team,
                  maxPersons: 10,
                  userId: userId,
                  role: role,
                ),
              ),
            );
          }
          break;
        case 'summary_team':
          if (documentId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SummaryTeamScreen(
                    documentId: documentId!, userId: userId, role: role),
              ),
            );
          }
          break;
        case 'company_name':
          if (documentId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CompanyNameScreen(
                    documentId: documentId!, userId: userId, role: role),
              ),
            );
          }
          break;
        case 'finding_summary':
          if (documentId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => FindingSummaryScreen(
                    documentId: documentId!, userId: userId, role: role),
              ),
            );
          }
          break;
        case 'security_settings':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SecuritySettingsScreen(userId: userId, role: role),
            ),
          );
          break;
        case 'profile':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: userId, role: role),
            ),
          );
          break;
        case 'reports':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ViewReportsScreen(userId: userId, role: role),
            ),
          );
          break;
        case 'templates':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ManageTemplatesScreen(userId: userId, role: role),
            ),
          );
          break;
        case 'approval':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalScreen(userId: userId, role: role),
            ),
          );
          break;
        // Add more cases for profile, settings, etc.
      }
    }

    // Helper for highlighting
    Color? tileColor(String page) =>
        currentPage == page ? const Color(0xFFE3E6F3) : null;
    Color? textColor(String page) =>
        currentPage == page ? const Color(0xFF4B1EFF) : null;
    Color? iconColor(String page) =>
        currentPage == page ? const Color(0xFF4B1EFF) : null;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      elevation: 8,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F8FA), Color(0xFFE3E6F3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeaderSection(userId: userId),
                const SizedBox(height: 16),
                // Navigation items
                ListTile(
                  leading: Icon(Icons.dashboard,
                      color:
                          iconColor('dashboard') ?? const Color(0xFF4B1EFF)),
                  title: Text('Dashboard',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor('dashboard'))),
                  tileColor: tileColor('dashboard'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: currentPage == 'dashboard'
                      ? null
                      : () => navigateTo('dashboard'),
                ),
                // Profile navigation
                ListTile(
                  leading: Icon(Icons.person,
                      color: iconColor('profile') ?? const Color(0xFF4B1EFF)),
                  title: Text('Profile',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor('profile'))),
                  tileColor: tileColor('profile'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: currentPage == 'profile'
                      ? null
                      : () => navigateTo('profile'),
                ),
                // Approval navigation (auditor-only)
                if (!SessionManager.isAdministrator(role))
                  _ApprovalMenuItem(
                    userId: userId,
                    role: role,
                    currentPage: currentPage,
                    iconColor: iconColor('approval'),
                    textColor: textColor('approval'),
                    tileColor: tileColor('approval'),
                    onTap: () => navigateTo('approval'),
                  ),

                if (currentPage == 'dashboard') ...[
                  // Profile link removed in revert
                  // Security Settings - Hidden for future implementation
                  // ListTile(
                  //   leading:
                  //       const Icon(Icons.security, color: Color(0xFF4B1EFF)),
                  //   title: const Text('Security Settings',
                  //       style: TextStyle(fontWeight: FontWeight.w600)),
                  //   shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12)),
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => SecuritySettingsScreen(
                  //           userId: userId,
                  //           role: role,
                  //         ),
                  //       ),
                  //     );
                  //   },
                  // ),
                ],
                if (documentId != null) ...[
                  ListTile(
                    leading: Icon(Icons.group,
                        color:
                            iconColor('team_list') ?? const Color(0xFF4B1EFF)),
                    title: Text('Team List',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor('team_list'))),
                    tileColor: tileColor('team_list'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: currentPage == 'team_list'
                        ? null
                        : () => navigateTo('team_list'),
                  ),
                  if (teams != null && teams!.isNotEmpty)
                    ExpansionTile(
                      leading: Icon(Icons.person,
                          color: iconColor('profiling_team') ??
                              const Color(0xFF4B1EFF)),
                      title: Text('Profiling Team',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor('profiling_team'))),
                      initiallyExpanded: currentPage == 'profiling_team',
                      children: (() {
                        // Sort teams: CM first, then by number
                        final sortedTeams = List<Team>.from(teams!)
                          ..sort((a, b) {
                            if (a.type == b.type) {
                              return a.number.compareTo(b.number);
                            }
                            if (a.type == 'CM') return -1;
                            if (b.type == 'CM') return 1;
                            return a.type.compareTo(b.type);
                          });
                        return sortedTeams;
                      })()
                          .map((team) {
                        final isCurrent = currentPage == 'profiling_team' &&
                            currentTeam != null &&
                            currentTeam!.id == team.id;
                        return ListTile(
                          title: Text(team.label),
                          selected: isCurrent,
                          selectedTileColor: Colors.blue.shade100,
                          onTap: isCurrent
                              ? null
                              : () => navigateTo('profiling_team', team: team),
                        );
                      }).toList(),
                    ),
                  ListTile(
                    leading: Icon(Icons.summarize,
                        color: iconColor('summary_team') ??
                            const Color(0xFF4B1EFF)),
                    title: Text('Summary Team',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor('summary_team'))),
                    tileColor: tileColor('summary_team'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: currentPage == 'summary_team'
                        ? null
                        : () => navigateTo('summary_team'),
                  ),
                  ListTile(
                    leading: Icon(Icons.business,
                        color: iconColor('company_name') ??
                            const Color(0xFF4B1EFF)),
                    title: Text('Physical Inspection',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor('company_name'))),
                    tileColor: tileColor('company_name'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: currentPage == 'company_name'
                        ? null
                        : () => navigateTo('company_name'),
                  ),
                  ListTile(
                    leading: Icon(Icons.find_in_page,
                        color: iconColor('finding_summary') ??
                            const Color(0xFF4B1EFF)),
                    title: Text('Finding & Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor('finding_summary'))),
                    tileColor: tileColor('finding_summary'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: currentPage == 'finding_summary'
                        ? null
                        : () => navigateTo('finding_summary'),
                  ),
                ],
                const Divider(
                    height: 32, thickness: 1, indent: 24, endIndent: 24),
                ListTile(
                  leading: Icon(Icons.help_outline,
                      color: iconColor('help') ?? const Color(0xFF4B1EFF)),
                  title: Text('Help',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor('help'))),
                  tileColor: tileColor('help'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: currentPage == 'help' ? null : () {},
                ),
                ListTile(
                  leading: Icon(Icons.info_outline,
                      color: iconColor('about') ?? const Color(0xFF4B1EFF)),
                  title: Text('About',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor('about'))),
                  tileColor: tileColor('about'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: currentPage == 'about'
                      ? null
                      : () {
                          Navigator.pop(context);
                          if (currentPage != 'about') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AboutScreen(userId: userId, role: role),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 8),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () => _logout(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    hoverColor: Colors.red.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Logout functionality
  Future<void> _logout(BuildContext context) async {
    const storage = FlutterSecureStorage();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Preserve the data encryption key — it is needed to read
      // encrypted profiling data (name, IC) after re-login.
      final encryptionKey = await storage.read(key: 'data_encryption_key');

      // Clear session data
      await storage.deleteAll();

      // Restore encryption key so existing data remains readable
      if (encryptionKey != null) {
        await storage.write(key: 'data_encryption_key', value: encryptionKey);
      }

      // Navigate to login screen and clear all previous routes
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _ApprovalMenuItem extends StatefulWidget {
  final String userId;
  final String role;
  final String currentPage;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  final Color? tileColor;

  const _ApprovalMenuItem({
    required this.userId,
    required this.role,
    required this.currentPage,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.tileColor,
  });

  @override
  State<_ApprovalMenuItem> createState() => _ApprovalMenuItemState();
}

class _ApprovalMenuItemState extends State<_ApprovalMenuItem> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    DatabaseHelper.badgeRefreshNotifier.addListener(_loadNotificationCount);
  }

  @override
  void dispose() {
    DatabaseHelper.badgeRefreshNotifier.removeListener(_loadNotificationCount);
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    if (SessionManager.isAdministrator(widget.role)) return;

    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM documents WHERE ownerId = ? AND isRead = 0 AND (status = 'rejected' OR status = 'approved')",
      [widget.userId],
    );

    if (result.isNotEmpty && mounted) {
      setState(() {
        _notificationCount = (result.first['count'] as int?) ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.approval,
          color: widget.iconColor ?? const Color(0xFF4B1EFF)),
      title: Row(
        children: [
          Text('Approval',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: widget.textColor)),
          if (_notificationCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_notificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      tileColor: widget.tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: widget.currentPage == 'approval' ? null : widget.onTap,
    );
  }
}
