class AuditTemplate {
  final String id;
  final String name;
  final String description;
  final bool isPublished;
  final bool isActive;
  final DateTime createdDate;
  final DateTime lastModified;

  AuditTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.isPublished = false,
    this.isActive = false,
    required this.createdDate,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'isPublished': isPublished ? 1 : 0,
        'isActive': isActive ? 1 : 0,
        'createdDate': createdDate.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
      };

  factory AuditTemplate.fromMap(Map<String, dynamic> map) => AuditTemplate(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        isPublished: (map['isPublished'] ?? 0) == 1,
        isActive: (map['isActive'] ?? 0) == 1,
        createdDate:
            DateTime.tryParse(map['createdDate']?.toString() ?? '') ??
                DateTime.now(),
        lastModified:
            DateTime.tryParse(map['lastModified']?.toString() ?? '') ??
                DateTime.now(),
      );

  AuditTemplate copyWith({
    String? id,
    String? name,
    String? description,
    bool? isPublished,
    bool? isActive,
    DateTime? createdDate,
    DateTime? lastModified,
  }) =>
      AuditTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        isPublished: isPublished ?? this.isPublished,
        isActive: isActive ?? this.isActive,
        createdDate: createdDate ?? this.createdDate,
        lastModified: lastModified ?? this.lastModified,
      );
}

class TemplateItem {
  final String id;
  final String templateId;
  final String section; // 'profiling_team', 'summary_team', 'company_name', 'finding_summary'
  final String category;
  final String label;
  final String itemType; // 'date_expiry', 'text', 'boolean'
  final bool isMandatory;
  final int sortOrder;
  final bool isDefault; // true = from default VMM checklist
  final String defaultKey; // stable key like 'ntsmp_expiry', 'ppe', etc.

  TemplateItem({
    required this.id,
    required this.templateId,
    this.section = 'profiling_team',
    required this.category,
    required this.label,
    required this.itemType,
    this.isMandatory = false,
    this.sortOrder = 0,
    this.isDefault = false,
    this.defaultKey = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'templateId': templateId,
        'section': section,
        'category': category,
        'label': label,
        'itemType': itemType,
        'isMandatory': isMandatory ? 1 : 0,
        'sortOrder': sortOrder,
        'isDefault': isDefault ? 1 : 0,
        'defaultKey': defaultKey,
      };

  factory TemplateItem.fromMap(Map<String, dynamic> map) => TemplateItem(
        id: map['id'] as String,
        templateId: map['templateId'] as String,
        section: map['section'] as String? ?? 'profiling_team',
        category: map['category'] as String? ?? '',
        label: map['label'] as String? ?? '',
        itemType: map['itemType'] as String? ?? 'text',
        isMandatory: (map['isMandatory'] ?? 0) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        isDefault: (map['isDefault'] ?? 0) == 1,
        defaultKey: map['defaultKey'] as String? ?? '',
      );

  TemplateItem copyWith({
    String? id,
    String? templateId,
    String? section,
    String? category,
    String? label,
    String? itemType,
    bool? isMandatory,
    int? sortOrder,
    bool? isDefault,
    String? defaultKey,
  }) =>
      TemplateItem(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        section: section ?? this.section,
        category: category ?? this.category,
        label: label ?? this.label,
        itemType: itemType ?? this.itemType,
        isMandatory: isMandatory ?? this.isMandatory,
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault ?? this.isDefault,
        defaultKey: defaultKey ?? this.defaultKey,
      );
}

/// All default VMM template items with their section and defaultKey.
/// Used when seeding the DB and when building the default checklist UI.
class DefaultTemplateItems {
  static const String sectionProfilingTeam = 'profiling_team';
  static const String sectionSummaryTeam = 'summary_team';
  static const String sectionCompanyName = 'company_name';
  static const String sectionFindingSummary = 'finding_summary';

