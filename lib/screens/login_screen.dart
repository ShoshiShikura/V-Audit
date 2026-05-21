import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../db/database_helper.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';
import '../services/backend_service.dart';
import '../services/session_manager.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'V-Audit',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const Text('Vendor Material Management'),
        const SizedBox(height: 30),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _wrongPassword = false;
  String? _idError;
  String? _passwordError;
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (_wrongPassword) setState(() => _wrongPassword = false);
      if (_passwordError != null) setState(() => _passwordError = null);
    });
    _idController.addListener(() {
      if (_idError != null) setState(() => _idError = null);
    });
  }

  void _login() async {
    String id = _idController.text.trim();
    String password = _passwordController.text.trim();
    bool hasError = false;
    setState(() {
      _idError = null;
      _passwordError = null;
    });
    if (id.isEmpty) {
      setState(() => _idError = 'Please enter your ID');
      hasError = true;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      hasError = true;
    }
    if (hasError) return;
    setState(() => _isLoading = true);
    try {
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();
      final user = await _dbHelper.getUser(id);
      if (!mounted) return;

      // Offline-first: allow login only if user exists locally AND is activated.
      if (user != null &&
          user.activated &&
          user.password == hashedPassword) {
        final normalizedRole = SessionManager.normalizeRole(user.role);
        await SessionManager.saveSession(user.id, normalizedRole);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DashboardScreen(role: normalizedRole, userId: user.id),
          ),
        );
        return;
      }

      // If user exists locally but not activated, require first-time online verification.
      // If user doesn't exist locally, also require online verification to "seed" offline login.
      final online = await BackendService.verifyFirstLogin(
        id: id,
        password: password,
      );
      if (!mounted) return;

      if (!online.ok) {
        // If we have a local user but wrong password, keep old behavior message.
        if (user != null && user.password != hashedPassword) {
          setState(() => _passwordError = 'Incorrect password.');
        } else if (user != null && !user.activated) {
          setState(() => _passwordError =
              'First-time login requires internet connection for verification.');
        } else {
          setState(() => _idError = online.message ?? 'User not found.');
        }
        return;
      }

      final role = SessionManager.normalizeRole(
        (online.role ?? (user?.role ?? 'auditor')).trim(),
      );
      final fullName = (online.fullName ?? (user?.fullName ?? '')).trim();

      final finalId = user?.id ?? id;

      // Upsert locally so subsequent logins are offline-capable.
      await _dbHelper.upsertActivatedUser(
        id: finalId,
        hashedPassword: hashedPassword,
        role: role,
        fullName: fullName,
      );
      await SessionManager.saveSession(finalId, role);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(role: role, userId: finalId),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoginHeader(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Sign In',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: 'ID',
                        prefixIcon: const Icon(Icons.mail),
                        errorText: _idError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
