class Child {
  final String id;
  final String userId;
  final String fullName;
  final int age;
  final String? school;
  final String? photoUrl;
  final DateTime createdAt;

  Child({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.age,
    this.school,
    this.photoUrl,
    required this.createdAt,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      age: json['age'] ?? 0,
      school: json['school'],
      photoUrl: json['photo_url'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'age': age,
      'school': school,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return '$fullName ($age лет)';
  }
}
