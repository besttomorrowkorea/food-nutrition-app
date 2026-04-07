class NutritionRecord {
  final String id;
  final String userId;
  final DateTime date;
  final String mealType; // breakfast / lunch / dinner / snack
  final String foodName;
  final String? foodImageUrl;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final DateTime createdAt;

  NutritionRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.foodName,
    this.foodImageUrl,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': date.toIso8601String(),
        'mealType': mealType,
        'foodName': foodName,
        'foodImageUrl': foodImageUrl,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NutritionRecord.fromJson(Map<String, dynamic> json) =>
      NutritionRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        date: DateTime.parse(json['date'] as String),
        mealType: json['mealType'] as String? ?? 'snack',
        foodName: json['foodName'] as String? ?? '알 수 없음',
        foodImageUrl: json['foodImageUrl'] as String?,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
