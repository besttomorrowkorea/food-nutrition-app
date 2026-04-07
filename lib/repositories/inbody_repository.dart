import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inbody_record.dart';

class InBodyRepository {
  final FirebaseFirestore _db;

  InBodyRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<String> save(InBodyRecord record) async {
    final docRef = _db.collection('inbody_records').doc(record.id);
    await docRef.set(record.toJson());
    return record.id;
  }

  Future<List<InBodyRecord>> getByUser(String userId, {int limit = 30}) async {
    final snapshot = await _db
        .collection('inbody_records')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => InBodyRecord.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  Future<InBodyRecord?> getLatest(String userId) async {
    final records = await getByUser(userId, limit: 1);
    return records.isEmpty ? null : records.first;
  }

  Future<void> delete(String recordId) async {
    await _db.collection('inbody_records').doc(recordId).delete();
  }
}
