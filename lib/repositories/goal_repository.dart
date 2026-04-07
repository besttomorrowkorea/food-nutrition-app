import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_goal.dart';

class GoalRepository {
  final FirebaseFirestore _db;

  GoalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<String> save(HealthGoal goal) async {
    final docRef = _db.collection('goals').doc(goal.id);
    await docRef.set(goal.toJson());
    return goal.id;
  }

  Future<HealthGoal?> getActive(String userId) async {
    final snapshot = await _db
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return HealthGoal.fromJson({'id': doc.id, ...doc.data()});
  }

  Future<void> delete(String goalId) async {
    await _db.collection('goals').doc(goalId).delete();
  }
}
