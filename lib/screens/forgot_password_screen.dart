import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';

class SuccessMessage extends StatelessWidget {
  final VoidCallback onBack;
  const SuccessMessage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          const Text('Your password has been reset.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onBack,
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String? _sentCode;
  String? _userId;
  bool _codeSent = false;
  bool _resetSuccess = false;

  Future<void> _sendResetCode() async {
    final currentContext = context;
    final username = _usernameController.text.trim();
    final db = DatabaseHelper();
    final users = await db.getUsers();
    User? user;
    for (final u in users) {
      if (u.id.toLowerCase() == username.toLowerCase()) {
        user = u;
        break;
      }
    }
    if (user == null) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('No user found with that username.')),
      );
      return;
    }
    // Generate a simple 6-digit code (for demo, not secure)
    _sentCode =
        (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    _userId = user.id;
    setState(() => _codeSent = true);

    // Show the code directly since we can't send email
    if (!currentContext.mounted) return;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text('Reset code: $_sentCode'),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final currentContext = context;
    if (_codeController.text.trim() != _sentCode) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Invalid code.')),
      );
      return;
    }
    if (_userId == null) return;
    final db = DatabaseHelper();
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters.')),
      );
      return;
    }
    final hashed = sha256.convert(utf8.encode(newPassword)).toString();
    await db.updatePassword(_userId!, hashed);
    setState(() => _resetSuccess = true);
    if (!currentContext.mounted) return;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      const SnackBar(content: Text('Password reset successful!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _resetSuccess
            ? SuccessMessage(onBack: () => Navigator.pop(context))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_codeSent) ...[
                    const SizedBox(height: 16),
                    const Text('Enter your username to receive a reset code:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sendResetCode,
                      child: const Text('Send Code'),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                        'Enter the code shown above and your new password:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      decoration:
                          const InputDecoration(labelText: 'Reset Code'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'New Password'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _resetPassword,
                      child: const Text('Reset Password'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
