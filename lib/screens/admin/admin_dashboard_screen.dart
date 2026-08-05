import 'package:flutter/material.dart';

import 'import_catalogue_screen.dart';
import 'match_quality_screen.dart';
import 'product_import_candidates_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.upload_file,
            title: 'Import Product Catalogue',
            subtitle: 'Preview and import CSV catalogues',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImportCatalogueScreen(),
                ),
              );
            },
          ),
          _AdminCard(
            icon: Icons.analytics_outlined,
            title: 'Match Quality',
            subtitle: 'Review match rates and confidence',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchQualityScreen()),
              );
            },
          ),
          _AdminCard(
            icon: Icons.bar_chart,
            title: 'Catalogue Statistics',
            subtitle: 'View product totals and categories',
            onTap: () {},
          ),
          _AdminCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: 'Import Candidates',
            subtitle: 'Products frequently seen but not yet in the catalogue',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductImportCandidatesScreen(),
                ),
              );
            },
          ),
          _AdminCard(
            icon: Icons.sell,
            title: 'Product Aliases',
            subtitle: 'Manage learned receipt aliases',
            onTap: () {},
          ),
          _AdminCard(
            icon: Icons.health_and_safety,
            title: 'System Diagnostics',
            subtitle: 'View OCR and matching diagnostics',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(icon, size: 34),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
