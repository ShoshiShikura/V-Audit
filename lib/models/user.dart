class User {
  final String id;
  final String password;
  final String role;
  final String fullName;
  final bool activated;
  final bool resetRequested;

  User({
    required this.id,
    required this.password,
    required this.role,
    required this.fullName,
    this.activated = false,
    this.resetRequested = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'password': password,
      'role': role,
      'fullName': fullName,
      'activated': activated ? 1 : 0,
      'password_reset_requested': resetRequested ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      password: map['password'],
      role: map['role'],
      fullName: map['fullName'],
      activated: (map['activated'] ?? 0) == 1,
      resetRequested: (map['password_reset_requested'] ?? 0) == 1,
    );
  }
}
