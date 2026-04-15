import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../services/backend_service.dart';

class AddUserScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const AddUserScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  String? _selectedRole;
  bool _usernameExists = false;
  bool _passwordsMatch = false;
  bool _checkingUsername = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_checkUsernameExists);
    _passwordController.addListener(_checkPasswordsMatch);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  Future<void> _checkUsernameExists() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _usernameExists = false);
      return;
    }
    setState(() => _checkingUsername = true);
    final users = await _dbHelper.getUsers();
    final exists = users.any((u) => u.id == id);
    setState(() {
      _usernameExists = exists;
      _checkingUsername = false;
    });
  }

  void _checkPasswordsMatch() {
    setState(() {
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text &&
              _passwordController.text.isNotEmpty &&
              _confirmPasswordController.text.isNotEmpty;
    });
  }

  void _addUser() async {
    final currentContext = context;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final id = _idController.text.trim();
      final password = _passwordController.text.trim();
      final role = _selectedRole!;
      final fullName = _fullNameController.text.trim();
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();
      final newUser = User(
        id: id,
        password: hashedPassword,
        role: role,
        fullName: fullName,
        // Option A: offline admin provisioning
        activated: widget.currentUserRole == 'superadmin',
      );
      await _dbHelper.addUser(newUser);

      // Best-effort sync to XAMPP (doesn't block local creation).
      try {
        await BackendService.upsertUserToServer(
          id: id,
          passwordSha256Hex: hashedPassword,
          role: role,
          fullName: fullName,
        );
      } catch (_) {
        // ignore - user is still created locally
      }

      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('User added successfully! (Synced if server reachable)'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (!currentContext.mounted) return;
      Navigator.pop(currentContext, true);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New User"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      children: [
                        // Username
                        TextFormField(
                          controller: _idController,
                          decoration: InputDecoration(
                            labelText: "Username / ID",
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixIcon: _checkingUsername
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : _idController.text.isNotEmpty
                                    ? (_usernameExists
                                        ? const Icon(Icons.error,
                                            color: Colors.red)
                                        : const Icon(Icons.check_circle,
                                            color: Colors.green))
                                    : null,
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "ID required";
                            }
                            if (_usernameExists) {
                              return "Username already exists";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Full Name required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                              color: Colors.grey, // Always neutral color
                            ),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (val) => val == null || val.length < 6
                              ? "Min 6 characters"
                              : null,
                        ),
                        const SizedBox(height: 14),
                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(() =>
                                  _showConfirmPassword = !_showConfirmPassword),
                              color: Colors.grey, // Always neutral color
                            ),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Confirm your password";
                            }
                            if (!_passwordsMatch) {
                              return "Password does not match";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Role
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          items: const [
                            DropdownMenuItem<String>(
                                value: 'user', child: Text('user')),
                            DropdownMenuItem<String>(
                                value: 'superadmin', child: Text('superadmin')),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedRole = value),
                          decoration: InputDecoration(
                            labelText: "Role",
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            return value == null ? "Role is required" : null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _addUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B1EFF),
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Add User"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
