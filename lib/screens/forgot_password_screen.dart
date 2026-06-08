import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../services/backend_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _userFound = false;
  bool _isChecking = false;
  String? _foundUserName;

  Future<void> _checkUser() async {
    final currentContext = context;
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Please enter your username.')),
      );
      return;
    }

    setState(() => _isChecking = true);

    try {
      // 1. Check local database first
      final db = DatabaseHelper();
      final users = await db.getUsers();
      User? user;
      for (final u in users) {
        if (u.id.toLowerCase() == username.toLowerCase()) {
          user = u;
          break;
        }
      }

      if (!currentContext.mounted) return;

      if (user != null) {
        final finalUser = user;
        // Send request to server
        await BackendService.requestPasswordReset(username);
        // Update local DB
        await db.database.then((db) {
          db.update('users', {'password_reset_requested': 1}, where: 'id = ?', whereArgs: [finalUser.id]);
        });
        setState(() {
          _userFound = true;
          _foundUserName = finalUser.fullName.isNotEmpty ? finalUser.fullName : finalUser.id;
        });
        return;
      }

      // 2. Not found locally — try server
      final serverUsers = await BackendService.fetchUsersFromServer();
      if (!currentContext.mounted) return;

      if (serverUsers != null) {
        for (final su in serverUsers) {
          final sid = su['id']?.toString() ?? '';
          if (sid.toLowerCase() == username.toLowerCase()) {
            final fullName = su['fullName']?.toString() ?? sid;
            // Send request to server
            await BackendService.requestPasswordReset(sid);
            setState(() {
              _userFound = true;
              _foundUserName = fullName.isNotEmpty ? fullName : sid;
            });
            return;
          }
        }
      }

      // 3. Not found anywhere
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('No user found with that username.')),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _userFound ? _buildContactAdmin() : _buildUsernameForm(),
        ),
      ),
    );
  }

  Widget _buildUsernameForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Color(0xFF4B1EFF)),
          const SizedBox(height: 16),
          const Text(
            'Forgot your password?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your username to proceed with the password reset.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _checkUser(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isChecking ? null : _checkUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B1EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAdmin() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4B1EFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings,
                size: 48, color: Color(0xFF4B1EFF)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Contact Your Administrator',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18, color: Color(0xFF4B1EFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Account: $_foundUserName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'To reset your password, please contact your system administrator. '
            'They can reset your password through the "Manage Users" section.\n\n'
            'You can reach your administrator via:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _contactChip(Icons.phone, 'Phone Call'),
              const SizedBox(width: 12),
              _contactChip(Icons.message, 'WhatsApp'),
              const SizedBox(width: 12),
              _contactChip(Icons.people, 'In Person'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4B1EFF),
                side: const BorderSide(color: Color(0xFF4B1EFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back to Login',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4B1EFF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF4B1EFF).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4B1EFF)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B1EFF)),
          ),
        ],
      ),
    );
  }
}
