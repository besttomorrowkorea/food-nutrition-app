import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../models/health_goal.dart';
import '../repositories/goal_repository.dart';

final goalRepoProvider = Provider((ref) => GoalRepository());

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  HealthGoal? _activeGoal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final goal = await ref.read(goalRepoProvider).getActive(uid);
    if (mounted) setState(() { _activeGoal = goal; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('목표 & 로드맵')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('목표 & 로드맵')),
      body: _activeGoal == null ? _buildNoGoal() : _buildGoalView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGoalDialog,
        icon: Icon(_activeGoal == null ? Icons.add : Icons.edit),
        label: Text(_activeGoal == null ? '목표 설정' : '목표 수정'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildNoGoal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('아직 목표가 없습니다',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('목표를 설정하면 AI가 맞춤 로드맵을 생성합니다',
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalView() {
    final g = _activeGoal!;
    final daysLeft = g.targetDate.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 목표 요약 카드
          Card(
            elevation: 0,
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(g.typeKr,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (g.targetWeight != null)
                    _buildGoalDetail('목표 체중', '${g.targetWeight}kg'),
                  if (g.targetBodyFat != null)
                    _buildGoalDetail('목표 체지방', '${g.targetBodyFat}%'),
                  _buildGoalDetail(
                    '목표일',
                    '${DateFormat('yyyy.MM.dd').format(g.targetDate)} (D-$daysLeft)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // AI 로드맵
          if (g.roadmapText.isNotEmpty) ...[
            Text('AI 로드맵',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${DateFormat('M/d').format(g.roadmapCreatedAt)} 기준 생성',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  g.roadmapText,
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGoalDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showGoalDialog() async {
    final typeCtrl = ValueNotifier<String>('diet');
    final weightCtrl = TextEditingController(
        text: _activeGoal?.targetWeight?.toString() ?? '');
    final fatCtrl = TextEditingController(
        text: _activeGoal?.targetBodyFat?.toString() ?? '');
    var targetDate =
        _activeGoal?.targetDate ?? DateTime.now().add(const Duration(days: 90));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('목표 설정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 목표 유형
                ValueListenableBuilder<String>(
                  valueListenable: typeCtrl,
                  builder: (_, val, __) => SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'diet', label: Text('다이어트')),
                      ButtonSegment(value: 'muscle', label: Text('근육 증가')),
                      ButtonSegment(value: 'fitness', label: Text('체력')),
                    ],
                    selected: {val},
                    onSelectionChanged: (s) => typeCtrl.value = s.first,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(
                    labelText: '목표 체중 (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatCtrl,
                  decoration: const InputDecoration(
                    labelText: '목표 체지방률 (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('목표 날짜'),
                  subtitle: Text(DateFormat('yyyy.MM.dd').format(targetDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      targetDate = picked;
                      setDialogState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장 & 로드맵 생성')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 저장 + AI 로드맵 생성
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    String roadmapText = '';

    // Claude 로드맵 생성 요청
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'chatWithAI',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'message':
            '목표: ${typeCtrl.value == "diet" ? "다이어트" : typeCtrl.value == "muscle" ? "근육 증가" : "체력 향상"}\n'
                '목표 체중: ${weightCtrl.text.isNotEmpty ? "${weightCtrl.text}kg" : "미지정"}\n'
                '목표 체지방: ${fatCtrl.text.isNotEmpty ? "${fatCtrl.text}%" : "미지정"}\n'
                '목표 날짜: ${DateFormat("yyyy.MM.dd").format(targetDate)}\n\n'
                '위 목표에 맞는 주간 단위 실행 로드맵을 만들어줘. '
                '운동, 식단, 생활습관을 포함해서 구체적으로 작성해줘.',
        'context': {},
      });

      if (result.data['success'] == true) {
        roadmapText = result.data['reply'] as String;
      }
    } catch (_) {
      roadmapText = '로드맵 생성에 실패했습니다. 나중에 다시 시도해주세요.';
    }

    final goal = HealthGoal(
      id: '${uid}_goal_${now.millisecondsSinceEpoch}',
      userId: uid,
      type: typeCtrl.value,
      targetWeight: weightCtrl.text.isNotEmpty
          ? double.tryParse(weightCtrl.text)
          : null,
      targetBodyFat:
          fatCtrl.text.isNotEmpty ? double.tryParse(fatCtrl.text) : null,
      targetDate: targetDate,
      roadmapData: {},
      roadmapText: roadmapText,
      roadmapCreatedAt: now,
      createdAt: now,
    );

    await ref.read(goalRepoProvider).save(goal);
    if (mounted) setState(() { _activeGoal = goal; _isLoading = false; });

    weightCtrl.dispose();
    fatCtrl.dispose();
    typeCtrl.dispose();
  }
}
