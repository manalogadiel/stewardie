import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/clay.dart';
import '../../core/theme.dart';
import 'revenuecat_service.dart';

/// Shows the Soft Pop Stewardie Plus paywall in a modal bottom sheet.
Future<bool?> showSoftPopPaywall(
  BuildContext context, {
  VoidCallback? onPurchased,
}) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: .72,
    minChildSize: .42,
    maxChildSize: .95,
    expand: false,
    snap: true,
    snapSizes: const [.72],
    builder: (context, controller) =>
        SoftPopPaywall(onPurchased: onPurchased, scrollController: controller),
  ),
);

class SoftPopPaywall extends StatefulWidget {
  const SoftPopPaywall({super.key, this.onPurchased, this.scrollController});
  final ScrollController? scrollController;
  final VoidCallback? onPurchased;

  @override
  State<SoftPopPaywall> createState() => _SoftPopPaywallState();
}

class _SoftPopPaywallState extends State<SoftPopPaywall> {
  bool _isAnnual = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    RevenueCatService.instance.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RevenueCatService.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revenueCat = RevenueCatService.instance;
    final offerings = revenueCat.offerings;
    final currentOffering = offerings?.current;

    // Detect actual packages from RevenueCat if available
    final annualPkg = currentOffering?.annual;
    final monthlyPkg = currentOffering?.monthly;

    final annualPrice = annualPkg?.storeProduct.priceString ?? 'Unavailable';
    final monthlyPrice = monthlyPkg?.storeProduct.priceString ?? 'Unavailable';

    return Container(
      decoration: const BoxDecoration(
        color: SoftPop.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: SoftPop.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row with Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SoftPop.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'STEWARDIE PLUS',
                      style: TextStyle(
                        color: SoftPop.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: SoftPop.secondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hero Mascot Illustration
              const Center(child: ClayArt('celebrate', height: 110)),
              const SizedBox(height: 16),

              Text(
                'A little more together',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'One individual subscription unlocks extra space, history, and moments across all your circles.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Perks List
              ClayPanel(
                color: SoftPop.surface,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: const [
                    _PerkRow(
                      icon: Icons.cottage_rounded,
                      color: SoftPop.butter,
                      title: 'Up to 20 shared spaces',
                      subtitle: 'Basic includes 3 spaces in total, created or joined.',
                    ),
                    Divider(height: 20, color: SoftPop.canvas),
                    _PerkRow(
                      icon: Icons.history_rounded,
                      color: SoftPop.sky,
                      title: 'Unlimited task history',
                      subtitle: 'Browse all retained task history in spaces you can access.',
                    ),
                    Divider(height: 20, color: SoftPop.canvas),
                    _PerkRow(
                      icon: Icons.photo_library_rounded,
                      color: SoftPop.rose,
                      title: 'Up to 5 photos per moment',
                      subtitle: 'Capture and attach multiple photos to tasks.',
                    ),
                    Divider(height: 20, color: SoftPop.canvas),
                    _PerkRow(
                      icon: Icons.verified_rounded,
                      color: SoftPop.blue,
                      title: 'Personal Plus badge',
                      subtitle: 'Special pastel clay badge displayed on your profile.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pricing Tier Selection
              Row(
                children: [
                  Expanded(
                    child: _PlanOptionCard(
                      title: 'Annual',
                      price: annualPrice,
                      subtitle: 'Billed annually',

                      selected: _isAnnual,
                      onTap: () => setState(() => _isAnnual = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlanOptionCard(
                      title: 'Monthly',
                      price: monthlyPrice,
                      subtitle: 'Flexible billing',
                      selected: !_isAnnual,
                      onTap: () => setState(() => _isAnnual = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 10),
              ],

              // Main CTA Button
              FilledButton(
                onPressed:
                    _busy ||
                        !RevenueCatService.purchasesEnabled ||
                        (_isAnnual ? annualPkg : monthlyPkg) == null
                    ? null
                    : () => _handlePurchase(annualPkg, monthlyPkg),
                style: FilledButton.styleFrom(
                  backgroundColor: SoftPop.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        !RevenueCatService.purchasesEnabled
                            ? 'Purchases are not available yet'
                            : _isAnnual
                            ? 'Start Annual Plus'
                            : 'Start Monthly Plus',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: 8),

              // Restore is available without a new purchase.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _handleRestore,
                    child: const Text(
                      'Restore purchases',
                      style: TextStyle(fontSize: 13, color: SoftPop.secondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(Package? annual, Package? monthly) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final targetPackage = _isAnnual ? annual : monthly;
    if (targetPackage == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Selected plan is not currently available.';
        });
      }
      return;
    }

    final result = await RevenueCatService.instance.purchasePackage(
      targetPackage,
    );

    if (mounted) {
      setState(() => _busy = false);
      if (result.status == PurchaseStatus.cancelled) {
        return;
      }
      if (result.status == PurchaseStatus.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment is pending approval from the store.'),
            backgroundColor: SoftPop.blue,
          ),
        );
        return;
      }
      if (result.isSuccess || result.status == PurchaseStatus.syncPending) {
        widget.onPurchased?.call();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.status == PurchaseStatus.syncPending
                  ? 'Purchase verified. Account benefits update after secure synchronization.'
                  : 'Welcome to Stewardie Plus!',
            ),
            backgroundColor: SoftPop.blue,
          ),
        );
      } else {
        setState(
          () => _error =
              result.message ?? 'Purchase could not be completed. Try again.',
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await RevenueCatService.instance.restorePurchases();
    if (mounted) {
      setState(() => _busy = false);
      if (result.isSuccess || result.status == RestoreStatus.syncPending) {
        widget.onPurchased?.call();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.status == RestoreStatus.syncPending
                  ? 'Purchases found. Syncing with your account...'
                  : 'Purchases restored successfully!',
            ),
            backgroundColor: SoftPop.blue,
          ),
        );
      } else if (result.status == RestoreStatus.noPurchases) {
        setState(() => _error = 'No previous purchases found.');
      } else {
        setState(
          () => _error = result.message ?? 'Could not restore purchases.',
        );
      }
    }
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color == SoftPop.surface ? SoftPop.blue : color,
          size: 22,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: SoftPop.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: SoftPop.secondary),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String price;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? SoftPop.surface : SoftPop.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? SoftPop.blue : SoftPop.border,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x10244BFF),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: selected ? SoftPop.blue : SoftPop.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: SoftPop.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: SoftPop.secondary),
          ),
        ],
      ),
    ),
  );
}
