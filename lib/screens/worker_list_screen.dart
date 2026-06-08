import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/worker.dart';
import '../services/backend_service.dart';

class WorkerListScreen extends StatefulWidget {
  final String userId;
  final String role;
  const WorkerListScreen({super.key, required this.userId, required this.role});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  List<Worker> _workers = [];
  List<String> _companies = [];
  bool _isLoading = true;
  final ScrollController _companyScrollController = ScrollController();

  @override
  void dispose() {
    _companyScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final workers = await DatabaseHelper().getWorkers();
    final companies = await DatabaseHelper().getCompanies();
    setState(() {
      _workers = workers;
      _companies = companies;
      _isLoading = false;
    });
  }

  String _maskIC(String ic) {
    if (ic.length <= 4) return '*' * ic.length;
    return '${ic.substring(0, ic.length - 4)}****';
  }

  void _showAddWorkerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final icController = TextEditingController();
    final userIdController = TextEditingController();
    List<String> selectedCompanies = [];
    String status = 'active';

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
              Container(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Add Worker',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              labelText: 'Name', border: OutlineInputBorder()),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Enter name'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: icController,
                          decoration: const InputDecoration(
                              labelText: 'IC/Passport Number',
                              border: OutlineInputBorder()),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Enter IC/Passport Number'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: userIdController,
                          decoration: const InputDecoration(
                              labelText: 'User ID (XL123456)',
                              border: OutlineInputBorder()),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter User ID';
                            }
                            if (!RegExp(r'^XL\d{6}\b').hasMatch(val.trim())) {
                              return 'Format: XL123456';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                          ],
                          onChanged: (val) => status = val ?? 'active',
                          decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        const Text('Company',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: Scrollbar(
                            thumbVisibility: true,
                            controller: _companyScrollController,
                            child: SingleChildScrollView(
                              controller: _companyScrollController,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _companies.map((company) {
                                  final selected =
                                      selectedCompanies.contains(company);
                                  return FilterChip(
                                    label: Text(company),
                                    selected: selected,
                                    onSelected: (sel) {
                                      if (sel) {
                                        selectedCompanies.add(company);
                                      } else {
                                        selectedCompanies.remove(company);
                                      }
                                      (context as Element).markNeedsBuild();
                                    },
                                    selectedColor: const Color(0xFF4B1EFF)
                                        .withValues(alpha: 0.15),
                                    backgroundColor: Colors.grey[100],
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? const Color(0xFF4B1EFF)
                                          : Colors.black87,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: selected
                                            ? const Color(0xFF4B1EFF)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final currentContext = context;
                          if (formKey.currentState?.validate() != true) return;
                          if (selectedCompanies.isEmpty) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              const SnackBar(
                                  content: Text('Select at least one company')),
                            );
                            return;
                          }
                          final worker = Worker(
                            userId: userIdController.text.trim(),
                            name: nameController.text.trim(),
                            ic: icController.text.trim(),
                            companies: selectedCompanies,
                            status: status,
                          );
                          await DatabaseHelper().insertWorker(worker);
                          
                          // Sync to server
                          try {
                            await BackendService.addWorkerToServer(
                              userId: worker.userId,
                              name: worker.name,
                              ic: worker.ic,
                              companies: worker.companies.join(','),
                              status: worker.status,
                            );
                          } catch (_) {}

                          if (!currentContext.mounted) return;
                          Navigator.pop(currentContext);
                          await _loadData();
                          if (currentContext.mounted) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              const SnackBar(content: Text('Worker added locally and synced')),
                            );
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

  Future<void> _deleteWorker(String userId) async {
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
                    const Text('Delete Worker',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 16),
                    const Text(
                      'Are you sure you want to delete this worker?',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
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
      await DatabaseHelper().deleteWorker(userId);
      
      // Sync delete to server
      try {
        await BackendService.deleteWorkerFromServer(userId);
      } catch (_) {}

      await _loadData();
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Worker deleted locally and synced')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker List'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search workers...',
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
                          onChanged: (query) {
                            setState(() {
                              _workers = _workers
                                  .where((w) =>
                                      w.name
                                          .toLowerCase()
                                          .contains(query.toLowerCase()) ||
                                      w.userId
                                          .toLowerCase()
                                          .contains(query.toLowerCase()))
                                  .toList();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddWorkerDialog,
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
                  child: _workers.isEmpty
                      ? const Center(child: Text('No workers found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _workers.length,
                          itemBuilder: (context, index) {
                            final worker = _workers[index];
                            final isActive =
                                worker.status.toLowerCase() == 'active';
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
                                      duration:
                                          const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: isHovered
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: Offset(0, 4),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.02),
                                                  blurRadius: 2,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        worker.name,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? const Color(
                                                                0xFFC8E6C9)
                                                            : const Color(
                                                                0xFFFFCDD2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        isActive
                                                            ? 'Active'
                                                            : 'Inactive',
                                                        style: TextStyle(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF388E3C)
                                                              : const Color(
                                                                  0xFFD32F2F),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 0,
                                                      vertical: 0),
                                                  margin: const EdgeInsets.only(
                                                      bottom: 2),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                          border: Border.all(
                                                              color: Colors.grey
                                                                  .shade300),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          worker.companies
                                                              .join(", "),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .black87),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                    'User ID: ${worker.userId}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black54)),
                                                const SizedBox(height: 2),
                                                Text(
                                                    'IC Number: ${_maskIC(worker.ic)}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black54,
                                                        letterSpacing: 2)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 22),
                                            onPressed: () =>
                                                _deleteWorker(worker.userId),
                                            tooltip: 'Remove worker',
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
