import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../services/session_manager.dart';
import 'app_drawer.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String role;

  const ProfileScreen({super.key, required this.userId, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  User? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _isSaving = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _passwordsMatch = false;

  // Error state variables
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String? _fullNameError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _newPasswordController.addListener(_checkPasswordsMatch);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordsMatch() {
    setState(() {
      _passwordsMatch =
          _newPasswordController.text == _confirmPasswordController.text &&
              _newPasswordController.text.isNotEmpty &&
              _confirmPasswordController.text.isNotEmpty;

      // Clear confirm password error if passwords match
      if (_passwordsMatch &&
          _confirmPasswordError == 'Passwords do not match') {
        _confirmPasswordError = null;
      }
    });
  }

  void _clearErrors() {
    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
      _fullNameError = null;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final users = await DatabaseHelper().getUsers();
      final user = users.firstWhere(
        (user) => user.id == widget.userId,
        orElse: () => throw Exception('User not found'),
      );
      setState(() {
        _userData = user;
        _fullNameController.text = user.fullName;
        _usernameController.text = user.id;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userData = User(
          id: widget.userId,
          password: '',
          role: widget.role,
          fullName: widget.userId,
        );
        _fullNameController.text = widget.userId;
        _usernameController.text = widget.userId;
        _isLoading = false;
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _fullNameController.text = _userData?.fullName ?? widget.userId;
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _clearErrors();
      }
    });
  }

  void _togglePasswordChange() {
    setState(() {
      _isChangingPassword = !_isChangingPassword;
      if (!_isChangingPassword) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _clearErrors();
      }
    });
  }

  Future<void> _saveChanges() async {
    // Clear previous errors
    _clearErrors();

    bool hasErrors = false;

    // Validate full name
    if (_fullNameController.text.trim().isEmpty) {
      setState(() {
        _fullNameError = 'Full name cannot be empty';
        hasErrors = true;
      });
    }

    if (_isChangingPassword) {
      // Validate current password
      if (_currentPasswordController.text.isEmpty) {
        setState(() {
          _currentPasswordError = 'Current password is required';
          hasErrors = true;
        });
      } else {
        // Verify current password
        final currentPasswordHash = sha256
            .convert(utf8.encode(_currentPasswordController.text))
            .toString();
        if (currentPasswordHash != _userData?.password) {
          setState(() {
            _currentPasswordError = 'Current password is incorrect';
            hasErrors = true;
          });
        }
      }

      // Validate new password
      if (_newPasswordController.text.isEmpty) {
        setState(() {
          _newPasswordError = 'New password is required';
          hasErrors = true;
        });
      } else if (_newPasswordController.text ==
          _currentPasswordController.text) {
        setState(() {
          _newPasswordError =
              'New password cannot be the same as current password';
          hasErrors = true;
        });
      } else if (_newPasswordController.text.length < 6) {
        setState(() {
          _newPasswordError = 'New password must be at least 6 characters';
          hasErrors = true;
        });
      }

      // Validate confirm password
      if (_confirmPasswordController.text.isEmpty) {
        setState(() {
          _confirmPasswordError = 'Please confirm your new password';
          hasErrors = true;
        });
      } else if (!_passwordsMatch) {
        setState(() {
          _confirmPasswordError = 'Passwords do not match';
          hasErrors = true;
        });
      }
    }

    if (hasErrors) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    final currentContext = context;
    // Capture before clearing state so the success message is correct
    final didChangePassword = _isChangingPassword;
    try {
      final db = DatabaseHelper();
      final userId = _userData?.id ?? widget.userId;

      // Update full name
      await db.updateUserFullName(userId, _fullNameController.text.trim());

      // Update password if requested
      String newPasswordHash = _userData?.password ?? '';
      if (didChangePassword) {
        newPasswordHash =
            sha256.convert(utf8.encode(_newPasswordController.text)).toString();
        await db.updatePassword(userId, newPasswordHash);
      }

      // Reload user data from DB to stay in sync
      final refreshedUser = await db.getUser(userId);

      setState(() {
        _userData = refreshedUser ?? User(
          id: userId,
          password: newPasswordHash,
          role: _userData?.role ?? widget.role,
          fullName: _fullNameController.text.trim(),
        );
        _isEditing = false;
        _isChangingPassword = false;
        _isSaving = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _clearErrors();
      });

      final message = didChangePassword
          ? 'Password changed successfully'
          : 'Profile updated successfully';

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    return SessionManager.isAdministrator(role)
        ? const Color(0xFF4B1EFF)
        : Colors.black54;
  }

  Color _getRoleBackgroundColor(String role) {
    return SessionManager.isAdministrator(role)
        ? const Color(0xFF4B1EFF).withValues(alpha: 0.1)
        : Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        currentPage: 'profile',
        userId: widget.userId,
        role: widget.role,
      ),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (!_isLoading && _userData != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: _isSaving ? null : _toggleEditMode,
              tooltip: _isEditing ? 'Cancel' : 'Edit',
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              const Color(0xFF4B1EFF).withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFF4B1EFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData?.fullName ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleBackgroundColor(
                                _userData?.role ?? SessionManager.roleAuditor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            SessionManager.normalizeRole(
                              _userData?.role ?? SessionManager.roleAuditor,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(
                                _userData?.role ?? SessionManager.roleAuditor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Color(0xFF4B1EFF)),
                            const SizedBox(width: 12),
                            const Text(
                              'Profile Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Username Field (Read-only)
                        _buildField(
                          label: 'Username',
                          icon: Icons.account_circle,
                          controller: _usernameController,
                          enabled: false,
                        ),
                        const SizedBox(height: 20),

                        // Full Name Field
                        _buildField(
                          label: 'Full Name',
                          icon: Icons.person,
                          controller: _fullNameController,
                          enabled: _isEditing,
                          error: _fullNameError,
                        ),
                        const SizedBox(height: 20),

                        // Password Change Section
                        if (_isEditing) ...[
                          Row(
                            children: [
                              const Icon(Icons.lock, color: Color(0xFF4B1EFF)),
                              const SizedBox(width: 12),
                              const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _isChangingPassword,
                                onChanged: (value) => _togglePasswordChange(),
                                activeThumbColor: const Color(0xFF4B1EFF),
                              ),
                            ],
                          ),
                          if (_isChangingPassword) ...[
                            const SizedBox(height: 20),
                            _buildPasswordField(
                              label: 'Current Password',
                              controller: _currentPasswordController,
                              showPassword: _showCurrentPassword,
                              onToggleVisibility: () => setState(() =>
                                  _showCurrentPassword = !_showCurrentPassword),
                              error: _currentPasswordError,
                            ),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              label: 'New Password',
                              controller: _newPasswordController,
                              showPassword: _showNewPassword,
                              onToggleVisibility: () => setState(
                                  () => _showNewPassword = !_showNewPassword),
                              error: _newPasswordError,
                            ),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              label: 'Confirm New Password',
                              controller: _confirmPasswordController,
                              showPassword: _showConfirmPassword,
                              onToggleVisibility: () => setState(() =>
                                  _showConfirmPassword = !_showConfirmPassword),
                              error: _confirmPasswordError,
                            ),
                            if (_newPasswordController.text.isNotEmpty &&
                                _confirmPasswordController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _passwordsMatch
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _passwordsMatch
                                        ? Colors.green
                                        : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _passwordsMatch
                                        ? 'Passwords match'
                                        : 'Passwords do not match',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _passwordsMatch
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save/Cancel Buttons
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _toggleEditMode,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B1EFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Account Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            const Text(
                              'Account Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('User ID', _userData?.id ?? 'N/A'),
                        const Divider(height: 24),
                        _buildInfoRow(
                            'Role', (_userData?.role ?? 'N/A').toUpperCase()),
                        const Divider(height: 24),
                        _buildInfoRow('Status', 'Active'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4B1EFF)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            errorText: error,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onToggleVisibility,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4B1EFF)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            errorText: error,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
