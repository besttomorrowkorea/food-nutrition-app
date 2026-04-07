class InBodyRecord {
  final String id;
  final String userId;
  final DateTime date;
  final double weight; // kg
  final double bodyFatPercentage; // %
  final double skeletalMuscleMass; // kg
  final double bmi;
  final double basalMetabolicRate; // kcal
  final String? scanImageUrl; // OCR 원본 이미지
  final bool isManualEntry;
  final DateTime createdAt;

  InBodyRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.weight,
    required this.bodyFatPercentage,
    required this.skeletalMuscleMass,
    required this.bmi,
    required this.basalMetabolicRate,
    this.scanImageUrl,
    required this.isManualEntry,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': date.toIso8601String(),
        'weight': weight,
        'bodyFatPercentage': bodyFatPercentage,
        'skeletalMuscleMass': skeletalMuscleMass,
        'bmi': bmi,
        'basalMetabolicRate': basalMetabolicRate,
        'scanImageUrl': scanImageUrl,
        'isManualEntry': isManualEntry,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InBodyRecord.fromJson(Map<String, dynamic> json) => InBodyRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        date: DateTime.parse(json['date'] as String),
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        bodyFatPercentage: (json['bodyFatPercentage'] as num?)?.toDouble() ?? 0,
        skeletalMuscleMass: (json['skeletalMuscleMass'] as num?)?.toDouble() ?? 0,
        bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
        basalMetabolicRate: (json['basalMetabolicRate'] as num?)?.toDouble() ?? 0,
        scanImageUrl: json['scanImageUrl'] as String?,
        isManualEntry: json['isManualEntry'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
