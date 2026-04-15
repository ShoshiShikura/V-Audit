class Team {
  final String id;
  final String documentId;
  final String type;
  final String label;
  final int number;

  Team({
    required this.id,
    required this.documentId,
    required this.type,
    required this.label,
    required this.number,
  });

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      type: map['type'] as String,
      label: map['label'] as String,
      number: map['number'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'type': type,
      'label': label,
      'number': number,
    };
  }
}
