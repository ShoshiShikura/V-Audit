import 'package:flutter/material.dart';
import '../models/document.dart';
import '../db/database_helper.dart';
import '../screens/document_team_screen.dart';
import '../screens/dashboard_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  final String userId;
  final String role;

  const AddDocumentScreen(
      {super.key, required this.userId, required this.role});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _auditorController = TextEditingController();
  final FocusNode _companyFocusNode = FocusNode();
  final LayerLink _companyFieldLink = LayerLink();
  OverlayEntry? _companyOverlayEntry;
  bool _isSaving = false;
  DateTime? _auditDate;
  String? _selectedTeamType;
  static const List<String> _teamTypes = ['CM', 'PM', 'ND'];
  List<String> _companies = [];
  List<String> _filteredCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _companyController.addListener(_filterCompanies);
    _companyFocusNode.addListener(_handleCompanyFocusChange);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _auditorController.dispose();
    _companyFocusNode.dispose();
    _removeCompanyOverlay();
    super.dispose();
  }

  void _handleCompanyFocusChange() {
    if (!_companyFocusNode.hasFocus) {
      _removeCompanyOverlay();
    } else {
      _showCompanyOverlay();
    }
  }

  void _showCompanyOverlay() {
    _removeCompanyOverlay();
    if (_filteredCompanies.isEmpty) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _companyOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: renderBox.size.width - 48, // 24 padding left/right
          child: CompositedTransformFollower(
            link: _companyFieldLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _filteredCompanies.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No companies found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final company = _filteredCompanies[index];
                          return ListTile(
                            title: Text(company),
                            dense: true,
                            onTap: () => _onCompanySelected(company),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_companyOverlayEntry!);
    }
  }

  void _removeCompanyOverlay() {
    _companyOverlayEntry?.remove();
    _companyOverlayEntry = null;
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await DatabaseHelper().getCompanies();
      setState(() {
        _companies = companies;
        _filteredCompanies = companies;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load companies: $e')),
        );
      }
    }
  }

  void _filterCompanies() {
    final query = _companyController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCompanies = _companies;
      } else {
        _filteredCompanies = _companies.where((company) {
          return company.toLowerCase().contains(query);
        }).toList();
      }
      final exactMatch = _companies.any((c) => c.toLowerCase() == query);
      if (_companyFocusNode.hasFocus &&
          _filteredCompanies.isNotEmpty &&
          !exactMatch) {
        _showCompanyOverlay();
      } else {
        _removeCompanyOverlay();
      }
    });
  }

  void _onCompanySelected(String company) {
    setState(() {
      _companyController.text = company;
    });
    _removeCompanyOverlay();
    _companyFocusNode.unfocus();
  }

  Future<bool> _isDuplicateDocument(
      String title, String company, DateTime auditDate) async {
    final docs = await DatabaseHelper().getDocumentsByUser(widget.userId);
    return docs.any((doc) =>
        doc.title.trim().toLowerCase() == title.trim().toLowerCase() &&
        doc.description.trim().toLowerCase() == company.trim().toLowerCase() &&
        doc.createdDate.year == auditDate.year &&
        doc.createdDate.month == auditDate.month &&
        doc.createdDate.day == auditDate.day);
  }

  Future<void> _saveAndRedirect() async {
    final currentContext = context;
    if (!_formKey.currentState!.validate() ||
        _auditDate == null ||
        _selectedTeamType == null) {
      return;
    }
    final title = _titleController.text.trim();
    final company = _companyController.text.trim();
    final location = _locationController.text.trim();
    final auditor = _auditorController.text.trim();
    if (await _isDuplicateDocument(title, company, _auditDate!)) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text(
                'A document with the same title, company, and audit date already exists.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final document = Document(
        id: 'doc_${now.millisecondsSinceEpoch}',
        title: title,
        description: company,
        type: _selectedTeamType!,
        createdDate: _auditDate!,
        lastModified: now,
        fileName: '',
        isDraft: false,
        ownerId: widget.userId,
        location: location,
        auditor: auditor,
      );
      await DatabaseHelper().insertDocument(document);
      if (!currentContext.mounted) return;
      Navigator.pushReplacement(
        currentContext,
        MaterialPageRoute(
          builder: (context) => DocumentTeamScreen(
            documentId: document.id,
            userId: widget.userId,
            role: widget.role,
          ),
        ),
      );
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to save document: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Audit'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  userId: widget.userId,
                  role: widget.role,
                ),
              ),
            );
          },
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeCompanyOverlay();
        },
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
                    decoration: const InputDecoration(
                      labelText: 'Log Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter log title'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Company Selection with Overlay
                  CompositedTransformTarget(
                    link: _companyFieldLink,
                    child: TextFormField(
                      controller: _companyController,
                      focusNode: _companyFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        hintText: 'Search and select company...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.search),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Enter company name'
                          : null,
                      onTap: () {
                        if (_companies.isNotEmpty) _showCompanyOverlay();
                      },
                      onChanged: (value) {
                        _filterCompanies();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 2),
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
                    decoration: const InputDecoration(
                      labelText: 'Auditor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter auditor name(s)'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTeamType,
                    items: _teamTypes
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedTeamType = val),
                    decoration: const InputDecoration(
                      labelText: 'Team Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) => val == null ? 'Select team type' : null,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _auditDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _auditDate = picked);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Audit Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide:
                                BorderSide(color: Colors.red, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: Icon(Icons.calendar_today),
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
                          icon: const Icon(Icons.create, color: Colors.white),
                          label: const Text('Create'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B1EFF),
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(24)),
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

class NextLogScreen extends StatelessWidget {
  final Document document;

  const NextLogScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Next Log Step')),
      body: Center(child: Text('Continue working on ${document.title}')),
    );
  }
}

class TeamListScreen extends StatelessWidget {
  final Document document;

  const TeamListScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    // UI + logic for team adding
    return Scaffold(
      appBar: AppBar(title: const Text('Next Log Step')),
      body: Center(child: Text('Continue working on ${document.title}')),
    );
  }
}
