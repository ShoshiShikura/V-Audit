import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'dashboard_screen.dart';

class CompanyListScreen extends StatefulWidget {
  final String userId;
  final String role;

  const CompanyListScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  List<String> _companies = [];
  List<String> _filteredCompanies = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newCompanyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(_filterCompanies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newCompanyController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await DatabaseHelper().getCompanies();
      setState(() {
        _companies = companies;
        _filteredCompanies = companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load companies: $e')),
        );
      }
    }
  }

  void _filterCompanies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCompanies = _companies.where((company) {
        return company.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _addCompany([BuildContext? context]) async {
    final currentContext = context ?? this.context;
    final companyName = _newCompanyController.text.trim();
    if (companyName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please enter a company name')),
        );
      }
      return;
    }

    // Check for duplicate
    if (_companies.contains(companyName)) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Company already exists')),
        );
      }
      return;
    }

    try {
      await DatabaseHelper().addCompany(companyName);
      _newCompanyController.clear();
      await _loadCompanies();
      if (mounted && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Company "$companyName" added successfully')),
        );
      }
    } catch (e) {
      if (mounted && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to add company: $e')),
        );
      }
    }
  }

  Future<void> _deleteCompany(String companyName) async {
    final currentContext = context;
    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Delete Company',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure you want to delete "$companyName"?\n\nThis action cannot be undone.',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper().deleteCompany(companyName);
        await _loadCompanies();
        if (mounted && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Company "$companyName" deleted')),
          );
        }
      } catch (e) {
        if (mounted && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Failed to delete company: $e')),
          );
        }
      }
    }
  }

  void _showAddCompanyDialog() {
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Add New Company',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _newCompanyController,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Please enter a company name'
                            : null,
                        onFieldSubmitted: (_) async {
                          final navigatorContext = context;
                          if (formKey.currentState?.validate() == true) {
                            await _addCompany(navigatorContext);
                            if (mounted && navigatorContext.mounted) {
                              Navigator.pop(navigatorContext);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _newCompanyController.clear();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigatorContext = context;
                          if (formKey.currentState?.validate() == true) {
                            await _addCompany(navigatorContext);
                            if (mounted && navigatorContext.mounted) {
                              Navigator.pop(navigatorContext);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B1EFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company List'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search companies...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showAddCompanyDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B1EFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCompanies.isEmpty
                    ? const Center(
                        child: Text(
                          'No companies found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final company = _filteredCompanies[index];
                          bool isHovered = false;
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: StatefulBuilder(
                              builder: (context, setCardState) {
                                return GestureDetector(
                                  onTapDown: (_) =>
                                      setCardState(() => isHovered = true),
                                  onTapUp: (_) =>
                                      setCardState(() => isHovered = false),
                                  onTapCancel: () =>
                                      setCardState(() => isHovered = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isHovered
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.02),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            company,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red, size: 20),
                                          onPressed: () =>
                                              _deleteCompany(company),
                                          tooltip: 'Delete company',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
