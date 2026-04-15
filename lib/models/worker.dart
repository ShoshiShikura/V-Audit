class Worker {
  final String userId;
  final String name;
  final String ic;
  final List<String> companies;
  final String status; // 'active' or 'inactive'

  Worker({
    required this.userId,
    required this.name,
    required this.ic,
    required this.companies,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'ic': ic,
      'companies': companies.join(','),
      'status': status,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      userId: map['userId'] as String,
      name: map['name'] as String,
      ic: map['ic'] as String,
      companies: (map['companies'] as String).split(','),
      status: map['status'] as String,
    );
  }
}
