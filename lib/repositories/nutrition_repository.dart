import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nutrition_record.dart';

abstract class NutritionRepository {
  /// 영양 분석 결과를 기록으로 저장 (유료)
  Future<String> saveRecord(NutritionRecord record);

  /// 날짜별 영양 기록 조회
  Future<List<NutritionRecord>> getRecordsByDate(
      String userId, DateTime date);

  /// 날짜 범위 영양 기록 조회 (히스토리)
  Future<List<NutritionRecord>> getRecordsByDateRange(
      String userId, DateTime from, DateTime to);

  /// 기록 삭제
  Future<void> deleteRecord(String recordId);
}

class FirestoreNutritionRepository implements NutritionRepository {
  final FirebaseFirestore _db;

  FirestoreNutritionRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<String> saveRecord(NutritionRecord record) async {
    final docRef = _db.collection('nutrition_records').doc(record.id);
    await docRef.set(record.toJson());
    return record.id;
  }

  @override
  Future<List<NutritionRecord>> getRecordsByDate(
      String userId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await _db
        .collection('nutrition_records')
        .where('userId', isEqualTo: userId)
        .where('date',
            isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => NutritionRecord.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  @override
  Future<List<NutritionRecord>> getRecordsByDateRange(
      String userId, DateTime from, DateTime to) async {
    final snapshot = await _db
        .collection('nutrition_records')
        .where('userId', isEqualTo: userId)
        .where('date',
            isGreaterThanOrEqualTo: from.toIso8601String())
        .where('date',
            isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => NutritionRecord.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await _db.collection('nutrition_records').doc(recordId).delete();
  }
}
