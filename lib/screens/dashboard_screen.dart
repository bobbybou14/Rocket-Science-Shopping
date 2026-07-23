import 'package:flutter/material.dart';

import '../models/savings_summary.dart';
import '../models/shopping_trip.dart';
import '../service/dashboard_intelligence_service.dart';
import '../service/shopping_trip_service.dart';
import '../service/savings_summary_service.dart';
import '../widgets/dashboard/best_store_card.dart';
import '../widgets/dashboard/price_alerts_card.dart';
import '../widgets/dashboard/quick_action_card.dart';
import '../widgets/dashboard/recent_trip_card.dart';
import '../widgets/dashboard/savings_summary_card.dart';
import '../widgets/dashboard/stats_grid.dart';
import '../widgets/dashboard/summary_card.dart';
import 'basket_comparison_screen.dart';
import 'favorites_screen.dart';
import 'product_catalog_screen.dart';
import 'receipt_upload_screen.dart';
import 'shopping_trip_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ShoppingTrip> trips = [];

  DashboardIntelligence intelligence = const DashboardIntelligence.empty();

  SavingsSummary savingsSummary = const SavingsSummary.empty();

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
      ]);

      final loadedTrips = results[0] as List<ShoppingTrip>;

      final loadedIntelligence = results[1] as DashboardIntelligence;

      final loadedSavingsSummary = results[2] as SavingsSummary;

      if (!mounted) return;

      setState(() {
        trips = loadedTrips;
        intelligence = loadedIntelligence;
        savingsSummary = loadedSavingsSummary;
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

  int get tripCountThisMonth {
    return tripsThisMonth.length;
  }

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

  Widget sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget loadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
    );
  }

  Widget emptyRecentTrips() {
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

  Widget quickActionsSection() {
    return Column(
      children: [
        QuickActionCard(
          icon: Icons.receipt_long,
          title: 'Upload Receipt',
          subtitle: 'Turn a grocery receipt into shopping history and prices',
          onTap: () {
            openScreen(const ReceiptUploadScreen());
          },
        ),
        QuickActionCard(
          icon: Icons.shopping_cart_checkout,
          title: 'Start Shopping',
          subtitle: 'Track your grocery cart while you shop (Coming Soon)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Scan As You Shop is coming soon!')),
            );
          },
        ),
        QuickActionCard(
          icon: Icons.history,
          title: 'Shopping Trips',
          subtitle: 'Review saved grocery trips and receipt items',
          onTap: () {
            openScreen(const ShoppingTripHistoryScreen());
          },
        ),
        QuickActionCard(
          icon: Icons.inventory_2,
          title: 'Browse Products',
          subtitle: 'Search products, compare prices, and view history',
          onTap: () {
            openScreen(const ProductCatalogScreen());
          },
        ),
        QuickActionCard(
          icon: Icons.star,
          title: 'My Watchlist',
          subtitle: 'View your favourite products and track price changes',
          onTap: () {
            openScreen(const FavoritesScreen());
          },
        ),
        QuickActionCard(
          icon: Icons.shopping_basket,
          title: 'Compare Basket',
          subtitle: 'Find the cheapest store for your grocery basket',
          onTap: () {
            openScreen(const BasketComparisonScreen());
          },
        ),
      ],
    );
  }

  Widget recentShoppingSection() {
    final recentTrips = trips.take(3).toList();

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Shopping',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                openScreen(const ShoppingTripHistoryScreen());
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentTrips.isEmpty)
          emptyRecentTrips()
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

  Widget dashboardContent() {
    if (isLoading) {
      return loadingState();
    }

    if (errorMessage != null) {
      return errorState();
    }

    final bestStore = intelligence.bestStore;

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SummaryCard(
            amountSpent: spentThisMonth,
            tripCount: tripCountThisMonth,
            storeCount: storesVisited,
          ),

          const SizedBox(height: 24),

          sectionHeading('Start Here'),
          quickActionsSection(),

          const SizedBox(height: 24),

          sectionHeading('This Month'),
          StatsGrid(
            tripCount: tripCountThisMonth,
            storeCount: storesVisited,
            amountSpent: spentThisMonth,
            averageTripCost: averageTripCost,
          ),

          const SizedBox(height: 24),

          sectionHeading('Shopping Insights'),

          BestStoreCard(
            storeName: bestStore.storeName,
            totalSpent: bestStore.totalSpent,
            averageTripCost: bestStore.averageTripCost,
            trips: bestStore.tripCount,
            hasData: bestStore.hasData,
          ),

          const SizedBox(height: 14),

          SavingsSummaryCard(summary: savingsSummary),

          const SizedBox(height: 14),

          PriceAlertsCard(alerts: intelligence.priceAlerts),

          const SizedBox(height: 24),

          recentShoppingSection(),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: dashboardContent());
  }
}
