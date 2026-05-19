import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/audit_template.dart';
import '../services/backend_service.dart';

class EditTemplateScreen extends StatefulWidget {
  final String userId;
  final String role;
  final String? templateId; // null = create new

  const EditTemplateScreen({
    super.key,
    required this.userId,
    required this.role,
    this.templateId,
  });

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  /// Which default items are checked (keyed by defaultKey).
  final Map<String, bool> _defaultChecks = {};

  /// Custom (non-default) items added by the user.
  List<TemplateItem> _customItems = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    // Initialize all defaults as checked
    for (final item in DefaultTemplateItems.all) {
      _defaultChecks[item['defaultKey'] as String] = true;
    }

    if (_isEditing) {
      final db = DatabaseHelper();
      final template = await db.getTemplate(widget.templateId!);
      final items = await db.getTemplateItems(widget.templateId!);
      if (template != null) {
        _nameController.text = template.name;
        _descController.text = template.description;

        // Uncheck all defaults first, then re-check only those present
        for (final key in _defaultChecks.keys.toList()) {
          _defaultChecks[key] = false;
        }
        for (final item in items) {
          if (item.isDefault && item.defaultKey.isNotEmpty) {
            _defaultChecks[item.defaultKey] = true;
          }
        }

        // Separate custom items
        _customItems = items.where((i) => !i.isDefault).toList();
      }
    }
    setState(() => _isLoading = false);
  }

  String _generateId() =>
      'tmpl_${DateTime.now().millisecondsSinceEpoch}_${_customItems.length}';

  void _addCustomItem() {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController();
    String section = DefaultTemplateItems.sectionProfilingTeam;
    String category = 'Other';
    String itemType = 'text';
    bool isMandatory = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add Custom Field',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 20),
                    // Section dropdown
                    DropdownButtonFormField<String>(
                      initialValue: section,
                      items: DefaultTemplateItems.allSections.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(DefaultTemplateItems.sectionLabel(s)),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => section = val ?? section),
                      decoration: InputDecoration(
                        labelText: 'Section (Page)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Label
                    TextFormField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'Field Label',
                        hintText: 'e.g. Safety Induction Expiry',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Enter a label'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Category
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: const [
                        DropdownMenuItem(
                            value: 'Identity', child: Text('Identity')),
                        DropdownMenuItem(
                            value: 'Attendance', child: Text('Attendance')),
                        DropdownMenuItem(
                            value: 'Certification',
                            child: Text('Certification')),
                        DropdownMenuItem(
                            value: 'Competency', child: Text('Competency')),
                        DropdownMenuItem(
                            value: 'Summary', child: Text('Summary')),
                        DropdownMenuItem(
                            value: 'Evidence', child: Text('Evidence')),
                        DropdownMenuItem(
                            value: 'Notes', child: Text('Notes')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => category = val ?? category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Item type
                    DropdownButtonFormField<String>(
                      initialValue: itemType,
                      items: const [
                        DropdownMenuItem(
                            value: 'text', child: Text('📝 Text Input')),
                        DropdownMenuItem(
                            value: 'date_expiry',
                            child: Text('📅 Date (Expiry Check)')),
                        DropdownMenuItem(
                            value: 'boolean', child: Text('✅ Yes / No')),
                      ],
                      onChanged: (val) => itemType = val ?? itemType,
                      decoration: InputDecoration(
                        labelText: 'Field Type',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mandatory toggle
                    SwitchListTile(
                      title: const Text('Mandatory'),
                      subtitle: const Text('Flag this field as required'),
                      value: isMandatory,
                      onChanged: (val) =>
                          setDialogState(() => isMandatory = val),
                      activeThumbColor: const Color(0xFF4B1EFF),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    Row(
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
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }
                              final newItem = TemplateItem(
                                id: _generateId(),
                                templateId: widget.templateId ?? '',
                                section: section,
                                category: category,
                                label: labelController.text.trim(),
                                itemType: itemType,
                                isMandatory: isMandatory,
                                sortOrder: _customItems.length,
                                isDefault: false,
                                defaultKey: '',
                              );
                              setState(() => _customItems.add(newItem));
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B1EFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeCustomItem(int index) {
    setState(() => _customItems.removeAt(index));
  }

  /// Build all the TemplateItems to save (default checked + custom).
  List<TemplateItem> _buildAllItems(String templateId) {
    final List<TemplateItem> allItems = [];
    int sortOrder = 0;

    // Add checked default items
    for (final def in DefaultTemplateItems.all) {
      final key = def['defaultKey'] as String;
      if (_defaultChecks[key] == true) {
        allItems.add(TemplateItem(
          id: '${templateId}_default_$key',
          templateId: templateId,
          section: def['section'] as String,
          category: def['category'] as String,
          label: def['label'] as String,
          itemType: def['itemType'] as String,
          isMandatory: (def['isMandatory'] as int) == 1,
          sortOrder: sortOrder++,
          isDefault: true,
          defaultKey: key,
        ));
      }
    }

    // Add custom items
    for (int i = 0; i < _customItems.length; i++) {
      allItems.add(_customItems[i].copyWith(
        templateId: templateId,
        sortOrder: sortOrder++,
        id: _customItems[i].id.isEmpty
            ? '${templateId}_custom_$i'
            : null,
      ));
    }

    return allItems;
  }

  Future<void> _saveTemplate({required bool publish}) async {
    final currentContext = context;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Template name is required.')),
      );
      return;
    }

    // Check at least one item
    final hasCheckedDefaults = _defaultChecks.values.any((v) => v);
    if (!hasCheckedDefaults && _customItems.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Template must have at least one field.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper();
      final now = DateTime.now();
      final templateId = widget.templateId ??
          'tmpl_${now.millisecondsSinceEpoch}';

      final template = AuditTemplate(
        id: templateId,
        name: name,
        description: _descController.text.trim(),
        isPublished: publish,
        isActive: false, // Active is managed separately from Manage Templates
        createdDate: _isEditing
            ? (await db.getTemplate(templateId))?.createdDate ?? now
            : now,
        lastModified: now,
      );

      if (_isEditing) {
        // Preserve isActive status when updating
        final existing = await db.getTemplate(templateId);
        final updatedTemplate = template.copyWith(
          isActive: existing?.isActive ?? false,
        );
        await db.updateTemplate(updatedTemplate);
      } else {
        await db.insertTemplate(template);
      }

      // Build and save all items
      final allItems = _buildAllItems(templateId);
      await db.replaceTemplateItems(templateId, allItems);

      // Best-effort sync to XAMPP
      if (publish) {
        try {
          await BackendService.publishTemplate(
            templateId: templateId,
            name: name,
            itemCount: allItems.length,
          );
        } catch (_) {
          // Non-blocking
        }
      }

      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(publish
              ? 'Template published successfully!'
              : 'Template saved as draft.'),
        ),
      );
      Navigator.pop(currentContext, true);
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Error saving template: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'date_expiry':
        return Icons.event;
      case 'text':
        return Icons.text_fields;
      case 'boolean':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'date_expiry':
        return Colors.blue;
      case 'text':
        return Colors.deepPurple;
      case 'boolean':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'date_expiry':
        return 'Date Expiry';
      case 'text':
        return 'Text';
      case 'boolean':
        return 'Yes / No';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Template' : 'New Template'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Template name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Template Name',
                          hintText: 'e.g. VMM Standard Audit',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Enter template name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      // Description
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════════
                      // SECTION A: Default Fields Checklist
                      // ══════════════════════════════════════════════
                      _buildSectionHeader(
                        'Default Fields',
                        Icons.checklist,
                        'Toggle VMM standard fields on/off',
                      ),
                      const SizedBox(height: 12),

                      // Group defaults by section
                      for (final section in DefaultTemplateItems.allSections) ...[
                        _buildSectionSubheader(
                          DefaultTemplateItems.sectionLabel(section),
                        ),
                        ..._buildDefaultChecklistForSection(section),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════════
                      // SECTION B: Custom Fields
                      // ══════════════════════════════════════════════
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Custom Fields',
                            Icons.add_box_outlined,
                            'Add your own fields to any section',
                          ),
                          ElevatedButton.icon(
                            onPressed: _addCustomItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Field'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B1EFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_customItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.playlist_add,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No custom fields yet',
                                    style: TextStyle(color: Colors.grey)),
                                Text('Tap "Add Field" to create custom fields',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        // Group custom items by section
                        for (final section in DefaultTemplateItems.allSections) ...[
                          ..._buildCustomItemsForSection(section),
                        ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              // Bottom action bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _saveTemplate(publish: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B1EFF),
                            side: const BorderSide(color: Color(0xFF4B1EFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save Draft',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _saveTemplate(publish: true),
                          icon: const Icon(Icons.publish, size: 20),
                          label: const Text('Publish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B1EFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSaving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4B1EFF), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSubheader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4B1EFF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined,
              size: 16, color: const Color(0xFF4B1EFF)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF4B1EFF),
              )),
        ],
      ),
    );
  }

  List<Widget> _buildDefaultChecklistForSection(String section) {
    final items = DefaultTemplateItems.all
        .where((item) => item['section'] == section)
        .toList();

    return items.map((item) {
      final key = item['defaultKey'] as String;
      final label = item['label'] as String;
      final type = item['itemType'] as String;

      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: CheckboxListTile(
          value: _defaultChecks[key] ?? false,
          onChanged: (val) {
            setState(() => _defaultChecks[key] = val ?? false);
          },
          title: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Row(
            children: [
              Icon(_typeIcon(type), size: 14, color: _typeColor(type)),
              const SizedBox(width: 4),
              Text(_typeLabel(type),
                  style: TextStyle(fontSize: 11, color: _typeColor(type))),
            ],
          ),
          activeColor: const Color(0xFF4B1EFF),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }).toList();
  }

  List<Widget> _buildCustomItemsForSection(String section) {
    final items = _customItems
        .where((i) => i.section == section)
        .toList();
    if (items.isEmpty) return [];

    return [
      _buildSectionSubheader(
          '${DefaultTemplateItems.sectionLabel(section)} (Custom)'),
      ...items.map((item) {
        final index = _customItems.indexOf(item);
        return _CustomItemTile(
          key: ValueKey(item.id),
          item: item,
          onDelete: () => _removeCustomItem(index),
          typeIcon: _typeIcon(item.itemType),
          typeColor: _typeColor(item.itemType),
          typeLabel: _typeLabel(item.itemType),
        );
      }),
      const SizedBox(height: 8),
    ];
  }
}

class _CustomItemTile extends StatelessWidget {
  final TemplateItem item;
  final VoidCallback onDelete;
  final IconData typeIcon;
  final Color typeColor;
  final String typeLabel;

  const _CustomItemTile({
    super.key,
    required this.item,
    required this.onDelete,
    required this.typeIcon,
    required this.typeColor,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(typeIcon, color: typeColor, size: 20),
        ),
        title: Text(
          item.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                item.category,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(fontSize: 10, color: typeColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.isMandatory
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.isMandatory
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item.isMandatory ? 'Required' : 'Optional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.isMandatory ? Colors.red : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
