import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/map_data.dart';
import 'map_geometry.dart';

/// A group of markers that sit close enough together to share one dot.
class MapCluster {
  const MapCluster({required this.places, required this.center});

  final List<MapPlace> places;

  /// The cluster centre in screen coordinates.
  final Offset center;

  bool get isSingle => places.length == 1;
  MapPlace get first => places.first;

  /// The label shown next to a single marker.
  String get label => isSingle ? first.name : '';
}

/// Groups the visible [places] into markers at [scale]/[offset].
///
/// Names whose projected positions are closer than [tolerance] logical
/// pixels share one cluster, so a spot holding several places gets a single
/// dot with a count instead of stacked markers that a tap cannot tell apart.
List<MapCluster> buildMapClusters({
  required List<MapPlace> places,
  required MapGeometry geometry,
  required double scale,
  required Offset offset,
  required Size viewport,
  double tolerance = 16,
}) {
  final clusters = <MapCluster>[];
  final members = <List<MapPlace>>[];

  for (final place in places) {
    final screen = geometry.project(place.lon, place.lat) * scale + offset;
    if (screen.dx < -60 ||
        screen.dy < -60 ||
        screen.dx > viewport.width + 60 ||
        screen.dy > viewport.height + 60) {
      continue;
    }
    var nearest = -1;
    for (var i = 0; i < clusters.length; i++) {
      if ((clusters[i].center - screen).distance <= tolerance) {
        nearest = i;
        break;
      }
    }
    if (nearest < 0) {
      members.add([place]);
      clusters.add(MapCluster(places: [place], center: screen));
    } else {
      final group = members[nearest]..add(place);
      final center =
          (clusters[nearest].center * (group.length - 1) + screen) /
          group.length.toDouble();
      clusters[nearest] = MapCluster(
        places: List<MapPlace>.unmodifiable(group),
        center: center,
      );
    }
  }
  return clusters;
}

/// Paints the basemap and the place markers for one camera position.
class MapPainter extends CustomPainter {
  const MapPainter({
    required this.geometry,
    required this.scale,
    required this.offset,
    required this.palette,
    required this.clusters,
    required this.showLabels,
    this.showRegionLabels = true,
    this.highlightSlug,
  });

  final MapGeometry geometry;
  final double scale;
  final Offset offset;
  final MapPalette palette;
  final List<MapCluster> clusters;
  final bool showLabels;

  /// Whether the countries/kingdoms of the basemap get their name drawn.
  final bool showRegionLabels;

  /// A place to draw larger, with a halo (used by the small map cards).
  final String? highlightSlug;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.water);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    canvas.drawPath(
      geometry.land,
      Paint()
        ..style = PaintingStyle.fill
        ..color = palette.land,
    );

    // The countries/kingdoms tint the land, so they must be painted after it
    // — not under an opaque land fill, which hid them entirely.
    for (final region in geometry.regions) {
      canvas.drawPath(
        region.path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = region.color.withValues(alpha: 0.45),
      );
    }

    canvas.drawPath(
      geometry.mountains,
      Paint()
        ..style = PaintingStyle.fill
        ..color = palette.mountain,
    );

    for (final river in geometry.rivers) {
      canvas.drawPath(
        river.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = palette.river
          ..strokeWidth = math.max(0.6, (1.6 - river.rank * 0.15)) / scale,
      );
    }

    canvas.drawPath(
      geometry.coast,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..color = palette.coast
        ..strokeWidth = 1.1 / scale,
    );

    canvas.drawPath(
      geometry.borders,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = palette.border
        ..strokeWidth = 1 / scale,
    );

    for (final journey in geometry.journeys) {
      canvas.drawPath(
        journey.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale
          ..color = palette.route.withValues(alpha: 0.8),
      );
    }

    canvas.restore();

    if (showRegionLabels) _paintRegionLabels(canvas, size);
    _paintMarkers(canvas, size);
  }

  /// Draws each country/kingdom name in screen space, so it stays readable at
  /// every zoom level and sits above the tinted regions.
  void _paintRegionLabels(Canvas canvas, Size size) {
    for (final region in geometry.regions) {
      if (region.name.isEmpty) continue;
      final center = region.anchor * scale + offset;
      if (!_visible(center, size, 80)) continue;
      // Skip regions too small on screen for a legible name, so the crowded
      // janapadas of the plain do not stack their labels at world zoom.
      final bounds = region.path.getBounds();
      if (bounds.width * scale < 44 || bounds.height * scale < 18) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: region.name,
          style: TextStyle(
            color: palette.label,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 150);
      final at = center - Offset(painter.width / 2, painter.height / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            at.dx - 3,
            at.dy - 1,
            painter.width + 6,
            painter.height + 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = palette.labelHalo,
      );
      painter.paint(canvas, at);
    }
  }

  void _paintMarkers(Canvas canvas, Size size) {
    final markerPaint = Paint()..color = palette.marker;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = palette.markerText.withValues(alpha: 0.9);
    final haloPaint = Paint()..color = palette.labelHalo;

    for (final cluster in clusters) {
      final center = cluster.center;
      if (!_visible(center, size, 40)) continue;

      final highlighted =
          highlightSlug != null &&
          cluster.places.any((place) => place.slug == highlightSlug);
      if (highlighted) {
        canvas.drawCircle(
          center,
          14,
          Paint()..color = palette.marker.withValues(alpha: 0.22),
        );
        canvas.drawCircle(
          center,
          8.5,
          Paint()..color = palette.marker.withValues(alpha: 0.35),
        );
      }

      if (cluster.isSingle) {
        final radius = highlighted ? 6.0 : 4.5;
        canvas.drawCircle(center, radius, markerPaint);
        canvas.drawCircle(center, radius, ringPaint);
      } else {
        final radius = 8.0 + math.min(6.0, cluster.places.length / 4);
        canvas.drawCircle(center, radius, markerPaint);
        canvas.drawCircle(center, radius, ringPaint);
        _paintText(
          canvas,
          '${cluster.places.length}',
          center,
          TextStyle(
            color: palette.markerText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          centerAlign: true,
        );
      }
    }

    if (!showLabels) return;
    for (final cluster in clusters) {
      if (!cluster.isSingle) continue;
      final center = cluster.center;
      if (!_visible(center, size, 120)) continue;
      final style = TextStyle(
        color: palette.label,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );
      final painter = TextPainter(
        text: TextSpan(text: cluster.label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
      final at = center + const Offset(8, -6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            at.dx - 2,
            at.dy - 1,
            painter.width + 4,
            painter.height + 2,
          ),
          const Radius.circular(3),
        ),
        haloPaint,
      );
      painter.paint(canvas, at);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    bool centerAlign = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = centerAlign
        ? center - Offset(painter.width / 2, painter.height / 2)
        : center;
    painter.paint(canvas, at);
  }

  bool _visible(Offset point, Size size, double margin) =>
      point.dx >= -margin &&
      point.dy >= -margin &&
      point.dx <= size.width + margin &&
      point.dy <= size.height + margin;

  @override
  bool shouldRepaint(MapPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.palette != palette ||
      oldDelegate.clusters != clusters ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.showRegionLabels != showRegionLabels ||
      oldDelegate.highlightSlug != highlightSlug;
}
