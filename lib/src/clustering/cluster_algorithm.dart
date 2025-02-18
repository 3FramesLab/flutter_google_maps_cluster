import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class ClusterAlgorithm {
  List<ClusterResult> cluster(List<ClusterPoint> points);
}

class ClusterPoint {
  final LatLng position;
  final dynamic data;

  ClusterPoint({
    required this.position,
    required this.data,
  });
}

class ClusterResult {
  final LatLng center;
  final List<ClusterPoint> points;

  ClusterResult({
    required this.center,
    required this.points,
  });
}
