import 'dart:math' as math;

/// OCR text and its corners in reading order: top-left, top-right,
/// bottom-right, bottom-left. Coordinates may be rotated with the image.
class ReceiptOcrFragment {
  final String text;
  final List<math.Point<double>> corners;

  const ReceiptOcrFragment({required this.text, required this.corners});
}

/// Groups OCR fragments without changing recognized characters or amounts.
class ReceiptRowReconstructionService {
  const ReceiptRowReconstructionService._();

  static String reconstruct(
    List<ReceiptOcrFragment> fragments, {
    required String fallbackText,
  }) {
    final usable = fragments
        .where((fragment) => fragment.text.trim().isNotEmpty)
        .toList();
    if (usable.isEmpty ||
        usable.any(
          (fragment) =>
              fragment.corners.length != 4 ||
              fragment.corners.any(
                (point) => !point.x.isFinite || !point.y.isFinite,
              ),
        )) {
      return fallbackText.trim();
    }
    final directions = <math.Point<double>>[];
    for (final fragment in usable) {
      final edge = fragment.corners[1] - fragment.corners[0];
      final side = fragment.corners[3] - fragment.corners[0];
      if (edge.magnitude > 0 && edge.magnitude >= side.magnitude * 3) {
        directions.add(edge * (1 / edge.magnitude));
      }
    }
    if (directions.isEmpty) return fallbackText.trim();
    var along = math.Point<double>(
      _median(directions.map((point) => point.x)),
      _median(directions.map((point) => point.y)),
    );
    if (along.magnitude < 0.5) return fallbackText.trim();
    along = along * (1 / along.magnitude);
    final down = math.Point<double>(-along.y, along.x);
    final projected = usable
        .map((fragment) => _ProjectedFragment(fragment, along, down))
        .toList();
    final referenceX = _median(projected.map((fragment) => fragment.x));
    final typicalHeight = _median(projected.map((fragment) => fragment.height));
    final directionAnchors = projected
        .where(
          (fragment) =>
              fragment.width >= fragment.height * 8 &&
              RegExp(r'[A-Za-z]').allMatches(fragment.original.text).length >=
                  3 &&
              fragment.slope.abs() < 0.2,
        )
        .toList();

    // Perspective and paper curvature change line slope down the receipt.
    // Estimate it from nearby long text, then compare all fragments at the
    // same horizontal reference. This avoids shifting a price onto the
    // preceding department heading when footer tilt differs from item tilt.
    for (final fragment in projected) {
      final nearby =
          directionAnchors
              .where(
                (anchor) => (anchor.y - fragment.y).abs() <= typicalHeight * 8,
              )
              .toList()
            ..sort(
              (first, second) => (first.y - fragment.y).abs().compareTo(
                (second.y - fragment.y).abs(),
              ),
            );
      final slope = nearby.isEmpty
          ? 0.0
          : _median(nearby.take(5).map((anchor) => anchor.slope));
      fragment.rowY = fragment.y - slope * (fragment.x - referenceX);
    }
    projected.sort((first, second) {
      final result = first.rowY.compareTo(second.rowY);
      return result != 0 ? result : first.left.compareTo(second.left);
    });
    final rows = <List<_ProjectedFragment>>[];
    for (final fragment in projected) {
      List<_ProjectedFragment>? closest;
      var closestDistance = double.infinity;
      for (final row in rows) {
        final reliable =
            [fragment, ...row].where(directionAnchors.contains).toList()
              ..sort((first, second) => second.width.compareTo(first.width));
        // A long text edge provides a direct baseline for a far-away price.
        // Use it for pairing; short price boxes have noisy edge angles.
        final distance = reliable.isEmpty
            ? (fragment.rowY - _median(row.map((existing) => existing.rowY)))
                  .abs()
            : (fragment.y -
                      _median(
                        row.map(
                          (existing) =>
                              existing.y +
                              reliable.first.slope * (fragment.x - existing.x),
                        ),
                      ))
                  .abs();
        final height = math.min(
          fragment.height,
          _median(row.map((existing) => existing.height)),
        );
        if (distance > height * 0.55 || distance >= closestDistance) continue;
        final overlaps = row.any(
          (existing) =>
              math.min(fragment.right, existing.right) -
                  math.max(fragment.left, existing.left) >
              math.min(fragment.width, existing.width) * 0.2,
        );
        if (overlaps) continue;
        closest = row;
        closestDistance = distance;
      }
      if (closest == null) {
        rows.add([fragment]);
      } else {
        closest.add(fragment);
      }
    }
    rows.sort(
      (first, second) => _median(
        first.map((fragment) => fragment.rowY),
      ).compareTo(_median(second.map((fragment) => fragment.rowY))),
    );
    return rows
        .map((row) {
          row.sort((first, second) => first.left.compareTo(second.left));
          return row.map((fragment) => fragment.original.text.trim()).join(' ');
        })
        .join('\n')
        .trim();
  }

  static double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _ProjectedFragment {
  final ReceiptOcrFragment original;
  late final double x;
  late final double y;
  late final double left;
  late final double right;
  late final double width;
  late final double height;
  late final double slope;
  double rowY = 0;

  _ProjectedFragment(
    this.original,
    math.Point<double> along,
    math.Point<double> down,
  ) {
    final xs = original.corners
        .map((point) => point.x * along.x + point.y * along.y)
        .toList();
    final ys = original.corners
        .map((point) => point.x * down.x + point.y * down.y)
        .toList();
    x = xs.reduce((a, b) => a + b) / 4;
    y = ys.reduce((a, b) => a + b) / 4;
    left = xs.reduce(math.min);
    right = xs.reduce(math.max);
    width = right - left;
    height = math.max(1, ((ys[3] - ys[0]).abs() + (ys[2] - ys[1]).abs()) / 2);
    final edgeWidth = ((xs[1] - xs[0]) + (xs[2] - xs[3])) / 2;
    slope = edgeWidth.abs() < 1
        ? 0
        : (((ys[1] - ys[0]) + (ys[2] - ys[3])) / 2) / edgeWidth;
  }
}
