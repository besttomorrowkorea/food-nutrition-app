import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inbody_record.dart';
import '../repositories/inbody_repository.dart';

final inBodyRepoProvider = Provider((ref) => InBodyRepository());

class InBodyInputScreen extends ConsumerStatefulWidget {
  const InBodyInputScreen({super.key});

  @override
  ConsumerState<InBodyInputScreen> createState() => _InBodyInputScreenState();
}

class _InBodyInputScreenState extends ConsumerState<InBodyInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _muscleCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  final _bmrCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _muscleCtrl.dispose();
    _bmiCtrl.dispose();
    _bmrCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final record = InBodyRecord(
      id: '${uid}_${now.millisecondsSinceEpoch}',
      userId: uid,
      date: _selectedDate,
      weight: double.parse(_weightCtrl.text),
      bodyFatPercentage: double.parse(_bodyFatCtrl.text),
      skeletalMuscleMass: double.parse(_muscleCtrl.text),
      bmi: _bmiCtrl.text.isNotEmpty ? double.parse(_bmiCtrl.text) : 0,
      basalMetabolicRate:
          _bmrCtrl.text.isNotEmpty ? double.parse(_bmrCtrl.text) : 0,
      isManualEntry: true,
      createdAt: now,
    );

    try {
      await ref.read(inBodyRepoProvider).save(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인바디 기록이 저장되었습니다!')),
        );
        Navigator.of(context).pop(record);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('인바디 기록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 날짜 선택
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('측정일'),
              subtitle: Text(
                '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
              ),
              trailing: const Icon(Icons.edit),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 24),

            // 필수 항목
            Text('필수 항목',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildNumberField(_weightCtrl, '체중', 'kg', required: true),
            const SizedBox(height: 12),
            _buildNumberField(_bodyFatCtrl, '체지방률', '%', required: true),
            const SizedBox(height: 12),
            _buildNumberField(_muscleCtrl, '골격근량', 'kg', required: true),
            const SizedBox(height: 24),

            // 선택 항목
            Text('선택 항목',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildNumberField(_bmiCtrl, 'BMI', ''),
            const SizedBox(height: 12),
            _buildNumberField(_bmrCtrl, '기초대사량', 'kcal'),
            const SizedBox(height: 32),

            // 저장 버튼
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('저장',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController ctrl,
    String label,
    String suffix, {
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: required
          ? (v) {
              if (v == null || v.isEmpty) return '$label을(를) 입력해주세요';
              if (double.tryParse(v) == null) return '올바른 숫자를 입력해주세요';
              return null;
            }
          : null,
    );
  }
}
