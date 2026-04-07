class HealthGoal {
  final String id;
  final String userId;
  final String type; // diet / muscle / fitness
  final double? targetWeight;
  final double? targetBodyFat;
  final DateTime targetDate;
  final Map<String, dynamic> roadmapData; // 구조화된 로드맵 (주차별 계획)
  final String roadmapText; // 표시용 텍스트 (마크다운)
  final DateTime roadmapCreatedAt;
  final DateTime createdAt;

  HealthGoal({
    required this.id,
    required this.userId,
    required this.type,
    this.targetWeight,
    this.targetBodyFat,
    required this.targetDate,
    required this.roadmapData,
    required this.roadmapText,
    required this.roadmapCreatedAt,
    required this.createdAt,
  });

  String get typeKr {
    switch (type) {
      case 'diet':
        return '다이어트';
      case 'muscle':
        return '근육 증가';
      case 'fitness':
        return '체력 향상';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'targetWeight': targetWeight,
        'targetBodyFat': targetBodyFat,
        'targetDate': targetDate.toIso8601String(),
        'roadmapData': roadmapData,
        'roadmapText': roadmapText,
        'roadmapCreatedAt': roadmapCreatedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory HealthGoal.fromJson(Map<String, dynamic> json) => HealthGoal(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: json['type'] as String? ?? 'fitness',
        targetWeight: (json['targetWeight'] as num?)?.toDouble(),
        targetBodyFat: (json['targetBodyFat'] as num?)?.toDouble(),
        targetDate: DateTime.parse(json['targetDate'] as String),
        roadmapData:
            (json['roadmapData'] as Map<String, dynamic>?) ?? {},
        roadmapText: json['roadmapText'] as String? ?? '',
        roadmapCreatedAt:
            DateTime.parse(json['roadmapCreatedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
