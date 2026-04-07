import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionTier { free, premium }

class SubscriptionService {
  static const _entitlementId = 'premium';

  /// RevenueCat 초기화 (main.dart에서 Firebase Auth 이후 호출)
  static Future<void> initialize({
    required String apiKey,
    String? userId,
  }) async {
    final config = PurchasesConfiguration(apiKey);
    if (userId != null) {
      config.appUserID = userId;
    }
    await Purchases.configure(config);
  }

  /// Firebase Auth 로그인 시 RevenueCat ID 동기화
  static Future<void> syncUserId(String firebaseUid) async {
    await Purchases.logIn(firebaseUid);
  }

  /// 현재 구독 상태 확인
  static Future<SubscriptionTier> checkSubscription() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final isPremium = info.entitlements.all[_entitlementId]?.isActive ?? false;
      return isPremium ? SubscriptionTier.premium : SubscriptionTier.free;
    } catch (_) {
      return SubscriptionTier.free;
    }
  }

  /// 구매 가능한 패키지 목록
  static Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  /// 패키지 구매
  static Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 구매 복원
  static Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }
}
