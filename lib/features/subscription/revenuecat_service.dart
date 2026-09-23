import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages RevenueCat subscription state and in-app purchases for Stewardie.
class RevenueCatService extends ChangeNotifier {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// Default public test keys. Can be overridden with --dart-define=REVENUECAT_API_KEY=...
  static const String _defaultAndroidKey = 'goog_sandbox_stewardie';
  static const String _defaultIosKey = 'appl_sandbox_stewardie';

  static String get apiKey {
    const override = String.fromEnvironment('REVENUECAT_API_KEY');
    if (override.isNotEmpty) return override;
    const googleKey = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
    if (!kIsWeb && Platform.isAndroid && googleKey.isNotEmpty) return googleKey;
    const appleKey = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
    if (!kIsWeb && Platform.isIOS && appleKey.isNotEmpty) return appleKey;
    if (kIsWeb) return 'web_sandbox_stewardie';
    return Platform.isAndroid ? _defaultAndroidKey : _defaultIosKey;
  }

  bool _initialized = false;
  bool _isPlus = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _currentUserId;

  bool get isPlus => _isPlus;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isInitialized => _initialized;

  /// Initializes RevenueCat with safe fallback for Web or environments without native billing.
  Future<void> init({String? userId}) async {
    if (_initialized && _currentUserId == userId) return;
    _currentUserId = userId;

    if (kIsWeb) {
      debugPrint('[RevenueCat] Web detected: running in Sandbox Demo mode.');
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(apiKey);
      if (userId != null && userId.isNotEmpty) {
        config.appUserID = userId;
      }
      await Purchases.configure(config);

      Purchases.addCustomerInfoUpdateListener((info) {
        _updateCustomerInfo(info);
      });

      final info = await Purchases.getCustomerInfo();
      _updateCustomerInfo(info);

      _offerings = await Purchases.getOfferings();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[RevenueCat] Initialization warning (sandbox fallback active): $e');
      _initialized = true;
      notifyListeners();
    }
  }

  /// Synchronizes logged-in Firebase user UID with RevenueCat.
  Future<void> logIn(String uid) async {
    _currentUserId = uid;
    if (kIsWeb) return;
    try {
      final result = await Purchases.logIn(uid);
      _updateCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('[RevenueCat] logIn error: $e');
    }
  }

  /// Logs out the user from RevenueCat when signing out of Firebase.
  Future<void> logOut() async {
    _currentUserId = null;
    _isPlus = false;
    _customerInfo = null;
    notifyListeners();
    if (kIsWeb) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('[RevenueCat] logOut error: $e');
    }
  }

  /// Purchases a real RevenueCat package if native store is connected.
  Future<bool> purchasePackage(Package package) async {
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
    if (kIsWeb) return _isPlus;
    try {
      final info = await Purchases.restorePurchases();
      _updateCustomerInfo(info);
      return _isPlus;
    } catch (e) {
      debugPrint('[RevenueCat] restorePurchases error: $e');
      return false;
    }
  }

  /// Sandbox / Demo mode toggle for Shipathon judges or test runs without a live store account.
  void setPlusSimulated(bool active) {
    _isPlus = active;
    notifyListeners();
  }

  void _updateCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    // Checks for entitlement 'plus' or 'personal_plus'
    final active = info.entitlements.active;
    _isPlus = active.containsKey('plus') ||
        active.containsKey('personal_plus') ||
        active.containsKey('Plus');
    notifyListeners();
  }
}
