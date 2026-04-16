import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../services/session_manager.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserCard extends StatelessWidget {
  final User user;
  final bool isCurrentUser;
  final bool showPassword;
  final VoidCallback? onTogglePassword;
  final VoidCallback? onResetPassword;
  final VoidCallback? onDeleteUser;
  final ValueChanged<String?>? onRoleChanged;
  final VoidCallback? onEditName;
  const UserCard({
    super.key,
    required this.user,
    required this.isCurrentUser,
    required this.showPassword,
    this.onTogglePassword,
    this.onResetPassword,
    this.onDeleteUser,
    this.onRoleChanged,
    this.onEditName,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFF4B1EFF).withAlpha((0.1 * 255).toInt()),
                  child: const Icon(Icons.person, color: Color(0xFF4B1EFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.id,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SessionManager.isAdministrator(user.role)
                        ? const Color(0xFF4B1EFF).withAlpha((0.1 * 255).toInt())
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    SessionManager.normalizeRole(user.role),
                    style: TextStyle(
                      color: SessionManager.isAdministrator(user.role)
                          ? const Color(0xFF4B1EFF)
                          : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Full Name row
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: Color(0xFF4B1EFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName : 'No name set',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Password row
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: SessionManager.isAdministrator(user.role)
                        ? 'This is the hashed password (SHA-256). The actual password is never stored.'
                        : 'Password is hidden for security.',
                    child: Text(
                      SessionManager.isAdministrator(user.role) && showPassword
                          ? 'Password: ${user.password}'
                          : 'Password: ••••••••',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ),
                // if (user.role == 'superadmin' && onTogglePassword != null)
                //   IconButton(
                //     icon: Icon(
                //       showPassword ? Icons.visibility_off : Icons.visibility,
                //       color: const Color(0xFF4B1EFF),
                //     ),
                //     onPressed: onTogglePassword,
                //   ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: SessionManager.isAdministrator(user.role)
                      ? SessionManager.roleAdministrator
                      : SessionManager.roleAuditor,
                  items: const [
                    DropdownMenuItem(
                      value: 'auditor',
                      child: Text('auditor'),
                    ),
                    DropdownMenuItem(
                      value: 'administrator',
                      child: Text('administrator'),
                    ),
                  ],
                  onChanged: isCurrentUser ? null : onRoleChanged,
                  borderRadius: BorderRadius.circular(12),
                  underline: const SizedBox(),
                ),
                const SizedBox(width: 4),
                if (!isCurrentUser && onEditName != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF4B1EFF)),
                    tooltip: 'Edit Full Name',
                    onPressed: onEditName,
                  ),
                if (!isCurrentUser && onResetPassword != null)
                  IconButton(
                    icon: const Icon(Icons.lock_reset, color: Color(0xFF2ECC71)),
                    tooltip: 'Reset Password',
                    onPressed: onResetPassword,
                  ),
                if (!isCurrentUser && onDeleteUser != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete User',
                    onPressed: onDeleteUser,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ViewUsersScreen extends StatefulWidget {
  final String currentUserId;

  const ViewUsersScreen({super.key, required this.currentUserId});

  @override
  State<ViewUsersScreen> createState() => _ViewUsersScreenState();
}

class _ViewUsersScreenState extends State<ViewUsersScreen> {
  List<User> _users = [];
  final int _maxVisibleUsers = 50;
  final Map<String, bool> _showPasswordMap =
      {}; // Track password visibility per user

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DatabaseHelper().getUsers();
    users.sort((a, b) {
      final aAdmin = SessionManager.isAdministrator(a.role);
      final bAdmin = SessionManager.isAdministrator(b.role);
      if (aAdmin == bAdmin) return 0;
      return aAdmin ? -1 : 1;
    });
    if (!mounted) return;
    setState(() {
      _users = users.take(_maxVisibleUsers).toList();
      // Initialize password visibility map
      for (var user in _users) {
        _showPasswordMap[user.id] = false;
      }
    });
  }

  Future<void> _deleteUser(String id) async {
    await DatabaseHelper().deleteUser(id);
    _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User deleted')),
    );
  }

  Future<void> _resetPassword(String id) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showPassword = false;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset Password for $id'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter a new password for this user. Share it with them securely (in-person, call, or message).',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter a password';
                    if (val.trim().length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val != passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, passwordController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );

    if (newPassword == null || newPassword.isEmpty) return;
    final hashed = sha256.convert(utf8.encode(newPassword)).toString();
    await DatabaseHelper().updatePassword(id, hashed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password for $id has been reset. Share the new password with them securely.')),
    );
  }

  Future<void> _editUserName(String id, String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Name — $id'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter a name';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B1EFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    await DatabaseHelper().updateUserFullName(id, newName);
    _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Name for $id updated to "$newName".')),
    );
  }

  Future<void> _updateUserRole(String id, String newRole) async {
    await DatabaseHelper().updateUserRole(id, newRole);
    if (!mounted) return;
    _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Role for $id updated to $newRole')),
    );
  }

  void _confirmAction(String title, String content, VoidCallback onConfirmed) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirmed();
              },
              child: const Text("Confirm"))
        ],
      ),
    );
  }

  // Toggle password visibility for a specific user
  void _togglePasswordVisibility(String userId) {
    setState(() {
      _showPasswordMap[userId] = !_showPasswordMap[userId]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Users"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (_, index) {
            final user = _users[index];
            final isCurrentUser = user.id == widget.currentUserId;
            final showPassword = _showPasswordMap[user.id]!;

            return UserCard(
              user: user,
              isCurrentUser: isCurrentUser,
              showPassword: showPassword,
              onTogglePassword: SessionManager.isAdministrator(user.role)
                  ? () => _togglePasswordVisibility(user.id)
                  : null,
              onEditName: isCurrentUser
                  ? null
                  : () => _editUserName(user.id, user.fullName),
              onResetPassword: isCurrentUser
                  ? null
                  : () => _resetPassword(user.id),
              onDeleteUser: isCurrentUser
                  ? null
                  : () => _confirmAction(
                        "Confirm Delete",
                        "Delete user ${user.id}?",
                        () => _deleteUser(user.id),
                      ),
              onRoleChanged: isCurrentUser
                  ? null
                  : (newRole) {
                      if (newRole != null && newRole != user.role) {
                        _confirmAction(
                          "Confirm Role Change",
                          "Change role of ${user.id} to $newRole?",
                          () => _updateUserRole(user.id, newRole),
                        );
                      }
                    },
            );
          },
        ),
      ),
    );
  }
}

extension FirstWhereOrNullExtension<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
