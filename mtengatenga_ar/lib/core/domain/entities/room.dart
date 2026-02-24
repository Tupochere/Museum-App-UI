/// Business entity representing a museum room/gallery
class Room {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
