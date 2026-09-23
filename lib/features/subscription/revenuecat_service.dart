import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages RevenueCat subscription state and in-app purchases for Stewardie.
class RevenueCatService extends ChangeNotifier {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// Default public test keys. Can be overridden with --dart-define=REVENUECAT_API_KEY=...
  static const String _defaultAndroidKey = 'test_FNaFLEDIUHKYuDjOZtSICpQHVvc';
  static const String _defaultIosKey = 'test_FNaFLEDIUHKYuDjOZtSICpQHVvc';

  static String get apiKey {
    const override = String.fromEnvironment('REVENUECAT_API_KEY');
    if (override.isNotEmpty) return override;
    const googleKey = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
    if (!kIsWeb && Platform.isAndroid && googleKey.isNotEmpty) return googleKey;
    const appleKey = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
    if (!kIsWeb && Platform.isIOS && appleKey.isNotEmpty) return appleKey;
    if (kIsWeb) return _defaultAndroidKey;
    return Platform.isAndroid ? _defaultAndroidKey : _defaultIosKey;
  }

  bool _initialized = false;
  bool _isPlus = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _currentUserId;
  Future<void> _queue = Future.value();
  String? error;
  int _epoch = 0;
  static const purchasesEnabled = bool.fromEnvironment(
    'ENABLE_TEST_PURCHASES',
    defaultValue: false,
  );

  bool get isPlus => _isPlus;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isInitialized => _initialized;

  /// Initializes RevenueCat with safe fallback for Web or environments without native billing.
  Future<void> init({String? userId}) {
    final epoch = ++_epoch;
    return _queue = _queue.then((_) => epoch == _epoch ? _bind(userId, epoch) : null);
  }

  Future<void> _bind(String? userId, int epoch) async {
    if (_currentUserId == userId && _initialized && error == null) return;
    _currentUserId = userId;
    _isPlus = false;
    _customerInfo = null;
    _offerings = null;
    error = null;
    notifyListeners();
    if (kIsWeb || userId == null) return;
    try {
      if (!_initialized) {
        await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.warn,
        );
        await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = userId,
        );
        Purchases.addCustomerInfoUpdateListener(_receiveInfo);
        _initialized = true;
      } else {
        await Purchases.logIn(userId);
      }
      final info = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      if (epoch != _epoch) return;
      _updateCustomerInfo(info);
      _offerings = offerings;
    } catch (_) {
      if (epoch != _epoch) return;
      error = 'Purchase information is unavailable. Try again when connected.';
    }
    notifyListeners();
  }

  void _receiveInfo(CustomerInfo _) async {
    final epoch = _epoch, expected = _currentUserId;
    if (expected == null) return;
    try {
      final info = await Purchases.getCustomerInfo();
      final actual = await Purchases.appUserID;
      if (epoch == _epoch && expected == actual) _updateCustomerInfo(info);
    } catch (_) { /* A listener failure does not grant or change access. */ }
  }

  Future<void> logIn(String uid) => init(userId: uid);
  Future<void> logOut() {
    _epoch++;
    _currentUserId = null;
    _isPlus = false;
    _customerInfo = null;
    _offerings = null;
    notifyListeners();
    return _queue = _queue.then((_) async {
      if (!kIsWeb && _initialized) {
        try {
          await Purchases.logOut();
        } catch (_) {
          /* Firebase sign-out still proceeds. */
        }
      }
    });
  }

  /// Purchases a real RevenueCat package if native store is connected.
  Future<bool> purchasePackage(Package package) async {
    if (!purchasesEnabled || kIsWeb || !_initialized || _currentUserId == null)
      return false;
    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _updateCustomerInfo(purchaseResult.customerInfo);
      return _isPlus;
    } catch (e) {
      debugPrint('[RevenueCat] purchasePackage error: $e');
      return false;
    }
  }

  /// Restores previous purchases.
  Future<bool> restorePurchases() async {
    if (kIsWeb || !_initialized || _currentUserId == null) return false;
    try {
      final info = await Purchases.restorePurchases();
      _updateCustomerInfo(info);
      return _isPlus;
    } catch (e) {
      debugPrint('[RevenueCat] restorePurchases error: $e');
      return false;
    }
  }

  void _updateCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    // One canonical entitlement; this UI status never grants Firestore access.
    final active = info.entitlements.active;
    _isPlus = active.containsKey('stewardie_plus');
    notifyListeners();
  }
}
