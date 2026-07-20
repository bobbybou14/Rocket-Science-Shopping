import 'package:flutter/material.dart';

import '../../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  static const Color smartCartRed = Color(0xFFD6001C);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.shopping_bag,
                            color: smartCartRed,
                            size: 34,
                          ),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.shopping_bag,
                          color: smartCartRed,
                          size: 34,
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (product.brand.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          product.brand,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),

                    if (product.size.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          product.size,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          product.taxable
                              ? Icons.receipt_long
                              : Icons.check_circle,
                          color: product.taxable
                              ? Colors.orange
                              : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.taxable
                              ? 'HST Applies'
                              : 'Tax Exempt',
                          style: TextStyle(
                            color: product.taxable
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}