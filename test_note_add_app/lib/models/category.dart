class Category {
  final String id;
  final String name;
  final String color;
  final int noteCount;
  final String userId;

  Category({
    required this.id,
    required this.name,
    required this.color,
    this.noteCount = 0,
    required this.userId,
  });

  // Convert Category to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'note_count': noteCount,
      'user_id': userId,
    };
  }

  // Create Category from JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      noteCount: json['note_count'] as int? ?? 0,
      userId: json['user_id'] as String,
    );
  }

  // Create Category from database map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      noteCount: map['note_count'] as int? ?? 0,
      userId: map['user_id'] as String,
    );
  }

  // Convert Category to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'note_count': noteCount,
      'user_id': userId,
    };
  }

  // Create a copy of Category with updated fields
  Category copyWith({
    String? id,
    String? name,
    String? color,
    int? noteCount,
    String? userId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      noteCount: noteCount ?? this.noteCount,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Category{id: $id, name: $name, noteCount: $noteCount}';
  }
}
