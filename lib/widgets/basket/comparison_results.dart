import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/store_branding.dart';
import '../../models/price_intelligence.dart';
import '../../service/basket_comparison_service.dart';
import '../../service/price_intelligence_service.dart';
import '../store_comparison_card.dart';

class ComparisonResults extends StatefulWidget {
  final BasketComparisonResult result;

  const ComparisonResults({super.key, required this.result});

  @override
  State<ComparisonResults> createState() => _ComparisonResultsState();
}

class _ComparisonResultsState extends State<ComparisonResults> {
  Map<String, PriceIntelligence> _intelligenceByBarcode = {};

  bool _loadingAdvisor = true;
  String? _advisorError;

  BasketComparisonResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    _loadBasketIntelligence();
  }

  @override
  void didUpdateWidget(covariant ComparisonResults oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_basketSignature(oldWidget.result) != _basketSignature(widget.result)) {
      _loadBasketIntelligence();
    }
  }

  String _basketSignature(BasketComparisonResult comparisonResult) {
    if (comparisonResult.stores.isEmpty) {
      return '';
    }

    final itemsByBarcode = <String, BasketStoreItemResult>{};

    for (final store in comparisonResult.stores) {
      for (final item in store.items) {
        final barcode = item.barcode.trim();

        if (barcode.isEmpty) {
          continue;
        }

        itemsByBarcode.putIfAbsent(barcode, () => item);
      }
    }

    final signatures =
        itemsByBarcode.values
            .map((item) => '${item.barcode.trim()}:${item.quantity}')
            .toList()
          ..sort();

    return signatures.join('|');
  }

  Map<String, BasketStoreItemResult> get _basketItems {
    final itemsByBarcode = <String, BasketStoreItemResult>{};

    for (final store in result.stores) {
      for (final item in store.items) {
        final barcode = item.barcode.trim();

        if (barcode.isEmpty) {
          continue;
        }

        itemsByBarcode.putIfAbsent(barcode, () => item);
      }
    }

    return itemsByBarcode;
  }

  Future<void> _loadBasketIntelligence() async {
    final barcodes = _basketItems.keys.toList();

    if (barcodes.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _intelligenceByBarcode = {};
        _loadingAdvisor = false;
        _advisorError = null;
      });

      return;
    }

    setState(() {
      _loadingAdvisor = true;
      _advisorError = null;
    });

    try {
      final intelligence = await PriceIntelligenceService.analyzeProducts(
        barcodes: barcodes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _intelligenceByBarcode = intelligence;
        _loadingAdvisor = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _intelligenceByBarcode = {};
        _loadingAdvisor = false;
        _advisorError = 'Unable to analyze this basket: $error';
      });
    }
  }

  BasketStoreComparison? get bestUnitValueStore {
    if (result.stores.isEmpty) {
      return null;
    }

    final storesWithComparablePrices = result.stores
        .where((store) => store.normalizedItems > 0)
        .toList();

    if (storesWithComparablePrices.isEmpty) {
      return null;
    }

    storesWithComparablePrices.sort((first, second) {
      final bestValueComparison = second.bestValueItems.compareTo(
        first.bestValueItems,
      );

      if (bestValueComparison != 0) {
        return bestValueComparison;
      }

      final normalizedComparison = second.normalizedItems.compareTo(
        first.normalizedItems,
      );

      if (normalizedComparison != 0) {
        return normalizedComparison;
      }

      if (first.isComplete && !second.isComplete) {
        return -1;
      }

      if (!first.isComplete && second.isComplete) {
        return 1;
      }

      return first.total.compareTo(second.total);
    });

    final bestStore = storesWithComparablePrices.first;

    if (bestStore.bestValueItems <= 0) {
      return null;
    }

    return bestStore;
  }

  List<_BasketIntelligenceItem> get _advisorItems {
    final basketItems = _basketItems;
    final items = <_BasketIntelligenceItem>[];

    for (final entry in _intelligenceByBarcode.entries) {
      final basketItem = basketItems[entry.key];

      if (basketItem == null) {
        continue;
      }

      items.add(
        _BasketIntelligenceItem(
          barcode: entry.key,
          productName: basketItem.productName,
          quantity: basketItem.quantity,
          intelligence: entry.value,
        ),
      );
    }

    items.sort((first, second) {
      final recommendationComparison = _recommendationPriority(
        first.intelligence.recommendation,
      ).compareTo(_recommendationPriority(second.intelligence.recommendation));

      if (recommendationComparison != 0) {
        return recommendationComparison;
      }

      return first.productName.toLowerCase().compareTo(
        second.productName.toLowerCase(),
      );
    });

    return items;
  }

  int _recommendationPriority(BuyRecommendation recommendation) {
    switch (recommendation) {
      case BuyRecommendation.excellentBuy:
        return 0;
      case BuyRecommendation.goodBuy:
        return 1;
      case BuyRecommendation.fairPrice:
        return 2;
      case BuyRecommendation.wait:
        return 3;
      case BuyRecommendation.insufficientData:
        return 4;
    }
  }

  List<_BasketIntelligenceItem> _itemsFor(BuyRecommendation recommendation) {
    return _advisorItems
        .where((item) => item.intelligence.recommendation == recommendation)
        .toList();
  }

  double get _estimatedWaitingSavings {
    double total = 0;

    for (final item in _itemsFor(BuyRecommendation.wait)) {
      final intelligence = item.intelligence;
      final amountAboveAverage =
          intelligence.currentPrice - intelligence.averagePrice;

      if (amountAboveAverage > 0) {
        total += amountAboveAverage * item.quantity;
      }
    }

    return total;
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }

    return quantity.toStringAsFixed(2);
  }

  String _advisorMessage(_BasketIntelligenceItem item) {
    final intelligence = item.intelligence;
    final difference = intelligence.currentVsAveragePercent.abs();

    switch (intelligence.recommendation) {
      case BuyRecommendation.excellentBuy:
        if (intelligence.isHistoricalLow) {
          return '${item.productName} is at its '
              'historical low of '
              '\$${intelligence.currentPrice.toStringAsFixed(2)}.';
        }

        if (intelligence.currentVsAveragePercent < 0) {
          return '${item.productName} is '
              '${difference.toStringAsFixed(1)}% below '
              'its historical average.';
        }

        return '${item.productName} is currently an '
            'excellent buying opportunity.';

      case BuyRecommendation.goodBuy:
        if (intelligence.currentVsAveragePercent < 0) {
          return '${item.productName} is '
              '${difference.toStringAsFixed(1)}% below '
              'its historical average.';
        }

        if (intelligence.trend == PriceTrend.falling) {
          return '${item.productName} is priced well '
              'and its recent trend is falling.';
        }

        return '${item.productName} is currently priced '
            'better than usual.';

      case BuyRecommendation.fairPrice:
        if (intelligence.trend == PriceTrend.rising) {
          return '${item.productName} is near its usual '
              'price, but the recent trend is rising.';
        }

        if (intelligence.trend == PriceTrend.falling) {
          return '${item.productName} is near its usual '
              'price and the recent trend is falling.';
        }

        return '${item.productName} is close to its '
            'historical average.';

      case BuyRecommendation.wait:
        if (intelligence.isHistoricalHigh) {
          return '${item.productName} is at its '
              'historical high of '
              '\$${intelligence.currentPrice.toStringAsFixed(2)}.';
        }

        if (intelligence.currentVsAveragePercent > 0) {
          return '${item.productName} is '
              '${difference.toStringAsFixed(1)}% above '
              'its historical average.';
        }

        return '${item.productName} may be worth '
            'waiting to purchase.';

      case BuyRecommendation.insufficientData:
        return '${item.productName} needs more price '
            'history before Rocket Science Shopping can recommend '
            'buying or waiting.';
    }
  }

  Color _recommendationColor(BuyRecommendation recommendation) {
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
        return Colors.blueGrey;
    }
  }

  IconData _recommendationIcon(BuyRecommendation recommendation) {
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

  Widget _buildAdvisorMetric({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 135,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorGroup({
    required String title,
    required BuyRecommendation recommendation,
    required List<_BasketIntelligenceItem> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = _recommendationColor(recommendation);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_recommendationIcon(recommendation), color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$title (${items.length})',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _advisorMessage(item),
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                  if (item.quantity != 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      '×${_formatQuantity(item.quantity)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingAdvisor() {
    if (_loadingAdvisor) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Analyzing basket price history...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_advisorError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.psychology_alt_outlined,
                size: 44,
                color: AppColors.warning,
              ),
              const SizedBox(height: 10),
              const Text(
                'Shopping Advisor Unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_advisorError!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loadBasketIntelligence,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_intelligenceByBarcode.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.psychology_alt_outlined,
                size: 44,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 10),
              const Text(
               'Rocket Science Shopping Advisor', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'There is not enough price history to '
                'analyze the products in this basket yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_basketItems.length} basket item'
                '${_basketItems.length == 1 ? '' : 's'} '
                'checked',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final excellentItems = _itemsFor(BuyRecommendation.excellentBuy);

    final goodItems = _itemsFor(BuyRecommendation.goodBuy);

    final fairItems = _itemsFor(BuyRecommendation.fairPrice);

    final waitItems = _itemsFor(BuyRecommendation.wait);

    final insufficientItems = _itemsFor(BuyRecommendation.insufficientData);

    final buyTodayCount = excellentItems.length + goodItems.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primary, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0x1AD6001C),
                    child: Icon(
                      Icons.psychology_alt,
                      color: AppColors.primary,
                      size: 29,
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rocket Science Shopping Advisor',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Recommendations based on '
                          'historical price patterns.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildAdvisorMetric(
                    value: '$buyTodayCount',
                    label: 'Buy opportunities',
                    color: AppColors.success,
                  ),
                  _buildAdvisorMetric(
                    value: '${fairItems.length}',
                    label: 'Fair-price items',
                    color: Colors.blue.shade700,
                  ),
                  _buildAdvisorMetric(
                    value: '${waitItems.length}',
                    label: 'Consider waiting',
                    color: Colors.orange.shade800,
                  ),
                ],
              ),
              if (waitItems.isNotEmpty && _estimatedWaitingSavings > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The items marked “wait” are '
                          'approximately '
                          '\$${_estimatedWaitingSavings.toStringAsFixed(2)} '
                          'above their combined historical '
                          'average at the selected quantities.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildAdvisorGroup(
                title: 'Excellent Buys',
                recommendation: BuyRecommendation.excellentBuy,
                items: excellentItems,
              ),
              _buildAdvisorGroup(
                title: 'Good Buys',
                recommendation: BuyRecommendation.goodBuy,
                items: goodItems,
              ),
              _buildAdvisorGroup(
                title: 'Fair Prices',
                recommendation: BuyRecommendation.fairPrice,
                items: fairItems,
              ),
              _buildAdvisorGroup(
                title: 'Consider Waiting',
                recommendation: BuyRecommendation.wait,
                items: waitItems,
              ),
              _buildAdvisorGroup(
                title: 'More History Needed',
                recommendation: BuyRecommendation.insufficientData,
                items: insufficientItems,
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${_intelligenceByBarcode.length} of '
                      '${_basketItems.length} basket item'
                      '${_basketItems.length == 1 ? '' : 's'} '
                      'had usable price history. '
                      'Recommendations are estimates and '
                      'do not account for urgency, coupons, '
                      'inventory, or personal preference.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.35,
                      ),
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

  Widget _buildCheapestBasketSummary() {
    final cheapest = result.cheapestCompleteStore;

    if (cheapest == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber,
                size: 46,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Complete Basket Available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No store currently has recorded prices '
                'for every item in this basket. Partial '
                'totals are shown below but are not '
                'eligible for cheapest-basket ranking.',
                textAlign: TextAlign.center,
              ),
              if (result.stores.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '${result.stores.length} store'
                  '${result.stores.length == 1 ? '' : 's'} '
                  'checked',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final branding = StoreBranding.fromStoreName(cheapest.storeName);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.success, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, size: 32, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cheapest Complete Basket',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: branding.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: branding.primaryColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      branding.icon,
                      color: branding.primaryColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branding.displayName,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: branding.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${cheapest.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  result.potentialSavings > 0
                      ? 'Potential savings compared with '
                            'the highest complete basket: '
                            '\$${result.potentialSavings.toStringAsFixed(2)}'
                      : 'No savings difference is '
                            'available between complete '
                            'baskets.',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${cheapest.pricedItems} item'
                '${cheapest.pricedItems == 1 ? '' : 's'} '
                'priced'
                '${cheapest.normalizedItems > 0 ? ' • '
                          '${cheapest.normalizedItems} with unit pricing' : ''}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBestUnitValueSummary() {
    final bestStore = bestUnitValueStore;

    if (bestStore == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.scale_outlined, size: 30, color: Colors.black45),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit-Price Comparison Unavailable',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Normalized pricing has not yet '
                      'been recorded for the products '
                      'in this basket.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final branding = StoreBranding.fromStoreName(bestStore.storeName);

    final tiedStores = result.stores.where((store) {
      return store.storeId != bestStore.storeId &&
          store.bestValueItems == bestStore.bestValueItems &&
          store.bestValueItems > 0;
    }).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: branding.primaryColor, width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 32,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Most Best-Value Items',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                branding.displayName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: branding.primaryColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${bestStore.bestValueItems} item'
                '${bestStore.bestValueItems == 1 ? '' : 's'} '
                'with the lowest comparable unit price',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${bestStore.normalizedItems} item'
                '${bestStore.normalizedItems == 1 ? '' : 's'} '
                'at this store '
                '${bestStore.normalizedItems == 1 ? 'has' : 'have'} '
                'normalized unit pricing.',
              ),
              if (tiedStores.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: branding.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tiedStores.length == 1
                        ? '${StoreBranding.fromStoreName(tiedStores.first.storeName).displayName} '
                              'is tied with the same number '
                              'of best-value items.'
                        : '${tiedStores.length} other '
                              'stores are tied with the same '
                              'number of best-value items.',
                    style: TextStyle(
                      color: branding.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'This ranking compares compatible unit '
                'prices. It does not replace the '
                'complete-basket total shown above.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cheapest = result.cheapestCompleteStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        const Text(
          'Comparison Results',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCheapestBasketSummary(),
        const SizedBox(height: 14),
        _buildBestUnitValueSummary(),
        const SizedBox(height: 14),
        _buildShoppingAdvisor(),
        const SizedBox(height: 18),
        const Text(
          'Store Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...result.stores.map(
          (store) => StoreComparisonCard(
            store: store,
            isCheapest: cheapest != null && store.storeId == cheapest.storeId,
            potentialSavings: result.potentialSavings,
          ),
        ),
      ],
    );
  }
}

class _BasketIntelligenceItem {
  final String barcode;
  final String productName;
  final double quantity;
  final PriceIntelligence intelligence;

  const _BasketIntelligenceItem({
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.intelligence,
  });
}
