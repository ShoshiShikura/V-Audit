class Document {
  final String id;
  final String title;
  final String description;
  final String type;
  final DateTime createdDate;
  final DateTime lastModified;
  final String fileName;
  final bool isDraft;
  final String ownerId;
  final String location;
  final String auditor;
  final String templateId; // Links to the audit template used
  final String status; // draft, pending, approved, rejected
  final String rejectionRemark;

  Document({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdDate,
    required this.lastModified,
    required this.fileName,
    required this.isDraft,
    required this.ownerId,
    required this.location,
    required this.auditor,
    this.templateId = 'default_vmm_template',
    this.status = 'draft',
    this.rejectionRemark = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'createdDate': createdDate.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'fileName': fileName,
      'isDraft': isDraft ? 1 : 0,
      'ownerId': ownerId,
      'location': location,
      'auditor': auditor,
      'templateId': templateId,
      'status': status,
      'rejectionRemark': rejectionRemark,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      type: map['type'],
      createdDate: DateTime.parse(map['createdDate']),
      lastModified: DateTime.parse(map['lastModified']),
      fileName: map['fileName'],
      isDraft: map['isDraft'] == 1,
      ownerId: map['ownerId'],
      location: map['location'] ?? '',
      auditor: map['auditor'] ?? '',
      templateId: map['templateId'] as String? ?? 'default_vmm_template',
      status: map['status'] as String? ?? 'draft',
      rejectionRemark: map['rejectionRemark'] as String? ?? '',
    );
  }

  String get companyName => description;
}
