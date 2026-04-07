import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import '../models/nutrition_result.dart';

class NutritionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 이미지 파일을 분석하여 영양소 정보를 반환
  Future<NutritionResult> analyzeFood(File imageFile) async {
    // compute() 아이솔레이트에서 이미지 처리 (UI 스레드 블로킹 방지)
    final base64Image = await compute(_processImageIsolate, imageFile.path);

    // Firebase Cloud Function 호출 (서버 120s → 클라이언트 90s)
    final callable = _functions.httpsCallable(
      'analyzeFood',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64Image,
      });

      final data = result.data;

      if (data['success'] != true) {
        throw Exception('분석에 실패했습니다.');
      }

      final analysisData = data['data'] as Map<String, dynamic>;

      // 음식이 아닌 경우 처리
      if (analysisData['error'] == true) {
        throw FoodNotRecognizedException(
          analysisData['message'] ?? '음식을 인식할 수 없습니다.',
        );
      }

      return NutritionResult.fromJson(analysisData);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'UNAUTHENTICATED' || e.code == 'unauthenticated') {
        throw Exception('로그인이 필요합니다.');
      }
      if (e.code == 'resource-exhausted') {
        throw Exception('일일 분석 한도에 도달했습니다. 내일 다시 시도해주세요.');
      }
      throw Exception('분석 오류: ${e.message}');
    }
  }
}

/// compute() 아이솔레이트에서 실행될 이미지 처리 함수 (top-level)
/// UI 스레드를 블로킹하지 않음
String _processImageIsolate(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  final original = img.decodeImage(bytes);

  if (original == null) {
    throw Exception('이미지를 읽을 수 없습니다. 지원되지 않는 형식일 수 있습니다.');
  }

  // 최대 1024px로 리사이즈 (API 비용 절감 + 속도 개선)
  img.Image resized;
  if (original.width > 1024 || original.height > 1024) {
    if (original.width > original.height) {
      resized = img.copyResize(original, width: 1024);
    } else {
      resized = img.copyResize(original, height: 1024);
    }
  } else {
    resized = original;
  }

  // JPEG로 인코딩 (품질 85%)
  final jpegBytes = img.encodeJpg(resized, quality: 85);
  return base64Encode(jpegBytes);
}

/// 음식이 아닌 사진일 때 발생하는 예외
class FoodNotRecognizedException implements Exception {
  final String message;
  FoodNotRecognizedException(this.message);

  @override
  String toString() => message;
}
