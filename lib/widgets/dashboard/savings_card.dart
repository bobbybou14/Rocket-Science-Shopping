import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SavingsCard extends StatelessWidget {
  final double? savingsAmount;
  final VoidCallback? onTap;

  const SavingsCard({super.key, this.savingsAmount, this.onTap});

  bool get hasSavings => savingsAmount != null && savingsAmount! > 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success.withValues(alpha: 0.16),
                AppColors.primary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.savings,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Savings Tracker',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasSavings) ...[
                      Text(
                        '\$${savingsAmount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Estimated savings this month',
                        style: TextStyle(fontSize: 15),
                      ),
                    ] else ...[
                      const Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'As Rocket Science Shopping learns more prices, your estimated grocery savings will appear here.',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Icon(Icons.chevron_right, color: AppColors.success),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
