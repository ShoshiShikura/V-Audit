import 'package:flutter/material.dart';
import '../models/document.dart';
import '../db/database_helper.dart';

class EditDocumentLoading extends StatelessWidget {
  const EditDocumentLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Audit'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class EditDocumentScreen extends StatefulWidget {
  final String documentId;
  final String userId;
  final String role;

  const EditDocumentScreen({
    super.key,
    required this.documentId,
    required this.userId,
    required this.role,
  });

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _auditorController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  DateTime? _auditDate;
  String? _selectedTeamType;
  final List<String> _teamTypes = ['CM', 'PM', 'ND'];
  Document? _originalDocument;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final currentContext = context;
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query('documents',
          where: 'id = ?', whereArgs: [widget.documentId], limit: 1);

      if (!mounted) return;

      if (result.isNotEmpty) {
        final doc = Document.fromMap(result.first);
        _originalDocument = doc;

        setState(() {
          _titleController.text = doc.title;
          _companyController.text =
              doc.description; // Company name is stored in description
          _locationController.text = doc.location;
          _auditorController.text = doc.auditor;
          _selectedTeamType = doc.type;
          _auditDate = doc.createdDate; // Audit date is stored in createdDate
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Document not found')),
          );
          Navigator.pop(currentContext);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Error loading document: $e')),
        );
        Navigator.pop(currentContext);
      }
    }
  }

  Future<bool> _isDuplicateTitle(String title) async {
    final docs = await DatabaseHelper().getDocumentsByUser(widget.userId);
    return docs.any(
      (doc) =>
          doc.id != widget.documentId &&
          doc.title.trim().toLowerCase() == title.trim().toLowerCase(),
    );
  }

  Future<void> _saveAndRedirect() async {
    final currentContext = context;
    if (!_formKey.currentState!.validate() ||
        _auditDate == null ||
        _selectedTeamType == null) {
      if (_auditDate == null) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please select an audit date.')),
        );
      }
      if (_selectedTeamType == null) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please select a team type.')),
        );
      }
      return;
    }

    final title = _titleController.text.trim();
    final company = _companyController.text.trim();
    final location = _locationController.text.trim();
    final auditor = _auditorController.text.trim();

    // Check for duplicate title for this user (excluding current document)
    if (await _isDuplicateTitle(title)) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Duplicate title. Please choose another title.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final updatedDocument = Document(
        id: widget.documentId,
        title: title,
        description: company,
        type: _selectedTeamType!,
        createdDate: _auditDate!,
        lastModified: now,
        fileName: _originalDocument?.fileName ?? '',
        isDraft: _originalDocument?.isDraft ?? false,
        ownerId: widget.userId,
        location: location,
        auditor: auditor,
      );

      await DatabaseHelper().updateDocument(updatedDocument);

      if (!currentContext.mounted) return;

      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Document updated successfully!')),
      );

      Navigator.pop(currentContext); // Return to dashboard
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext)
          .showSnackBar(SnackBar(content: Text('Error updating document: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _auditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const EditDocumentLoading();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Audit'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Log Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter log title'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyController,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter company name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter location'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _auditorController,
                    decoration: InputDecoration(
                      labelText: 'Auditor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter auditor name(s)'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Team Type Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTeamType,
                    items: _teamTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedTeamType = val),
                    decoration: InputDecoration(
                      labelText: 'Team Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => val == null ? 'Select team type' : null,
                  ),
                  const SizedBox(height: 16),
                  // Audit Date Picker as TextFormField
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _auditDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (!mounted) return;
                      if (picked != null) {
                        setState(() => _auditDate = picked);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Audit Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: _auditDate == null
                              ? ''
                              : '${_auditDate!.day.toString().padLeft(2, '0')}/${_auditDate!.month.toString().padLeft(2, '0')}/${_auditDate!.year}',
                        ),
                        validator: (_) => _auditDate == null
                            ? 'Please select an audit date.'
                            : null,
                        readOnly: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B1EFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isSaving ? null : _saveAndRedirect,
                        ),
                      ),
                    ],
                  ),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
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
