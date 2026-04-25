class ClothingModel {
  final int? id;
  final String name;
  final String brand;
  final String color;
  final String? imagePath;
  final int categoryId;
  final String status; // 'clean' | 'dirty' | 'laundry'
  final int wearCount;
  final String? firestoreId;
  final String? userId;
  final DateTime createdAt;

  ClothingModel({
    this.id,
    required this.name,
    required this.brand,
    required this.color,
    this.imagePath,
    required this.categoryId,
    this.status = 'clean',
    this.wearCount = 0,
    this.firestoreId,
    this.userId,
    required this.createdAt,
  });

  // Untuk simpan ke SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'color': color,
      'imagePath': imagePath,
      'categoryId': categoryId,
      'status': status,
      'wearCount': wearCount,
      'firestoreId': firestoreId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Untuk simpan ke Firestore (tanpa imagePath, tanpa id lokal)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'brand': brand,
      'color': color,
      'categoryId': categoryId,
      'status': status,
      'wearCount': wearCount,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClothingModel.fromMap(Map<String, dynamic> map) {
    return ClothingModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      brand: map['brand'] as String? ?? '',
      color: map['color'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      categoryId: map['categoryId'] as int,
      status: map['status'] as String? ?? 'clean',
      wearCount: map['wearCount'] as int? ?? 0,
      firestoreId: map['firestoreId'] as String?,
      userId: map['userId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Untuk update sebagian field saja
  ClothingModel copyWith({
    int? id,
    String? name,
    String? brand,
    String? color,
    String? imagePath,
    int? categoryId,
    String? status,
    int? wearCount,
    String? firestoreId,
    String? userId,
    DateTime? createdAt,
  }) {
    return ClothingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      wearCount: wearCount ?? this.wearCount,
      firestoreId: firestoreId ?? this.firestoreId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}