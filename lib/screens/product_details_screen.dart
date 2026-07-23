import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/cart_item.dart';
import '../models/price.dart';
import '../models/product.dart';
import '../service/favorites_service.dart';
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

  bool loading = true;
  bool isFavorite = false;
  bool isLoadingFavorite = true;
  bool isUpdatingFavorite = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProductDetails();
  }

  Future<void> loadProductDetails() async {
    await Future.wait([loadPrices(), loadFavoriteStatus()]);
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
      await loadPrices();
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

    await loadPrices();
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
              : '${widget.product.name} added to cart (price unavailable).',
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
          child: Text('No price data yet.', style: TextStyle(fontSize: 18)),
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
              'Best Price',
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
            _summaryRow('Average Price', averagePrice),
            _summaryRow('Highest Price', highestPrice),
            _summaryRow('Potential Savings', potentialSavings),
            const SizedBox(height: 6),
            Text(
              '${prices.length} price record'
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
          Text(label, style: const TextStyle(fontSize: 17)),
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
