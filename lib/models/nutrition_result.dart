class NutritionResult {
  final String foodName;
  final String foodNameEn;
  final String servingSize;
  final int calories;
  final Nutrients nutrients;
  final String confidence;
  final String description;

  NutritionResult({
    required this.foodName,
    required this.foodNameEn,
    required this.servingSize,
    required this.calories,
    required this.nutrients,
    required this.confidence,
    required this.description,
  });

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    return NutritionResult(
      foodName: json['food_name'] ?? '알 수 없음',
      foodNameEn: json['food_name_en'] ?? 'Unknown',
      servingSize: json['serving_size'] ?? '-',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      nutrients: Nutrients.fromJson(json['nutrients'] ?? {}),
      confidence: json['confidence'] ?? 'low',
      description: json['description'] ?? '',
    );
  }

  /// 신뢰도를 한국어로 변환
  String get confidenceKr {
    switch (confidence) {
      case 'high':
        return '높음';
      case 'medium':
        return '보통';
      case 'low':
        return '낮음';
      default:
        return '알 수 없음';
    }
  }
}

class Nutrients {
  final double carbohydrates;
  final double protein;
  final double fat;
  final double saturatedFat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double cholesterol;

  Nutrients({
    required this.carbohydrates,
    required this.protein,
    required this.fat,
    required this.saturatedFat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
  });

  factory Nutrients.fromJson(Map<String, dynamic> json) {
    return Nutrients(
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
      cholesterol: (json['cholesterol'] as num?)?.toDouble() ?? 0,
    );
  }
}
