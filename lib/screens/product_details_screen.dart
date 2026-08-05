import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/cart_item.dart';
import '../models/price.dart';
import '../models/price_intelligence.dart';
import '../models/product.dart';
import '../service/favorites_service.dart';
import '../service/price_intelligence_service.dart';
import '../service/price_service.dart';
import 'add_price_screen.dart';
import 'price_history_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final void Function(CartItem item)? onAddToCart;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.onAddToCart,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  List<Price> prices = [];
  PriceIntelligence? intelligence;

  bool loading = true;
  bool loadingIntelligence = true;
  bool isFavorite = false;
  bool isLoadingFavorite = true;
  bool isUpdatingFavorite = false;

  String? errorMessage;
  String? intelligenceErrorMessage;

  @override
  void initState() {
    super.initState();
    loadProductDetails();
  }

  Future<void> loadProductDetails() async {
    await Future.wait([
      loadPrices(),
      loadPriceIntelligence(),
      loadFavoriteStatus(),
    ]);
  }

  Future<void> loadPricingData() async {
    await Future.wait([loadPrices(), loadPriceIntelligence()]);
  }

  Future<void> loadPrices() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final results = await PriceService.getPricesForProduct(
        widget.product.barcode,
      );

      if (!mounted) return;

      setState(() {
        prices = results;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Unable to load prices: $error';
      });
    }
  }

  Future<void> loadPriceIntelligence() async {
    setState(() {
      loadingIntelligence = true;
      intelligenceErrorMessage = null;
    });

    try {
      final result = await PriceIntelligenceService.analyzeProduct(
        barcode: widget.product.barcode,
      );

      if (!mounted) return;

      setState(() {
        intelligence = result;
        loadingIntelligence = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        intelligence = null;
        loadingIntelligence = false;
        intelligenceErrorMessage = 'Unable to analyze price history: $error';
      });
    }
  }

  Future<void> loadFavoriteStatus() async {
    setState(() {
      isLoadingFavorite = true;
    });

    try {
      final favoriteStatus = await FavoritesService.isFavorite(
        widget.product.barcode,
      );

      if (!mounted) return;

      setState(() {
        isFavorite = favoriteStatus;
        isLoadingFavorite = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load favourite status: $error')),
      );
    }
  }

  Future<void> toggleFavorite() async {
    if (isUpdatingFavorite) {
      return;
    }

    setState(() {
      isUpdatingFavorite = true;
    });

    try {
      final updatedStatus = await FavoritesService.toggleFavorite(
        widget.product,
      );

      if (!mounted) return;

      setState(() {
        isFavorite = updatedStatus;
        isUpdatingFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedStatus
                ? '${widget.product.name} added to favourites.'
                : '${widget.product.name} removed from favourites.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isUpdatingFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update favourite: $error')),
      );
    }
  }

  double get averagePrice {
    if (prices.isEmpty) return 0;

    final total = prices.fold<double>(0, (sum, price) => sum + price.price);

    return total / prices.length;
  }

  double get lowestPrice {
    if (prices.isEmpty) return 0;

    return prices.map((price) => price.price).reduce((a, b) => a < b ? a : b);
  }

  double get highestPrice {
    if (prices.isEmpty) return 0;

    return prices.map((price) => price.price).reduce((a, b) => a > b ? a : b);
  }

  double get potentialSavings {
    if (prices.length < 2) return 0;

    return highestPrice - lowestPrice;
  }

  Future<void> openAddPriceScreen() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPriceScreen(product: widget.product),
      ),
    );

    if (saved == true) {
      await loadPricingData();
    }
  }

  Future<void> openPriceHistoryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PriceHistoryScreen(product: widget.product),
      ),
    );

    if (!mounted) return;

    await loadPricingData();
  }

  void addToCart() {
    if (widget.onAddToCart == null) return;

    final hasValidPrice = prices.isNotEmpty && lowestPrice > 0;

    final item = CartItem(
      product: widget.product,
      price: hasValidPrice ? lowestPrice : 0.0,
    );

    widget.onAddToCart!(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasValidPrice
              ? '${widget.product.name} added to cart.'
              : '${widget.product.name} added to cart '
                    '(price unavailable).',
        ),
      ),
    );
  }

  Widget productImage() {
    if (widget.product.imageUrl.isEmpty) {
      return const Icon(
        Icons.shopping_bag,
        size: 110,
        color: AppColors.primary,
      );
    }

    return Image.network(
      widget.product.imageUrl,
      height: 160,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) {
        return const Icon(
          Icons.shopping_bag,
          size: 110,
          color: AppColors.primary,
        );
      },
    );
  }

  Widget favoriteStatusCard() {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isFavorite
              ? Colors.amber.withValues(alpha: 0.16)
              : AppColors.primary.withValues(alpha: 0.10),
          child: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.amber.shade800 : AppColors.primary,
          ),
        ),
        title: Text(
          isFavorite ? 'Saved to Favourites' : 'Add to Favourites',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isFavorite
              ? 'SmartCart will keep this product on your watchlist.'
              : 'Save this product to track it more easily.',
        ),
        trailing: isUpdatingFavorite
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: isUpdatingFavorite ? null : toggleFavorite,
      ),
    );
  }

  Color recommendationColor(BuyRecommendation recommendation) {
    switch (recommendation) {
      case BuyRecommendation.excellentBuy:
        return AppColors.success;
      case BuyRecommendation.goodBuy:
        return Colors.green.shade700;
      case BuyRecommendation.fairPrice:
        return Colors.blue.shade700;
      case BuyRecommendation.wait:
        return Colors.orange.shade800;
      case BuyRecommendation.insufficientData:
        return Colors.grey.shade700;
    }
  }

  IconData recommendationIcon(BuyRecommendation recommendation) {
    switch (recommendation) {
      case BuyRecommendation.excellentBuy:
        return Icons.workspace_premium;
      case BuyRecommendation.goodBuy:
        return Icons.thumb_up_alt;
      case BuyRecommendation.fairPrice:
        return Icons.balance;
      case BuyRecommendation.wait:
        return Icons.schedule;
      case BuyRecommendation.insufficientData:
        return Icons.query_stats;
    }
  }

  IconData trendIcon(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.rising:
        return Icons.trending_up;
      case PriceTrend.falling:
        return Icons.trending_down;
      case PriceTrend.stable:
        return Icons.trending_flat;
      case PriceTrend.unknown:
        return Icons.show_chart;
    }
  }

  Color trendColor(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.rising:
        return Colors.red.shade700;
      case PriceTrend.falling:
        return AppColors.success;
      case PriceTrend.stable:
        return Colors.blueGrey;
      case PriceTrend.unknown:
        return Colors.grey;
    }
  }

  String percentageComparisonText(PriceIntelligence result) {
    final difference = result.currentVsAveragePercent;
    final amount = difference.abs().toStringAsFixed(1);

    if (difference < -0.05) {
      return '$amount% below average';
    }

    if (difference > 0.05) {
      return '$amount% above average';
    }

    return 'At the historical average';
  }

  String savingsText(PriceIntelligence result) {
    final savings = result.savingsVsAverage;

    if (savings > 0.005) {
      return '\$${savings.toStringAsFixed(2)} below average';
    }

    if (savings < -0.005) {
      return '\$${savings.abs().toStringAsFixed(2)} above average';
    }

    return 'No difference from average';
  }

  Widget priceIntelligenceCard() {
    if (loadingIntelligence) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Analyzing price history...'),
            ],
          ),
        ),
      );
    }

    if (intelligenceErrorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 42,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(intelligenceErrorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loadPriceIntelligence,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final result = intelligence;

    if (result == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(Icons.query_stats, size: 42, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'Price Intelligence',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Add price records to begin analyzing this product.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final accentColor = recommendationColor(result.recommendation);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    child: Icon(
                      recommendationIcon(result.recommendation),
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Intelligence',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result.recommendationTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                result.recommendationMessage,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _intelligenceHighlight(
                        label: 'Current',
                        value: '\$${result.currentPrice.toStringAsFixed(2)}',
                      ),
                    ),
                    Container(width: 1, height: 46, color: Colors.black12),
                    Expanded(
                      child: _intelligenceHighlight(
                        label: 'Compared to average',
                        value: percentageComparisonText(result),
                        valueColor: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.isHistoricalLow || result.isHistoricalHigh) ...[
                const SizedBox(height: 12),
                _historicalBadge(result),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile(
                    label: 'Average',
                    value: '\$${result.averagePrice.toStringAsFixed(2)}',
                    icon: Icons.calculate_outlined,
                  ),
                  _metricTile(
                    label: 'Median',
                    value: '\$${result.medianPrice.toStringAsFixed(2)}',
                    icon: Icons.horizontal_rule,
                  ),
                  _metricTile(
                    label: 'Lowest',
                    value: '\$${result.lowestPrice.toStringAsFixed(2)}',
                    icon: Icons.south,
                  ),
                  _metricTile(
                    label: 'Highest',
                    value: '\$${result.highestPrice.toStringAsFixed(2)}',
                    icon: Icons.north,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _informationRow(
                icon: trendIcon(result.trend),
                iconColor: trendColor(result.trend),
                label: 'Recent trend',
                value: result.trendLabel,
              ),
              _informationRow(
                icon: Icons.savings_outlined,
                iconColor: result.savingsVsAverage >= 0
                    ? AppColors.success
                    : Colors.orange.shade800,
                label: 'Current difference',
                value: savingsText(result),
              ),
              _informationRow(
                icon: Icons.fact_check_outlined,
                iconColor: AppColors.primary,
                label: 'Confidence',
                value: result.confidenceLabel,
              ),
              _informationRow(
                icon: Icons.receipt_long_outlined,
                iconColor: Colors.blueGrey,
                label: 'Price observations',
                value: '${result.observations}',
              ),
              _informationRow(
                icon: Icons.store_outlined,
                iconColor: Colors.blueGrey,
                label: 'Stores represented',
                value: '${result.storeCount}',
              ),
              if (result.confidence == IntelligenceConfidence.low) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This recommendation has low confidence. '
                          'More price records collected over time will '
                          'improve the analysis.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _historicalBadge(PriceIntelligence result) {
    final isLow = result.isHistoricalLow;

    final color = isLow ? AppColors.success : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(isLow ? Icons.celebration : Icons.warning_amber, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLow
                  ? 'Current price matches the historical low.'
                  : 'Current price matches the historical high.',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intelligenceHighlight({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 21, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget priceSummaryCard() {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loadPrices,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (prices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No current store prices available.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final bestPrice = prices.reduce(
      (current, next) => next.price < current.price ? next : current,
    );

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Best Current Price',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              bestPrice.store.isEmpty ? 'Unknown Store' : bestPrice.store,
              style: const TextStyle(fontSize: 20),
            ),
            Text(
              '\$${bestPrice.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const Divider(height: 28),
            _summaryRow('Store Average', averagePrice),
            _summaryRow('Highest Current Price', highestPrice),
            _summaryRow('Potential Store Savings', potentialSavings),
            const SizedBox(height: 6),
            Text(
              '${prices.length} current price record'
              '${prices.length == 1 ? '' : 's'} compared',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
          const SizedBox(width: 12),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget priceCard(Price price) {
    final isCheapest = prices.isNotEmpty && price.price == lowestPrice;

    final location = [
      price.city,
      price.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isCheapest ? Icons.emoji_events : Icons.store,
          color: isCheapest ? AppColors.warning : AppColors.primary,
        ),
        title: Text(
          price.store.isEmpty ? 'Unknown Store' : price.store,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: location.isEmpty ? null : Text(location),
        trailing: Text(
          '\$${price.price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCheapest ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (isLoadingFavorite)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: isUpdatingFavorite ? null : toggleFavorite,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : null,
              ),
              tooltip: isFavorite
                  ? 'Remove from Favourites'
                  : 'Add to Favourites',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadProductDetails,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            productImage(),
            const SizedBox(height: 20),
            Text(
              product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            if (product.brand.isNotEmpty)
              Text(
                product.brand,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            if (product.size.isNotEmpty)
              Text(
                product.size,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 10),
            Text(
              product.taxable ? 'Ontario HST Applies' : 'No HST',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            favoriteStatusCard(),
            const SizedBox(height: 14),
            if (widget.onAddToCart != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addToCart,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Add to Cart'),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: openPriceHistoryScreen,
                icon: const Icon(Icons.show_chart),
                label: const Text('View Price History'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: openAddPriceScreen,
                icon: const Icon(Icons.add),
                label: const Text('Add Price'),
              ),
            ),
            const SizedBox(height: 25),
            priceIntelligenceCard(),
            const SizedBox(height: 18),
            priceSummaryCard(),
            const SizedBox(height: 25),
            const Text(
              'Current Prices',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (!loading && errorMessage == null && prices.isEmpty)
              const Text('No prices found yet.', style: TextStyle(fontSize: 18))
            else if (!loading && errorMessage == null)
              ...prices.map(priceCard),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
