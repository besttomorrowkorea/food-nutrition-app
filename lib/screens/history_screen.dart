import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/nutrition_record.dart';
import '../providers/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<NutritionRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecords(_selectedDay);
  }

  Future<void> _loadRecords(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final records = await repo.getRecordsByDate(uid, date);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영양 기록')),
      body: Column(
        children: [
          // 캘린더
          TableCalendar(
            firstDay: DateTime(2024),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _loadRecords(selected);
            },
            calendarFormat: CalendarFormat.month,
            locale: 'ko_KR',
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.green.shade200,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),

          // 선택된 날짜의 요약
          _buildDaySummary(),

          // 기록 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : _buildRecordList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySummary() {
    final totalCal = _records.fold<int>(0, (sum, r) => sum + r.calories);
    final totalProtein = _records.fold<double>(0, (sum, r) => sum + r.protein);
    final totalCarbs = _records.fold<double>(0, (sum, r) => sum + r.carbs);
    final totalFat = _records.fold<double>(0, (sum, r) => sum + r.fat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.green.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('칼로리', '$totalCal', 'kcal', Colors.orange),
          _buildSummaryItem(
              '탄수화물', totalCarbs.toStringAsFixed(0), 'g', Colors.blue),
          _buildSummaryItem(
              '단백질', totalProtein.toStringAsFixed(0), 'g', Colors.red),
          _buildSummaryItem(
              '지방', totalFat.toStringAsFixed(0), 'g', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: unit,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final dateStr = DateFormat('M월 d일').format(_selectedDay);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('$dateStr의 기록이 없습니다',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = _records[index];
        return Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _mealColor(r.mealType),
              child: Text(_mealEmoji(r.mealType),
                  style: const TextStyle(fontSize: 20)),
            ),
            title: Text(r.foodName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '탄 ${r.carbs.toStringAsFixed(0)}g · 단 ${r.protein.toStringAsFixed(0)}g · 지 ${r.fat.toStringAsFixed(0)}g',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Text(
              '${r.calories}\nkcal',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  String _mealEmoji(String type) {
    switch (type) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      default:
        return '🍪';
    }
  }

  Color _mealColor(String type) {
    switch (type) {
      case 'breakfast':
        return Colors.amber.shade100;
      case 'lunch':
        return Colors.orange.shade100;
      case 'dinner':
        return Colors.indigo.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
