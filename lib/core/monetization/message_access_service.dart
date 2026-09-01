import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MessageAccessResult { granted, cancelled, unavailable, failed }

class MessageAccessService {
  MessageAccessService(this._preferences) {
    isUnlockedListenable.value = _preferences.getBool(_unlockedKey) ?? false;
  }

  static const productId = String.fromEnvironment(
    'MESSAGE_SUBSCRIPTION_PRODUCT_ID',
    defaultValue: 'whyapp_unlimited_messages_monthly',
  );
  static const _useRealPlayBilling = bool.fromEnvironment(
    'USE_REAL_PLAY_BILLING',
    defaultValue: false,
  );

  static const _androidTestRewardedAdId =
      'ca-app-pub-3940256099942544/5224354917';
  static const _unlockedKey = 'message_sending_unlocked';

  final SharedPreferences _preferences;
  final InAppPurchase _store = InAppPurchase.instance;
  final ValueNotifier<bool> isUnlockedListenable = ValueNotifier(false);
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<MessageAccessResult>? _purchaseCompleter;

  bool get isUnlocked => isUnlockedListenable.value;
  bool get isUsingFakeBilling => !_useRealPlayBilling;

  void initialize() {
    unawaited(MobileAds.instance.initialize());
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (_) => _completePurchase(MessageAccessResult.failed),
    );
    unawaited(_restorePurchases());
  }

  Future<void> _restorePurchases() async {
    // A subscription must not be treated as a permanent local unlock. Active
    // entitlement is granted again from the Play Store purchase restoration.
    await _setUnlocked(false);
    if (isUsingFakeBilling) return;
    if (!await _store.isAvailable()) return;
    await _store.restorePurchases();
  }

  Future<MessageAccessResult> showRewardedAd() async {
    if (!Platform.isAndroid) return MessageAccessResult.unavailable;

    final result = Completer<MessageAccessResult>();
    var earnedReward = false;

    RewardedAd.load(
      adUnitId: _androidTestRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!result.isCompleted) {
                result.complete(
                  earnedReward
                      ? MessageAccessResult.granted
                      : MessageAccessResult.cancelled,
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!result.isCompleted) {
                result.complete(MessageAccessResult.failed);
              }
            },
          );
          ad.show(
            onUserEarnedReward: (_, _) {
              earnedReward = true;
              if (!result.isCompleted) {
                result.complete(MessageAccessResult.granted);
              }
            },
          );
        },
        onAdFailedToLoad: (_) {
          if (!result.isCompleted) {
            result.complete(MessageAccessResult.unavailable);
          }
        },
      ),
    );

    return result.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => MessageAccessResult.failed,
    );
  }

  Future<MessageAccessResult> subscribeMonthly() async {
    if (isUsingFakeBilling) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _setUnlocked(true);
      return MessageAccessResult.granted;
    }

    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      return _purchaseCompleter!.future;
    }
    if (!await _store.isAvailable()) return MessageAccessResult.unavailable;

    final response = await _store.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      return MessageAccessResult.unavailable;
    }

    _purchaseCompleter = Completer<MessageAccessResult>();
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
      ),
    );
    if (!started) {
      _completePurchase(MessageAccessResult.failed);
    }

    return _purchaseCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => MessageAccessResult.failed,
    );
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Before production, verify purchase.verificationData on the backend.
        await _setUnlocked(true);
        _completePurchase(MessageAccessResult.granted);
      } else if (purchase.status == PurchaseStatus.error) {
        _completePurchase(MessageAccessResult.failed);
      } else if (purchase.status == PurchaseStatus.canceled) {
        _completePurchase(MessageAccessResult.cancelled);
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  void _completePurchase(MessageAccessResult result) {
    final completer = _purchaseCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(result);
  }

  Future<void> _setUnlocked(bool value) async {
    await _preferences.setBool(_unlockedKey, value);
    isUnlockedListenable.value = value;
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    isUnlockedListenable.dispose();
  }
}
