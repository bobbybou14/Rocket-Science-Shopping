import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/budget_intelligence.dart';
import '../models/savings_summary.dart';
import '../models/shopping_trip.dart';
import '../models/shopping_score.dart';
import '../models/spending_analytics.dart';
import '../service/budget_intelligence_service.dart';
import '../service/dashboard_intelligence_service.dart';
import '../service/savings_summary_service.dart';
import '../service/settings_service.dart';
import '../service/shopping_trip_service.dart';
import '../service/shopping_score_service.dart';
import '../service/spending_analytics_service.dart';
import '../widgets/dashboard/best_store_card.dart';
import '../widgets/dashboard/budget_intelligence_card.dart';
import '../widgets/dashboard/price_alerts_card.dart';
import '../widgets/dashboard/recent_trip_card.dart';
import '../widgets/dashboard/savings_summary_card.dart';
import '../widgets/dashboard/shopping_score_card.dart';
import '../widgets/dashboard/spending_analytics_card.dart';
import '../widgets/dashboard/stats_grid.dart';
import 'basket_comparison_screen.dart';
import 'favorites_screen.dart';
import 'product_catalog_screen.dart';
import 'receipt_upload_screen.dart';
import 'settings_screen.dart';
import 'shopping_trip_history_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onStartShopping;

  const DashboardScreen({super.key, required this.onStartShopping});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ShoppingTrip> trips = [];

  DashboardIntelligence intelligence = const DashboardIntelligence.empty();

  SavingsSummary savingsSummary = const SavingsSummary.empty();

  ShoppingScore shoppingScore = const ShoppingScore.empty();

  SpendingAnalytics spendingAnalytics = const SpendingAnalytics.empty();

  BudgetIntelligence budgetIntelligence = const BudgetIntelligence.empty();

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ShoppingTripService.getShoppingTrips(),
        DashboardIntelligenceService.loadDashboardIntelligence(),
        SavingsSummaryService.loadSavingsSummary(),
        SettingsService.load(),
      ]);

      final loadedTrips = results[0] as List<ShoppingTrip>;
      final loadedIntelligence = results[1] as DashboardIntelligence;
      final loadedSavingsSummary = results[2] as SavingsSummary;
      final loadedSettings = results[3] as AppSettings;

      final loadedShoppingScore = ShoppingScoreService.calculate(
        trips: loadedTrips,
        savingsSummary: loadedSavingsSummary,
        intelligence: loadedIntelligence,
      );

      final loadedSpendingAnalytics = SpendingAnalyticsService.calculate(
        trips: loadedTrips,
      );

      final loadedBudgetIntelligence = BudgetIntelligenceService.calculate(
        trips: loadedTrips,
        monthlyBudget: loadedSettings.monthlyBudget,
      );

      if (!mounted) return;

      setState(() {
        trips = loadedTrips;
        intelligence = loadedIntelligence;
        savingsSummary = loadedSavingsSummary;
        shoppingScore = loadedShoppingScore;
        spendingAnalytics = loadedSpendingAnalytics;
        budgetIntelligence = loadedBudgetIntelligence;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load dashboard information: $error';
      });
    }
  }

  Future<void> openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (!mounted) return;

    await loadDashboard();
  }

  List<ShoppingTrip> get tripsThisMonth {
    final now = DateTime.now();

    return trips.where((trip) {
      return trip.purchaseDate.year == now.year &&
          trip.purchaseDate.month == now.month;
    }).toList();
  }

  int get tripCountThisMonth => tripsThisMonth.length;

  double get spentThisMonth {
    return tripsThisMonth.fold<double>(0, (total, trip) => total + trip.total);
  }

  double get averageTripCost {
    if (tripsThisMonth.isEmpty) {
      return 0;
    }

    return spentThisMonth / tripsThisMonth.length;
  }

  int get storesVisited {
    return tripsThisMonth
        .map((trip) {
          if (trip.storeId.trim().isNotEmpty) {
            return trip.storeId.trim();
          }

          return trip.storeName.trim().toLowerCase();
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
  }

  String get monthlyStatus {
    if (tripCountThisMonth == 0) {
      return 'Start scanning receipts to build your grocery intelligence.';
    }

    if (tripCountThisMonth == 1) {
      return 'Your monthly shopping picture is starting to take shape.';
    }

    if (tripCountThisMonth < 4) {
      return 'Rocket Science Shopping is learning from your recent shopping trips.';
    }

    return 'Your grocery intelligence is active and growing.';
  }

  String money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(tripDate).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String tripLocation(ShoppingTrip trip) {
    return [
      trip.city,
      trip.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');
  }

  Widget buildSectionHeader({
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget buildHeroCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Rocket Science Shopping Intelligence',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    openScreen(const SettingsScreen());
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    color: colorScheme.onPrimary,
                  ),
                  tooltip: 'Settings',
                ),
                IconButton(
                  onPressed: loadDashboard,
                  icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                  tooltip: 'Refresh dashboard',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              monthlyStatus,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 17,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: buildHeroMetric(
                    label: 'Spent',
                    value: money(spentThisMonth),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildHeroMetric(
                    label: 'Trips',
                    value: '$tripCountThisMonth',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildHeroMetric(
                    label: 'Stores',
                    value: '$storesVisited',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeroMetric({required String label, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStartShoppingButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.onStartShopping,
        icon: const Icon(Icons.shopping_cart_checkout, size: 28),
        label: const Text(
          'Start Shopping',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final actions = [
          _DashboardAction(
            icon: Icons.receipt_long_outlined,
            title: 'Upload Receipt',
            subtitle: 'Add prices and shopping history',
            onTap: () {
              openScreen(const ReceiptUploadScreen());
            },
          ),
          _DashboardAction(
            icon: Icons.shopping_basket_outlined,
            title: 'Compare Basket',
            subtitle: 'Find the lowest basket total',
            onTap: () {
              openScreen(const BasketComparisonScreen());
            },
          ),
          _DashboardAction(
            icon: Icons.star_outline,
            title: 'My Watchlist',
            subtitle: 'Review buying opportunities',
            onTap: () {
              openScreen(const FavoritesScreen());
            },
          ),
          _DashboardAction(
            icon: Icons.inventory_2_outlined,
            title: 'Browse Products',
            subtitle: 'Search prices and history',
            onTap: () {
              openScreen(const ProductCatalogScreen());
            },
          ),
          _DashboardAction(
            icon: Icons.history,
            title: 'Shopping Trips',
            subtitle: 'Review previous receipts',
            onTap: () {
              openScreen(const ShoppingTripHistoryScreen());
            },
          ),
          _DashboardAction(
            icon: Icons.admin_panel_settings,
            title: 'Admin Tools',
            subtitle: 'Developer and catalogue management',
            onTap: () {
              openScreen(const AdminDashboardScreen());
            },
          ),
        ];

        if (isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              return buildActionCard(actions[index]);
            },
          );
        }

        return Column(
          children: [
            for (var index = 0; index < actions.length; index += 2)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index + 2 < actions.length ? 12 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildActionCard(actions[index])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: index + 1 < actions.length
                          ? buildActionCard(actions[index + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildActionCard(_DashboardAction action) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  action.icon,
                  color: colorScheme.onPrimaryContainer,
                  size: 27,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                action.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Dashboard Could Not Be Loaded',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  errorMessage ?? 'An unknown error occurred.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: loadDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildEmptyRecentTrips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 56),
            const SizedBox(height: 14),
            const Text(
              'No Shopping Trips Yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a receipt to begin building your shopping history and grocery price database.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                openScreen(const ReceiptUploadScreen());
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Upload Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRecentShoppingSection() {
    final recentTrips = trips.take(3).toList();

    return Column(
      children: [
        buildSectionHeader(
          title: 'Recent Shopping',
          subtitle: 'Your latest saved grocery trips.',
          trailing: TextButton(
            onPressed: () {
              openScreen(const ShoppingTripHistoryScreen());
            },
            child: const Text('View All'),
          ),
        ),
        const SizedBox(height: 12),
        if (recentTrips.isEmpty)
          buildEmptyRecentTrips()
        else
          ...recentTrips.map(
            (trip) => RecentTripCard(
              store: trip.storeName,
              date: formatDate(trip.purchaseDate),
              total: trip.total,
              location: tripLocation(trip),
              onTap: () {
                openScreen(const ShoppingTripHistoryScreen());
              },
            ),
          ),
      ],
    );
  }

  Widget buildDashboardContent() {
    if (isLoading) {
      return buildLoadingState();
    }

    if (errorMessage != null) {
      return buildErrorState();
    }

    final bestStore = intelligence.bestStore;

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          buildHeroCard(),

          const SizedBox(height: 18),

          ShoppingScoreCard(score: shoppingScore),

          const SizedBox(height: 18),

          buildStartShoppingButton(),

          const SizedBox(height: 28),

          buildSectionHeader(
            title: 'Savings Opportunities',
            subtitle: 'See where Rocket Science Shopping can help you save more.',
          ),

          const SizedBox(height: 12),

          SavingsSummaryCard(summary: savingsSummary),

          const SizedBox(height: 14),

          PriceAlertsCard(alerts: intelligence.priceAlerts),

          const SizedBox(height: 14),

          BestStoreCard(
            storeName: bestStore.storeName,
            totalSpent: bestStore.totalSpent,
            averageTripCost: bestStore.averageTripCost,
            trips: bestStore.tripCount,
            hasData: bestStore.hasData,
          ),

          const SizedBox(height: 30),

          buildSectionHeader(
            title: 'Monthly Snapshot',
            subtitle: 'A quick look at your grocery activity this month.',
          ),

          const SizedBox(height: 12),

          StatsGrid(
            tripCount: tripCountThisMonth,
            storeCount: storesVisited,
            amountSpent: spentThisMonth,
            averageTripCost: averageTripCost,
          ),

          const SizedBox(height: 30),

          buildSectionHeader(
            title: 'Budget Intelligence',
            subtitle:
                'Track your grocery budget and forecast your month-end spending.',
          ),

          const SizedBox(height: 12),

          BudgetIntelligenceCard(intelligence: budgetIntelligence),

          const SizedBox(height: 30),

          buildSectionHeader(
            title: 'Spending Analytics',
            subtitle:
                'Understand how, when, and where your grocery money is being spent.',
          ),

          const SizedBox(height: 12),

          SpendingAnalyticsCard(
            analytics: spendingAnalytics,
            onViewMonth: (month) {
              openScreen(
                ShoppingTripHistoryScreen(
                  initialYear: month.year,
                  initialMonth: month.month,
                ),
              );
            },
          ),

          const SizedBox(height: 32),
          buildRecentShoppingSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: buildDashboardContent());
  }
}

class _DashboardAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
