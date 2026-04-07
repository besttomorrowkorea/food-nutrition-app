import 'package:cloud_functions/cloud_functions.dart';

class ChatService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> chat({
    required String message,
    Map<String, dynamic>? context,
  }) async {
    final callable = _functions.httpsCallable(
      'chatWithAI',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'message': message,
        'context': context ?? {},
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception('AI 응답에 실패했습니다.');
      }
      return data['reply'] as String;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception('일일 한도 초과: ${e.message}');
      }
      throw Exception('챗 오류: ${e.message}');
    }
  }
}
