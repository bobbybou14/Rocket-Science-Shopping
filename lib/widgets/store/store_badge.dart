import 'package:flutter/material.dart';

class StoreBadge extends StatelessWidget {
  final String storeName;
  final bool compact;

  const StoreBadge({super.key, required this.storeName, this.compact = false});

  String get normalizedStoreName {
    return storeName.trim().toLowerCase();
  }

  String get displayName {
    final cleanedName = storeName.trim();

    if (cleanedName.isEmpty) {
      return 'Unknown Store';
    }

    return cleanedName;
  }

  Color get brandColor {
    final name = normalizedStoreName;

    if (name.contains('walmart')) {
      return const Color(0xFF0071CE);
    }

    if (name.contains('freshco')) {
      return const Color(0xFF00843D);
    }

    if (name.contains('no frills')) {
      return const Color(0xFFFFC72C);
    }

    if (name.contains('food basics')) {
      return const Color(0xFFD71920);
    }

    if (name.contains('costco')) {
      return const Color(0xFFE31837);
    }

    if (name.contains('metro')) {
      return const Color(0xFFE31837);
    }

    if (name.contains('loblaws')) {
      return const Color(0xFFE31837);
    }

    if (name.contains('real canadian superstore') ||
        name.contains('superstore')) {
      return const Color(0xFFFFC72C);
    }

    if (name.contains('sobeys')) {
      return const Color(0xFF007A33);
    }

    if (name.contains('zehrs')) {
      return const Color(0xFFE31837);
    }

    if (name.contains('giant tiger')) {
      return const Color(0xFFFFC72C);
    }

    if (name.contains('farm boy')) {
      return const Color(0xFF2E7D32);
    }

    if (name.contains('longo')) {
      return const Color(0xFF006837);
    }

    if (name.contains('independent')) {
      return const Color(0xFFFFC72C);
    }

    return Colors.blueGrey;
  }

  Color get foregroundColor {
    final name = normalizedStoreName;

    if (name.contains('no frills') ||
        name.contains('superstore') ||
        name.contains('giant tiger') ||
        name.contains('independent')) {
      return Colors.black87;
    }

    return Colors.white;
  }

  IconData get storeIcon {
    final name = normalizedStoreName;

    if (name.contains('costco')) {
      return Icons.warehouse;
    }

    if (name.contains('walmart') ||
        name.contains('superstore') ||
        name.contains('loblaws') ||
        name.contains('metro') ||
        name.contains('sobeys') ||
        name.contains('freshco') ||
        name.contains('food basics') ||
        name.contains('no frills')) {
      return Icons.storefront;
    }

    return Icons.store;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 9.0 : 12.0;
    final verticalPadding = compact ? 5.0 : 7.0;
    final iconSize = compact ? 15.0 : 18.0;
    final fontSize = compact ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(storeIcon, size: iconSize, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
