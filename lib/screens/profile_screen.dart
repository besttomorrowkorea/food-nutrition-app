import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/subscription_provider.dart';
import '../repositories/inbody_repository.dart';
import '../models/inbody_record.dart';
import 'inbody_input_screen.dart';
import 'goal_screen.dart';
import 'paywall_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  InBodyRecord? _latestInBody;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final inbody = await InBodyRepository().getLatest(uid);
    if (mounted) setState(() { _latestInBody = inbody; _isLoading = false; });
  }

  Future<bool> _requirePremium(String featureName) async {
    final sub = ref.read(subscriptionProvider);
    if (sub.isPremium) return true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(featureName: featureName),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 구독 상태 배너
                _buildSubscriptionBanner(sub),
                const SizedBox(height: 20),

                // 최신 인바디
                _buildSection(
                  '인바디 기록',
                  Icons.monitor_weight,
                  _latestInBody != null
                      ? '체중 ${_latestInBody!.weight}kg · '
                          '체지방 ${_latestInBody!.bodyFatPercentage}% · '
                          '골격근 ${_latestInBody!.skeletalMuscleMass}kg'
                      : '아직 기록이 없습니다',
                  onTap: () async {
                    if (!await _requirePremium('인바디 기록')) return;
                    if (!mounted) return;
                    final result = await Navigator.push<InBodyRecord>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InBodyInputScreen()),
                    );
                    if (result != null && mounted) {
                      setState(() => _latestInBody = result);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // 목표 & 로드맵
                _buildSection(
                  '목표 & AI 로드맵',
                  Icons.flag,
                  'AI가 맞춤 건강 로드맵을 생성합니다',
                  onTap: () async {
                    if (!await _requirePremium('목표 & 로드맵')) return;
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GoalScreen()),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // 계정 정보
                Text('계정',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    FirebaseAuth.instance.currentUser?.isAnonymous == true
                        ? '게스트 (비로그인)'
                        : FirebaseAuth.instance.currentUser?.email ?? '사용자',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSubscriptionBanner(SubscriptionNotifier sub) {
    final isPremium = sub.isPremium;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [Colors.amber.shade600, Colors.orange.shade600]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.workspace_premium : Icons.lock_open,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'NutriSync Pro' : '무료 버전',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                Text(
                  isPremium
                      ? '모든 프리미엄 기능을 사용 중입니다'
                      : '업그레이드하여 기록 저장, 인바디, 로드맵을 이용하세요',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isPremium)
            ElevatedButton(
              onPressed: () => _requirePremium('Pro 업그레이드'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
              ),
              child: const Text('업그레이드'),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade600),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
