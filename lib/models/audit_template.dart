class AuditTemplate {
  final String id;
  final String name;
  final String description;
  final bool isPublished;
  final DateTime createdDate;
  final DateTime lastModified;

  AuditTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.isPublished = false,
    required this.createdDate,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'isPublished': isPublished ? 1 : 0,
        'createdDate': createdDate.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
      };

  factory AuditTemplate.fromMap(Map<String, dynamic> map) => AuditTemplate(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        isPublished: (map['isPublished'] ?? 0) == 1,
        createdDate:
            DateTime.tryParse(map['createdDate']?.toString() ?? '') ??
                DateTime.now(),
        lastModified:
            DateTime.tryParse(map['lastModified']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class TemplateItem {
  final String id;
  final String templateId;
  final String category;
  final String label;
  final String itemType; // 'date_expiry', 'text', 'boolean'
  final bool isMandatory;
  final int sortOrder;

  TemplateItem({
    required this.id,
    required this.templateId,
    required this.category,
    required this.label,
    required this.itemType,
    this.isMandatory = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'templateId': templateId,
        'category': category,
        'label': label,
        'itemType': itemType,
        'isMandatory': isMandatory ? 1 : 0,
        'sortOrder': sortOrder,
      };

  factory TemplateItem.fromMap(Map<String, dynamic> map) => TemplateItem(
        id: map['id'] as String,
        templateId: map['templateId'] as String,
        category: map['category'] as String? ?? '',
        label: map['label'] as String? ?? '',
        itemType: map['itemType'] as String? ?? 'text',
        isMandatory: (map['isMandatory'] ?? 0) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
      );

  TemplateItem copyWith({
    String? id,
    String? templateId,
    String? category,
    String? label,
    String? itemType,
    bool? isMandatory,
    int? sortOrder,
  }) =>
      TemplateItem(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        category: category ?? this.category,
        label: label ?? this.label,
        itemType: itemType ?? this.itemType,
        isMandatory: isMandatory ?? this.isMandatory,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
