import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nutrition_result.dart';
import '../models/nutrition_record.dart';
import '../providers/providers.dart';
import '../providers/subscription_provider.dart';
import 'paywall_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final NutritionResult result;
  final File imageFile;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imageFile,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  NutritionResult get result => widget.result;
  File get imageFile => widget.imageFile;
  String _selectedMealType = 'lunch';
  bool _isSaving = false;
  bool _saved = false;

  Future<void> _saveRecord() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 7일 무료 기록 체크 — 프리미엄이 아니면 페이월
    final sub = ref.read(subscriptionProvider);
    if (!sub.isPremium) {
      // 무료 사용자: 최근 7일간 기록 수 확인
      final repo = ref.read(nutritionRepositoryProvider);
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recent = await repo.getRecordsByDateRange(uid, weekAgo, DateTime.now());

      if (recent.length >= 21) {
        // 7일간 21건(하루 3끼) 이상이면 페이월
        if (!mounted) return;
        final upgraded = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(featureName: '영양 기록 저장'),
          ),
        );
        if (upgraded != true) return;
      }
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final record = NutritionRecord(
      id: '${uid}_${now.millisecondsSinceEpoch}',
      userId: uid,
      date: now,
      mealType: _selectedMealType,
      foodName: result.foodName,
      calories: result.calories,
      protein: result.nutrients.protein,
      carbs: result.nutrients.carbohydrates,
      fat: result.nutrients.fat,
      fiber: result.nutrients.fiber,
      sugar: result.nutrients.sugar,
      sodium: result.nutrients.sodium,
      createdAt: now,
    );

    try {
      await ref.read(nutritionRepositoryProvider).saveRecord(record);
      if (mounted) {
        setState(() { _saved = true; _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 저장되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 결과'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 음식 이미지
            _buildImageCard(),
            const SizedBox(height: 16),

            // 음식 이름 및 기본 정보
            _buildFoodInfoCard(context),
            const SizedBox(height: 16),

            // 칼로리 하이라이트
            _buildCalorieCard(context),
            const SizedBox(height: 16),

            // 주요 영양소 (탄단지)
            _buildMacroNutrients(context),
            const SizedBox(height: 16),

            // 상세 영양소
            _buildDetailedNutrients(context),
            const SizedBox(height: 16),

            // 설명
            _buildDescriptionCard(context),
            const SizedBox(height: 16),

            // 기록 저장 영역
            _buildSaveSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveSection(BuildContext context) {
    if (_saved) {
      return Card(
        elevation: 0,
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              Text('기록에 저장되었습니다!',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 식사를 기록할까요?',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'breakfast', label: Text('아침')),
                ButtonSegment(value: 'lunch', label: Text('점심')),
                ButtonSegment(value: 'dinner', label: Text('저녁')),
                ButtonSegment(value: 'snack', label: Text('간식')),
              ],
              selected: {_selectedMealType},
              onSelectionChanged: (s) =>
                  setState(() => _selectedMealType = s.first),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecord,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt),
                label: const Text('기록 저장'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.file(
          imageFile,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFoodInfoCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.foodName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              result.foodNameEn,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.scale,
                  result.servingSize,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.verified,
                  '신뢰도: ${result.confidenceKr}',
                  _confidenceColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _confidenceColor {
    switch (result.confidence) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.local_fire_department,
                size: 40, color: Colors.orange.shade600),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '칼로리',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                ),
                Text(
                  '${result.calories} kcal',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroNutrients(BuildContext context) {
    final n = result.nutrients;
    final total = n.carbohydrates + n.protein + n.fat;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '주요 영양소',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // 비율 바
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Flexible(
                        flex: (n.carbohydrates / total * 100).round(),
                        child: Container(color: Colors.blue.shade400),
                      ),
                      Flexible(
                        flex: (n.protein / total * 100).round(),
                        child: Container(color: Colors.red.shade400),
                      ),
                      Flexible(
                        flex: (n.fat / total * 100).round(),
                        child: Container(color: Colors.amber.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMacroItem(
                    '탄수화물',
                    '${n.carbohydrates.toStringAsFixed(1)}g',
                    Colors.blue.shade400,
                  ),
                ),
                Expanded(
                  child: _buildMacroItem(
                    '단백질',
                    '${n.protein.toStringAsFixed(1)}g',
                    Colors.red.shade400,
                  ),
                ),
                Expanded(
                  child: _buildMacroItem(
                    '지방',
                    '${n.fat.toStringAsFixed(1)}g',
                    Colors.amber.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedNutrients(BuildContext context) {
    final n = result.nutrients;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상세 영양소',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildNutrientRow('포화지방', '${n.saturatedFat.toStringAsFixed(1)}g'),
            _buildNutrientRow('식이섬유', '${n.fiber.toStringAsFixed(1)}g'),
            _buildNutrientRow('당류', '${n.sugar.toStringAsFixed(1)}g'),
            _buildNutrientRow('나트륨', '${n.sodium.toStringAsFixed(0)}mg'),
            _buildNutrientRow(
              '콜레스테롤',
              '${n.cholesterol.toStringAsFixed(0)}mg',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[700])),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  '영양 정보',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: Colors.blue.shade900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
