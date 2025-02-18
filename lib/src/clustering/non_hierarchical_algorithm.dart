import 'package:flutter_google_maps_cluster/src/clustering/cluster_algorithm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class NonHierarchicalDistanceBasedAlgorithm implements ClusterAlgorithm {
  final double maxDistance;

  NonHierarchicalDistanceBasedAlgorithm({
    required this.maxDistance,
  });

  @override
  List<ClusterResult> cluster(List<ClusterPoint> points) {
    if (points.isEmpty) return [];

    final clusters = <List<ClusterPoint>>[];
    final processed = <ClusterPoint>{};

    for (final point in points) {
      if (processed.contains(point)) continue;

      final cluster = <ClusterPoint>[point];
      processed.add(point);

      for (final other in points) {
        if (processed.contains(other)) continue;

        if (_calculateDistance(point.position, other.position) <= maxDistance) {
          cluster.add(other);
          processed.add(other);
        }
      }

      clusters.add(cluster);
    }

    return clusters.map((cluster) {
      final center = _calculateCenter(cluster);
      return ClusterResult(
        center: center,
        points: cluster,
      );
    }).toList();
  }

  double _calculateDistance(LatLng a, LatLng b) {
    // Using Haversine formula for distance calculation
    const r = 6371000; // Earth's radius in meters
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return 2 * r * math.asin(math.sqrt(h));
  }

  LatLng _calculateCenter(List<ClusterPoint> points) {
    if (points.isEmpty) return const LatLng(0, 0);

    double lat = 0;
    double lng = 0;

    for (final point in points) {
      lat += point.position.latitude;
      lng += point.position.longitude;
    }

    return LatLng(lat / points.length, lng / points.length);
  }
}