  static const List<String> allSections = [
    sectionProfilingTeam,
    sectionSummaryTeam,
    sectionCompanyName,
    sectionFindingSummary,
  ];

  static String sectionLabel(String section) {
    switch (section) {
      case sectionProfilingTeam:
        return 'Profiling Team';
      case sectionSummaryTeam:
        return 'Summary Team';
      case sectionCompanyName:
        return 'Company Name';
      case sectionFindingSummary:
        return 'Finding & Summary';
      default:
        return section;
    }
  }

  /// The canonical list of all default template items.
  static List<Map<String, dynamic>> get all => [
        // ── Profiling Team ──
        {'defaultKey': 'worker_name', 'section': sectionProfilingTeam, 'category': 'Identity', 'label': 'Worker Name', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 0},
        {'defaultKey': 'ic_passport', 'section': sectionProfilingTeam, 'category': 'Identity', 'label': 'IC / Passport Number', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 1},
        {'defaultKey': 'attendance', 'section': sectionProfilingTeam, 'category': 'Attendance', 'label': 'Attendance', 'itemType': 'boolean', 'isMandatory': 1, 'sortOrder': 2},
        {'defaultKey': 'ntsmp_expiry', 'section': sectionProfilingTeam, 'category': 'Certification', 'label': 'NTSMP Expiry', 'itemType': 'date_expiry', 'isMandatory': 1, 'sortOrder': 3},
        {'defaultKey': 'aesp_expiry', 'section': sectionProfilingTeam, 'category': 'Certification', 'label': 'AESP Expiry', 'itemType': 'date_expiry', 'isMandatory': 1, 'sortOrder': 4},
        {'defaultKey': 'agtes_expiry', 'section': sectionProfilingTeam, 'category': 'Certification', 'label': 'AGTES Expiry', 'itemType': 'date_expiry', 'isMandatory': 1, 'sortOrder': 5},
        {'defaultKey': 'pole_proficiency', 'section': sectionProfilingTeam, 'category': 'Competency', 'label': 'Pole Proficiency', 'itemType': 'boolean', 'isMandatory': 1, 'sortOrder': 6},
        {'defaultKey': 'ca2a_expiry', 'section': sectionProfilingTeam, 'category': 'Certification', 'label': 'CA2A Expiry', 'itemType': 'date_expiry', 'isMandatory': 0, 'sortOrder': 7},
        {'defaultKey': 'ca2c_expiry', 'section': sectionProfilingTeam, 'category': 'Certification', 'label': 'CA2C Expiry', 'itemType': 'date_expiry', 'isMandatory': 0, 'sortOrder': 8},
        // ── Summary Team ──
        {'defaultKey': 'type_of_team', 'section': sectionSummaryTeam, 'category': 'Summary', 'label': 'Type of Team', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 0},
        {'defaultKey': 'ppe', 'section': sectionSummaryTeam, 'category': 'Summary', 'label': 'PPE', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 1},
        {'defaultKey': 'competency', 'section': sectionSummaryTeam, 'category': 'Summary', 'label': 'Competency', 'itemType': 'boolean', 'isMandatory': 1, 'sortOrder': 2},
        // ── Company Name ──
        {'defaultKey': 'member_selection', 'section': sectionCompanyName, 'category': 'Team', 'label': 'Member Selection', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 0},
        {'defaultKey': 'attachment', 'section': sectionCompanyName, 'category': 'Evidence', 'label': 'Attachment (Photo)', 'itemType': 'text', 'isMandatory': 1, 'sortOrder': 1},
        {'defaultKey': 'company_remark', 'section': sectionCompanyName, 'category': 'Notes', 'label': 'Remark', 'itemType': 'text', 'isMandatory': 0, 'sortOrder': 2},
        // ── Finding & Summary ──
        {'defaultKey': 'finding_remark', 'section': sectionFindingSummary, 'category': 'Notes', 'label': 'Remark', 'itemType': 'text', 'isMandatory': 0, 'sortOrder': 0},
      ];
}
