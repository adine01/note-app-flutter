class Note {
  final String id;
  final String title;
  final String content;
  final String? category;
  final List<String> tags;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    this.tags = const [],
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  // Convert Note to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'archived': archived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
    };
  }

  // Create Note from JSON
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      archived: json['archived'] == 1 || json['archived'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userId: json['user_id'] as String,
    );
  }

  // Create Note from database map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String?,
      tags: map['tags'] != null
          ? (map['tags'] as String)
                .split(',')
                .where((tag) => tag.isNotEmpty)
                .toList()
          : [],
      archived: map['archived'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String,
    );
  }

  // Convert Note to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags.join(','),
      'archived': archived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
    };
  }

  // Create a copy of Note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Note{id: $id, title: $title, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...}';
  }
}
