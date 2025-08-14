class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final int storageUsed;
  final int storageLimit;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.storageUsed = 0,
    this.storageLimit = 1073741824, // 1GB default
  });

  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'storage_used': storageUsed,
      'storage_limit': storageLimit,
    };
  }

  // Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      storageUsed: json['storage_used'] as int? ?? 0,
      storageLimit: json['storage_limit'] as int? ?? 1073741824,
    );
  }

  // Create a copy of User with updated fields
  User copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    int? storageUsed,
    int? storageLimit,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User{id: $id, email: $email, name: $name}';
  }
}
