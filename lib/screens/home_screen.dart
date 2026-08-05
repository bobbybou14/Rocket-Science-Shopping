import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/cart_item.dart';
import '../service/dashboard_service.dart';

class HomeScreen extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onScanTap;
  final VoidCallback onCartTap;

  const HomeScreen({
    super.key,
    required this.cart,
    required this.onScanTap,
    required this.onCartTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DashboardInsights insights = const DashboardInsights.empty();

  bool loadingInsights = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboardInsights();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_cartMatches(oldWidget.cart, widget.cart)) {
      loadDashboardInsights();
    }
  }

  bool _cartMatches(List<CartItem> previousCart, List<CartItem> currentCart) {
    if (previousCart.length != currentCart.length) {
      return false;
    }

    for (var index = 0; index < previousCart.length; index++) {
      final previous = previousCart[index];
      final current = currentCart[index];

      if (previous.barcode != current.barcode ||
          previous.quantity != current.quantity ||
          previous.price != current.price ||
          previous.total != current.total) {
        return false;
      }
    }

    return true;
  }

  Future<void> loadDashboardInsights() async {
    setState(() {
      loadingInsights = true;
      errorMessage = null;
    });

    try {
      final loadedInsights = await DashboardService.loadInsights(widget.cart);

      if (!mounted) return;

      setState(() {
        insights = loadedInsights;
        loadingInsights = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadingInsights = false;
        errorMessage = 'Unable to load shopping insights.';
      });
    }
  }

  String money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  Widget buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Shopping',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          widget.cart.isEmpty
              ? 'Start scanning products to build your cart.'
              : 'Your current grocery cart and savings opportunities.',
          style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onScanTap,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Product'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onCartTap,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('View Cart'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildEmptyCartState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Cart Is Empty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a grocery product to begin comparing prices and finding savings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onScanTap,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan First Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCartHero({
    required int itemCount,
    required int productCount,
    required double cartTotal,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Cart',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('Estimated using scanned prices'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCartTap,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  tooltip: 'View cart',
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              money(cartTotal),
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'} across '
              '$productCount ${productCount == 1 ? 'product' : 'products'}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInsightTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLoadingInsights() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text('Analyzing the best known prices for your cart...'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Shopping insights are temporarily unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: loadDashboardInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCoverageCard() {
    final coverage = insights.coveragePercentage.round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Price Intelligence Coverage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$coverage%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: insights.coveragePercentage / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Text(
              '${insights.productsWithKnownPrices} of '
              '${insights.productsAnalyzed} products have known comparison prices.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildShoppingInsights() {
    if (loadingInsights) {
      return buildLoadingInsights();
    }

    if (errorMessage != null) {
      return buildErrorState();
    }

    return Column(
      children: [
        buildInsightTile(
          icon: Icons.savings_outlined,
          label: 'Potential Savings',
          value: money(insights.potentialSavings),
          subtitle: insights.potentialSavings > 0
              ? 'Possible savings using the cheapest known prices.'
              : 'Your scanned prices are already competitive.',
        ),
        buildInsightTile(
          icon: Icons.storefront_outlined,
          label: 'Best Store for This Cart',
          value: insights.bestStore,
          subtitle: insights.hasPriceData
              ? 'The store with the most lowest-price products.'
              : 'More product pricing data is needed.',
        ),
        buildCoverageCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = DashboardService.cartItemCount(widget.cart);

    final productCount = DashboardService.cartProductCount(widget.cart);

    final cartTotal = DashboardService.cartTotal(widget.cart);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartCart Canada'),
        actions: [
          IconButton(
            onPressed: loadDashboardInsights,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboardInsights,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            buildHeader(),
            const SizedBox(height: 24),
            buildQuickActions(),
            const SizedBox(height: 24),
            if (widget.cart.isEmpty)
              buildEmptyCartState()
            else ...[
              buildCartHero(
                itemCount: itemCount,
                productCount: productCount,
                cartTotal: cartTotal,
              ),
              const SizedBox(height: 20),
              const Text(
                'Shopping Insights',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              buildShoppingInsights(),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
