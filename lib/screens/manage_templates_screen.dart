import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/audit_template.dart';
import 'edit_template_screen.dart';

class ManageTemplatesScreen extends StatefulWidget {
  final String userId;
  final String role;

  const ManageTemplatesScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<ManageTemplatesScreen> createState() => _ManageTemplatesScreenState();
}

class _ManageTemplatesScreenState extends State<ManageTemplatesScreen> {
  List<AuditTemplate> _templates = [];
  Map<String, int> _itemCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final templates = await db.getAllTemplates();
    final counts = <String, int>{};
    for (final t in templates) {
      counts[t.id] = await db.getTemplateItemCount(t.id);
    }
    setState(() {
      _templates = templates;
      _itemCounts = counts;
      _isLoading = false;
    });
  }

  void _createNewTemplate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTemplateScreen(
          userId: widget.userId,
          role: widget.role,
        ),
      ),
    );
    if (result == true) _loadTemplates();
  }

  void _editTemplate(AuditTemplate template) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTemplateScreen(
          userId: widget.userId,
          role: widget.role,
          templateId: template.id,
        ),
      ),
    );
    if (result == true) _loadTemplates();
  }

  Future<void> _setActiveTemplate(AuditTemplate template) async {
    if (!template.isPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only published templates can be set as active.')),
      );
      return;
    }
    await DatabaseHelper().setActiveTemplate(template.id);
    await _loadTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${template.name}" is now the active template.')),
    );
  }

  Future<void> _deleteTemplate(AuditTemplate template) async {
    final currentContext = context;

    // Prevent deleting the active template
    if (template.isActive) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot delete the active template. Set another template as active first.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Delete Template',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure you want to delete "${template.name}"?\n\nThis action cannot be undone.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
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
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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
      await DatabaseHelper().deleteTemplate(template.id);
      await _loadTemplates();
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Template deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Templates'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTemplate,
        backgroundColor: const Color(0xFF4B1EFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create New'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No templates yet',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('Tap "Create New" to get started',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        final itemCount = _itemCounts[template.id] ?? 0;
                        return _TemplateCard(
                          template: template,
                          itemCount: itemCount,
                          onTap: () => _editTemplate(template),
                          onDelete: () => _deleteTemplate(template),
                          onSetActive: () => _setActiveTemplate(template),
                        );
                      },
                    ),
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final AuditTemplate template;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;

  const _TemplateCard({
    required this.template,
    required this.itemCount,
    required this.onTap,
    required this.onDelete,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(template.lastModified);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: template.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : const Color(0xFF4B1EFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    template.isActive ? Icons.check_circle : Icons.article,
                    color: template.isActive
                        ? Colors.green
                        : const Color(0xFF4B1EFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              template.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (template.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (template.description.isNotEmpty)
                        Text(
                          template.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!template.isActive)
                  IconButton(
                    icon: const Icon(Icons.star_border,
                        color: Color(0xFF4B1EFF), size: 20),
                    onPressed: onSetActive,
                    tooltip: 'Set as Active',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(
                  Icons.checklist,
                  '$itemCount items',
                  const Color(0xFF4B1EFF),
                ),
                const SizedBox(width: 8),
                _infoChip(
                  Icons.calendar_today,
                  dateStr,
                  Colors.grey,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: template.isPublished
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: template.isPublished
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    template.isPublished ? 'Published' : 'Draft',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          template.isPublished ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(text,
              style:
                  TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}
