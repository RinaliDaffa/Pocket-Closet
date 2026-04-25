class OutfitModel {
  final int? id;
  final String name;
  final String occasion; // 'casual' | 'formal' | 'sport' | 'hangout'
  final bool isOotd;
  final String? userId;
  final String? firestoreId;
  final DateTime createdAt;

  OutfitModel({
    this.id,
    required this.name,
    required this.occasion,
    this.isOotd = false,
    this.userId,
    this.firestoreId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'occasion': occasion,
      'isOotd': isOotd ? 1 : 0,
      'userId': userId,
      'firestoreId': firestoreId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'occasion': occasion,
      'isOotd': isOotd,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OutfitModel.fromMap(Map<String, dynamic> map) {
    return OutfitModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      occasion: map['occasion'] as String,
      isOotd: (map['isOotd'] as int? ?? 0) == 1,
      userId: map['userId'] as String?,
      firestoreId: map['firestoreId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  OutfitModel copyWith({
    int? id,
    String? name,
    String? occasion,
    bool? isOotd,
    String? userId,
    String? firestoreId,
    DateTime? createdAt,
  }) {
    return OutfitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      occasion: occasion ?? this.occasion,
      isOotd: isOotd ?? this.isOotd,
      userId: userId ?? this.userId,
      firestoreId: firestoreId ?? this.firestoreId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}