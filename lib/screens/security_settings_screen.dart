import 'package:flutter/material.dart';
import '../services/encryption_service.dart';
import '../services/data_encryption_service.dart';
import '../db/database_helper.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final String userId;
  final String role;

  const SecuritySettingsScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isEncryptionReady = false;
  bool _isRotatingKeys = false;
  bool _isClearingData = false;

  @override
  void initState() {
    super.initState();
    _checkEncryptionStatus();
  }

  Future<void> _checkEncryptionStatus() async {
    final isReady = await EncryptionService.isEncryptionReady();
    setState(() {
      _isEncryptionReady = isReady;
    });
  }

  Future<void> _rotateEncryptionKeys() async {
    final currentContext = context;
    if (widget.role != 'superadmin') {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Only superadmin can rotate encryption keys')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Rotate Encryption Keys'),
        content: const Text(
            'This will generate new encryption keys. All existing data will be re-encrypted. '
            'This process may take a few moments. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rotate Keys'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRotatingKeys = true);

      try {
        await EncryptionService.rotateEncryptionKey();
        await DataEncryptionService.rotateKeys();

        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text('Encryption keys rotated successfully')),
          );
        }

        await _checkEncryptionStatus();
      } catch (e) {
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Failed to rotate keys: $e')),
          );
        }
      } finally {
        setState(() => _isRotatingKeys = false);
      }
    }
  }

  Future<void> _clearAllData() async {
    final currentContext = context;
    if (widget.role != 'superadmin') {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Only superadmin can clear all data')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete ALL data including:\n'
            '• All audit documents\n'
            '• All user accounts\n'
            '• All team data\n'
            '• All encryption keys\n\n'
            'This action cannot be undone. Are you sure?'),
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
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isClearingData = true);

      try {
        await EncryptionService.clearEncryptionKeys();
        await DataEncryptionService.clearKeys();
        await deleteDatabaseFile();

        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully')),
          );
        }

        await _checkEncryptionStatus();
      } catch (e) {
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Failed to clear data: $e')),
          );
        }
      } finally {
        setState(() => _isClearingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEncryptionReady ? Icons.security : Icons.warning,
                          color:
                              _isEncryptionReady ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Encryption Status',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEncryptionReady
                          ? '✅ Database encryption is active and secure'
                          : '⚠️ Encryption keys are being initialized',
                      style: TextStyle(
                        color:
                            _isEncryptionReady ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.role == 'superadmin') ...[
              Text(
                'Administrator Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRotatingKeys ? null : _rotateEncryptionKeys,
                  icon: _isRotatingKeys
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isRotatingKeys
                      ? 'Rotating Keys...'
                      : 'Rotate Encryption Keys'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isClearingData ? null : _clearAllData,
                  icon: _isClearingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever),
                  label: Text(
                      _isClearingData ? 'Clearing Data...' : 'Clear All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
