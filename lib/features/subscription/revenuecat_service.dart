import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';

enum RevenueCatEnvironment {
  off,
  test,
  production,
}

enum PurchaseStatus {
  success,
  cancelled,
  pending,
  missingPackage,
  userMismatch,
  syncPending,
  syncFailed,
  notAllowed,
  error,
}

class PurchaseExecutionResult {
  const PurchaseExecutionResult(this.status, {this.message, this.customerInfo});
  final PurchaseStatus status;
  final String? message;
  final CustomerInfo? customerInfo;
  bool get isSuccess => status == PurchaseStatus.success;
}

enum RestoreStatus {
  success,
  noPurchases,
  syncPending,
  syncFailed,
  error,
}

class RestoreExecutionResult {
  const RestoreExecutionResult(this.status, {this.message, this.customerInfo});
  final RestoreStatus status;
  final String? message;
  final CustomerInfo? customerInfo;
  bool get isSuccess => status == RestoreStatus.success;
}

/// Manages RevenueCat subscription state, store environments, and server reconciliation.
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

  static const String reconciliationEndpoint = String.fromEnvironment(
    'SUBSCRIPTION_RECONCILIATION_URL',
    defaultValue: 'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/reconcile-subscription',
  );

  static RevenueCatEnvironment get environment {
    // Release builds must never silently use a test key
    if (kReleaseMode && apiKey.startsWith('test_')) {
      return RevenueCatEnvironment.off;
    }
    const envOverride = String.fromEnvironment('REVENUECAT_ENVIRONMENT');
    if (envOverride == 'production') {
      const allowProd = bool.fromEnvironment('ENABLE_PRODUCTION_PURCHASES', defaultValue: false);
      return allowProd && !apiKey.startsWith('test_')
          ? RevenueCatEnvironment.production
          : RevenueCatEnvironment.off;
    }
    if (envOverride == 'off') {
      return RevenueCatEnvironment.off;
    }
    const testPurchasesEnabled = bool.fromEnvironment(
      'ENABLE_TEST_PURCHASES',
      defaultValue: false,
    );
    if (!testPurchasesEnabled && envOverride != 'test') {
      return RevenueCatEnvironment.off;
    }
    return apiKey.startsWith('test_') ? RevenueCatEnvironment.test : RevenueCatEnvironment.off;
  }

  static bool get purchasesEnabled => environment != RevenueCatEnvironment.off;

  bool _initialized = false;
  bool _isPlus = false;
  bool _isFounder = false;
  DateTime? _subscriptionExpiry;
  String? _subscriptionStore;
  String? _subscriptionProductId;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _currentUserId;
  Future<void> _queue = Future.value();
  String? error;
  int _epoch = 0;

  bool get isPlus => _isPlus;
  bool get isFounder => _isFounder;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  String? get subscriptionStore => _subscriptionStore;
  String? get subscriptionProductId => _subscriptionProductId;
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
    _isFounder = false;
    _subscriptionExpiry = null;
    _subscriptionStore = null;
    _subscriptionProductId = null;
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
      // Reconcile in the background without blocking initialization
      reconcileWithBackend();
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
      if (epoch == _epoch && expected == actual) {
        _updateCustomerInfo(info);
        reconcileWithBackend();
      }
    } catch (_) { /* A listener failure does not grant or change access. */ }
  }

  Future<void> logIn(String uid) => init(userId: uid);
  Future<void> logOut() {
    _epoch++;
    _currentUserId = null;
    _isPlus = false;
    _isFounder = false;
    _subscriptionExpiry = null;
    _subscriptionStore = null;
    _subscriptionProductId = null;
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

  /// Reconciles subscription status with server endpoint.
  Future<bool> reconcileWithBackend({String? idToken}) async {
    final epoch = _epoch;
    final expectedUid = _currentUserId;
    if (expectedUid == null) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != expectedUid) return false;
      final token = idToken ?? await user.getIdToken();
      if (epoch != _epoch || expectedUid != _currentUserId) return false;
      if (token == null) return false;

      final response = await http
          .post(
            Uri.parse(reconciliationEndpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (epoch != _epoch || expectedUid != _currentUserId) return false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (epoch != _epoch || expectedUid != _currentUserId) return false;
          _isFounder = data['isFounder'] == true;
          _isPlus = data['isPlus'] == true;
          final sub = data['subscription'] as Map<String, dynamic>?;
          if (sub != null) {
            final exp = sub['expiresAt'] as String?;
            _subscriptionExpiry = exp != null ? DateTime.tryParse(exp) : null;
            _subscriptionStore = sub['store'] as String?;
            _subscriptionProductId = sub['productId'] as String?;
          }
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[RevenueCat] Backend reconciliation error: $e');
      return false;
    }
  }

  /// Purchases a package with explicit status reporting and backend reconciliation.
  Future<PurchaseExecutionResult> purchasePackage(Package package) {
    if (!purchasesEnabled) {
      return Future.value(const PurchaseExecutionResult(
        PurchaseStatus.notAllowed,
        message: 'Purchases are currently disabled.',
      ));
    }
    if (kIsWeb || !_initialized || _currentUserId == null) {
      return Future.value(const PurchaseExecutionResult(
        PurchaseStatus.error,
        message: 'Purchase service is not available. Try again later.',
      ));
    }

    final epoch = _epoch;
    final expectedUid = _currentUserId;
    final completer = Completer<PurchaseExecutionResult>();

    _queue = _queue.then((_) async {
      if (epoch != _epoch || expectedUid != _currentUserId) {
        completer.complete(const PurchaseExecutionResult(
          PurchaseStatus.userMismatch,
          message: 'Account changed before purchase started.',
        ));
        return;
      }

      try {
        final purchaseResult = await Purchases.purchase(
          PurchaseParams.package(package),
        );

        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.userMismatch,
            message: 'Account changed during purchase.',
          ));
          return;
        }

        _updateCustomerInfo(purchaseResult.customerInfo);

        // Reconcile with trusted backend endpoint before confirming activation
        final reconciled = await reconcileWithBackend();

        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.userMismatch,
            message: 'Account changed during purchase reconciliation.',
          ));
          return;
        }

        if (reconciled && _isPlus) {
          completer.complete(PurchaseExecutionResult(
            PurchaseStatus.success,
            customerInfo: purchaseResult.customerInfo,
          ));
        } else {
          completer.complete(PurchaseExecutionResult(
            PurchaseStatus.syncPending,
            message: 'Purchase verified. Account benefits update after secure synchronization.',
            customerInfo: purchaseResult.customerInfo,
          ));
        }
      } on PlatformException catch (e) {
        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.userMismatch,
            message: 'Account changed during purchase.',
          ));
          return;
        }
        final code = PurchasesErrorHelper.getErrorCode(e);
        if (code == PurchasesErrorCode.purchaseCancelledError) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.cancelled,
            message: 'Purchase was cancelled.',
          ));
          return;
        }
        if (code == PurchasesErrorCode.paymentPendingError) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.pending,
            message: 'Payment is pending approval from the store.',
          ));
          return;
        }
        debugPrint('[RevenueCat] purchasePackage PlatformException: $e (code: $code)');
        completer.complete(PurchaseExecutionResult(
          PurchaseStatus.error,
          message: 'Purchase could not be completed ($code).',
        ));
      } catch (e) {
        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.userMismatch,
            message: 'Account changed during purchase.',
          ));
          return;
        }
        debugPrint('[RevenueCat] purchasePackage error: $e');
        final msg = e.toString();
        if (msg.contains('purchaseCancelledError') || msg.contains('cancelled') || msg.contains('Canceled')) {
          completer.complete(const PurchaseExecutionResult(
            PurchaseStatus.cancelled,
            message: 'Purchase was cancelled.',
          ));
          return;
        }
        completer.complete(const PurchaseExecutionResult(
          PurchaseStatus.error,
          message: 'Purchase could not be completed. Try again.',
        ));
      }
    });

    return completer.future;
  }

  /// Restores previous purchases with distinct outcome states.
  Future<RestoreExecutionResult> restorePurchases() {
    if (kIsWeb || !_initialized || _currentUserId == null) {
      return Future.value(const RestoreExecutionResult(
        RestoreStatus.error,
        message: 'Restore service is unavailable.',
      ));
    }

    final epoch = _epoch;
    final expectedUid = _currentUserId;
    final completer = Completer<RestoreExecutionResult>();

    _queue = _queue.then((_) async {
      if (epoch != _epoch || expectedUid != _currentUserId) {
        completer.complete(const RestoreExecutionResult(
          RestoreStatus.error,
          message: 'Account changed before restore started.',
        ));
        return;
      }

      try {
        final info = await Purchases.restorePurchases();

        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const RestoreExecutionResult(
            RestoreStatus.error,
            message: 'Account changed during restore.',
          ));
          return;
        }

        _updateCustomerInfo(info);
        final hasPlus = info.entitlements.active.containsKey('stewardie_plus');

        if (!hasPlus) {
          completer.complete(RestoreExecutionResult(
            RestoreStatus.noPurchases,
            customerInfo: info,
            message: 'No active purchases found for this account.',
          ));
          return;
        }

        final reconciled = await reconcileWithBackend();

        if (epoch != _epoch || expectedUid != _currentUserId) {
          completer.complete(const RestoreExecutionResult(
            RestoreStatus.error,
            message: 'Account changed during restore synchronization.',
          ));
          return;
        }

        if (reconciled && _isPlus) {
          completer.complete(RestoreExecutionResult(
            RestoreStatus.success,
            customerInfo: info,
          ));
        } else {
          completer.complete(RestoreExecutionResult(
            RestoreStatus.syncPending,
            customerInfo: info,
            message: 'Purchases found. Syncing with your account...',
          ));
        }
      } catch (e) {
        debugPrint('[RevenueCat] restorePurchases error: $e');
        completer.complete(const RestoreExecutionResult(
          RestoreStatus.error,
          message: 'Could not restore purchases. Check your connection.',
        ));
      }
    });

    return completer.future;
  }

  void _updateCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    final active = info.entitlements.active;
    final entitlement = active['stewardie_plus'];
    _isPlus = entitlement != null;
    if (entitlement != null) {
      _subscriptionStore = entitlement.store.name;
      _subscriptionProductId = entitlement.productIdentifier;
      final exp = entitlement.expirationDate;
      _subscriptionExpiry = exp != null ? DateTime.tryParse(exp) : null;
    }
    notifyListeners();
  }
}
