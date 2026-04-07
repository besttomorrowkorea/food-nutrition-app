import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

class SubscriptionNotifier extends ChangeNotifier {
  SubscriptionTier _tier = SubscriptionTier.free;
  bool _isLoading = false;

  SubscriptionTier get tier => _tier;
  bool get isPremium => _tier == SubscriptionTier.premium;
  bool get isLoading => _isLoading;

  Future<void> checkStatus() async {
    _isLoading = true;
    notifyListeners();

    _tier = await SubscriptionService.checkSubscription();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> restore() async {
    _isLoading = true;
    notifyListeners();

    final success = await SubscriptionService.restore();
    if (success) _tier = SubscriptionTier.premium;

    _isLoading = false;
    notifyListeners();
    return success;
  }

  void setTier(SubscriptionTier tier) {
    _tier = tier;
    notifyListeners();
  }
}

final subscriptionProvider =
    ChangeNotifierProvider<SubscriptionNotifier>((ref) {
  final notifier = SubscriptionNotifier();
  notifier.checkStatus();
  return notifier;
});
