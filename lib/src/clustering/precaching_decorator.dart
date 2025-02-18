import 'package:flutter_google_maps_cluster/src/clustering/cluster_algorithm.dart';

class PrecachingDecorator implements ClusterAlgorithm {
  final ClusterAlgorithm _algorithm;
  List<ClusterResult>? _cachedResults;
  List<ClusterPoint>? _cachedPoints;

  PrecachingDecorator(this._algorithm);

  @override
  List<ClusterResult> cluster(List<ClusterPoint> points) {
    if (_cachedPoints != null && _listEquals(_cachedPoints!, points)) {
      return _cachedResults!;
    }

    final results = _algorithm.cluster(points);
    _cachedPoints = List.from(points);
    _cachedResults = results;
    return results;
  }

  bool _listEquals(List<ClusterPoint> a, List<ClusterPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].position != b[i].position) return false;
    }
    return true;
  }
}
