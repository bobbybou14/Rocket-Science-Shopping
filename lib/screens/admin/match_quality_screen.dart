import 'package:flutter/material.dart';

import '../../models/match_quality_summary.dart';
import '../../service/match_quality_service.dart';
import 'product_import_candidates_screen.dart';

class MatchQualityScreen extends StatefulWidget {
  const MatchQualityScreen({super.key});

  @override
  State<MatchQualityScreen> createState() => _MatchQualityScreenState();
}

class _MatchQualityScreenState extends State<MatchQualityScreen> {
  late Future<MatchQualitySummary> _summary;

  _DateRangeFilter _selectedFilter = _DateRangeFilter.allTime;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case _DateRangeFilter.allTime:
        _summary = MatchQualityService.getSummary();
        break;

      case _DateRangeFilter.last7Days:
        _summary = MatchQualityService.getSummary(
          fromDate: now.subtract(const Duration(days: 7)),
          toDate: now,
        );
        break;

      case _DateRangeFilter.last30Days:
        _summary = MatchQualityService.getSummary(
          fromDate: now.subtract(const Duration(days: 30)),
          toDate: now,
        );
        break;
    }
  }

  Future<void> _refreshSummary() async {
    setState(_loadSummary);

    await _summary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Quality'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<_DateRangeFilter>(
              value: _selectedFilter,
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedFilter = value;
                  _loadSummary();
                });
              },
              items: const [
                DropdownMenuItem(
                  value: _DateRangeFilter.allTime,
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: _DateRangeFilter.last7Days,
                  child: Text('7 Days'),
                ),
                DropdownMenuItem(
                  value: _DateRangeFilter.last30Days,
                  child: Text('30 Days'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Import Candidates',
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductImportCandidatesScreen(),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _refreshSummary,
            tooltip: 'Refresh statistics',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<MatchQualitySummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final summary = snapshot.data ?? MatchQualitySummary.empty;

          return RefreshIndicator(
            onRefresh: _refreshSummary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildOverviewCard(summary),
                const SizedBox(height: 18),
                _buildConfidenceCard(summary),
                const SizedBox(height: 18),
                _buildStoreQualityCard(summary),
                const SizedBox(height: 18),
                _buildUnmatchedItemsCard(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(MatchQualitySummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Overall Match Quality',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Lifetime statistics from saved shopping-trip items.'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Total Items',
                  value: summary.totalItems.toString(),
                  icon: Icons.receipt_long_outlined,
                ),
                _MetricCard(
                  label: 'Matched',
                  value: summary.matchedItems.toString(),
                  icon: Icons.check_circle_outline,
                ),
                _MetricCard(
                  label: 'Unmatched',
                  value: summary.unmatchedItems.toString(),
                  icon: Icons.link_off_outlined,
                ),
                _MetricCard(
                  label: 'Needs Review',
                  value: summary.reviewRequiredItems.toString(),
                  icon: Icons.rate_review_outlined,
                ),
                _MetricCard(
                  label: 'Average Confidence',
                  value: '${summary.averageConfidence.toStringAsFixed(1)}%',
                  icon: Icons.speed_outlined,
                ),
                _MetricCard(
                  label: 'Match Rate',
                  value: '${summary.matchRate.toStringAsFixed(1)}%',
                  icon: Icons.analytics_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard(MatchQualitySummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confidence Distribution',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'How saved receipt items are distributed across confidence '
              'levels.',
            ),
            const SizedBox(height: 20),
            _ConfidenceRow(
              label: 'High confidence',
              description: '75% and above',
              count: summary.highConfidenceItems,
              total: summary.totalItems,
              icon: Icons.verified_outlined,
            ),
            const SizedBox(height: 18),
            _ConfidenceRow(
              label: 'Medium confidence',
              description: '60% to 74.9%',
              count: summary.mediumConfidenceItems,
              total: summary.totalItems,
              icon: Icons.help_outline,
            ),
            const SizedBox(height: 18),
            _ConfidenceRow(
              label: 'Low confidence',
              description: 'Below 60%',
              count: summary.lowConfidenceItems,
              total: summary.totalItems,
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreQualityCard(MatchQualitySummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Match Quality by Store',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compare match performance across stores represented in '
              'saved shopping trips.',
            ),
            const SizedBox(height: 18),
            if (summary.stores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No store statistics are available yet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...summary.stores.map(
                (store) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _StoreQualityRow(store: store),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnmatchedItemsCard(MatchQualitySummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Top Unmatched Receipt Items',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Frequently unmatched receipt wording can identify missing '
              'products, aliases, or dictionary entries.',
            ),
            const SizedBox(height: 18),
            if (summary.commonUnmatchedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No unmatched receipt items were found.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...summary.commonUnmatchedItems.asMap().entries.map((entry) {
                final position = entry.key + 1;
                final item = entry.value;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(position.toString())),
                  title: Text(
                    item.receiptName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${item.occurrences}×',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60),
                const SizedBox(height: 14),
                const Text(
                  'Match Statistics Could Not Be Loaded',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  error?.toString() ?? 'An unknown error occurred.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _refreshSummary,
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
}

class _StoreQualityRow extends StatelessWidget {
  final StoreMatchQualitySummary store;

  const _StoreQualityRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final progress = (store.matchRate / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                store.storeName.trim().isEmpty
                    ? 'Unknown Store'
                    : store.storeName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${store.matchRate.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: progress,
          minHeight: 9,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            Text('Items: ${store.totalItems}'),
            Text('Matched: ${store.matchedItems}'),
            Text('Unmatched: ${store.unmatchedItems}'),
            Text('Review: ${store.reviewRequiredItems}'),
            Text(
              'Avg. confidence: '
              '${store.averageConfidence.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ],
    );
  }
}

enum _DateRangeFilter { allTime, last7Days, last30Days }

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: colorScheme.primary),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  final String label;
  final String description;
  final int count;
  final int total;
  final IconData icon;

  const _ConfidenceRow({
    required this.label,
    required this.description,
    required this.count,
    required this.total,
    required this.icon,
  });

  double get percentage {
    if (total == 0) {
      return 0;
    }

    return count / total;
  }

  @override
  Widget build(BuildContext context) {
    final percentageText = '${(percentage * 100).toStringAsFixed(1)}%';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '$count · $percentageText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage.clamp(0, 1),
                minHeight: 9,
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
