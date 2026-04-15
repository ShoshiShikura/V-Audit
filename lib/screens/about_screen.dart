import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/preset_workers.dart';

class AboutEmailRow extends StatelessWidget {
  const AboutEmailRow({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.email, color: Color(0xFF4B1EFF)),
        SizedBox(width: 8),
        Text(
          'whshahrin@gmail.com',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF4B1EFF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  final String userId;
  final String role;
  const AboutScreen({super.key, required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'V-Audit',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B1EFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Version 1.2.0',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ChangelogSection(),
                    const SizedBox(height: 20),
                    const Text(
                      'V-Audit is an offline audit logging tool for internal team use, supporting PDF generation and team management.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Developed by Wan Hani Shahrin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '© 2025 Wan Hani Shahrin. All rights reserved.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const AboutEmailRow(),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Worker Database'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset Worker Database'),
                            content: const Text(
                                'This will delete all current workers and restore the preset worker list. This cannot be undone. Continue?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final db = DatabaseHelper();
                          final database = await db.database;
                          await database.delete('workers');
                          for (final worker in presetWorkers) {
                            await db.insertWorker(worker);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Worker database has been reset.')),
                            );
                          }
                        }
                      },
                    ),
                    // --- MIGRATION BUTTON FOR SUPERADMIN ---
                    if (role == 'superadmin') ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings),
                        label:
                            const Text('Fix All Users (Decryption Migration)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await DatabaseHelper().fixAllUsersDecryption();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User migration complete!')),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangelogSection extends StatefulWidget {
  @override
  State<_ChangelogSection> createState() => _ChangelogSectionState();
}

class _ChangelogSectionState extends State<_ChangelogSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 18, color: Color(0xFF4B1EFF)),
                  const SizedBox(width: 8),
                  const Text(
                    'Changelog',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF4B1EFF),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade700),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    tooltip: _expanded ? 'Show less' : 'Show more',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Latest version - brief summary by default
              const Text(
                'v1.2.0',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87),
              ),
              const SizedBox(height: 2),
              if (!_expanded)
                const Text(
                  'UI/UX improvements, enhanced Profile and Add User screens, redesigned Dashboard filters, new worker features, and various bug fixes.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                )
              else
                const Text(
                  '- Updated About screen and app version to 1.2.0, copyright to 2025.\n'
                  '- Improved Profile screen: inline error messages, error borders, password validation, badge consistency.\n'
                  '- Add User screen: inline error messages, error borders, removed snackbars for validation errors.\n'
                  '- Dashboard: sort/filter modals redesigned, filter chips apply immediately, improved spacing, bug fixes.\n'
                  '- General UI/UX: improved spacing, modern look, bug fixes and polish.\n'
                  '- Documents can now be grouped and displayed by company.\n'
                  '- Worker list: last 4 digits of IC/Passport are now censored for privacy.\n'
                  '- Workers: capture images directly from the app.\n'
                  '- "IC" field renamed to "IC/Passport Number".\n'
                  '- Added new fields: OYK and CSME.\n'
                  '- Dashboard remembers your sort/group preference when navigating between screens.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                const Text(
                  'v1.1.6',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                const SizedBox(height: 2),
                const Text(
                  '- Profile screen added with editable full name, read-only username, and secure password change flow.\n'
                  '- Various bug fixes and improvements.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
