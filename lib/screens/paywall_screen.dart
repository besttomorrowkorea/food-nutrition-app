import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final packages = await SubscriptionService.getOfferings();
    if (mounted) {
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _isPurchasing = true);

    final success = await SubscriptionService.purchase(package);
    if (success && mounted) {
      ref.read(subscriptionProvider).setTier(SubscriptionTier.premium);
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _restore() async {
    final success = await ref.read(subscriptionProvider).restore();
    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매가 복원되었습니다!')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복원할 구매 내역이 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NutriSync Pro')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 헤더
                  Icon(Icons.workspace_premium,
                      size: 64, color: Colors.amber.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'NutriSync Pro로 업그레이드',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (widget.featureName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${widget.featureName}" 기능은 Pro에서 사용할 수 있습니다',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Pro 기능 목록
                  _buildFeatureItem(Icons.save_alt, '영양 기록 무제한 저장'),
                  _buildFeatureItem(Icons.calendar_month, '날짜별 히스토리 & 차트'),
                  _buildFeatureItem(Icons.monitor_weight, '인바디 기록 관리'),
                  _buildFeatureItem(Icons.route, 'AI 목표 로드맵'),
                  _buildFeatureItem(Icons.fitness_center, '개인화 운동 루틴'),
                  _buildFeatureItem(Icons.chat, 'AI 코칭 대화 기록 저장'),
                  const SizedBox(height: 32),

                  // 구독 옵션
                  if (_packages.isEmpty)
                    _buildFallbackPricing()
                  else
                    ..._packages.map(_buildPackageCard),

                  const SizedBox(height: 16),

                  // 구매 복원
                  TextButton(
                    onPressed: _restore,
                    child: const Text('이전 구매 복원'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '구독은 언제든 취소할 수 있습니다.',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade600, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    final product = package.storeProduct;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: _isPurchasing ? null : () => _purchase(package),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isPurchasing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                '${product.title} — ${product.priceString}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildFallbackPricing() {
    return Column(
      children: [
        _buildPriceOption('월간 구독', '₩9,900/월', true),
        const SizedBox(height: 12),
        _buildPriceOption('연간 구독', '₩79,000/년 (33% 할인)', false),
      ],
    );
  }

  Widget _buildPriceOption(String title, String price, bool isPrimary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPrimary ? Colors.green.shade600 : Colors.grey.shade300,
          width: isPrimary ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isPrimary ? Colors.green.shade50 : null,
      ),
      child: Column(
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(price,
              style: TextStyle(
                  color: Colors.green.shade700, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
