import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import '../models/nutrition_result.dart';

class NutritionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 이미지 파일을 분석하여 영양소 정보를 반환
  Future<NutritionResult> analyzeFood(File imageFile) async {
    // 이미지 압축 및 Base64 인코딩
    final base64Image = await _processImage(imageFile);

    // Firebase Cloud Function 호출
    final callable = _functions.httpsCallable(
      'analyzeFood',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
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
      throw Exception('분석 오류: ${e.message}');
    }
  }

  /// 이미지를 적절한 크기로 리사이즈하고 Base64로 인코딩
  Future<String> _processImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);

    if (original == null) {
      throw Exception('이미지를 읽을 수 없습니다.');
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
}

/// 음식이 아닌 사진일 때 발생하는 예외
class FoodNotRecognizedException implements Exception {
  final String message;
  FoodNotRecognizedException(this.message);

  @override
  String toString() => message;
}
