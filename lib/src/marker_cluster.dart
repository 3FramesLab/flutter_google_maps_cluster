import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_google_maps_cluster/flutter_google_maps_cluster.dart';
import 'package:flutter_google_maps_cluster/src/clustering/cluster_algorithm.dart';
import 'package:flutter_google_maps_cluster/src/clustering/non_hierarchical_algorithm.dart';
import 'package:flutter_google_maps_cluster/src/clustering/precaching_decorator.dart';
import 'package:flutter_google_maps_cluster/src/custom_marker.dart';
import 'package:flutter_google_maps_cluster/src/point_cluster.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerCluster<T extends Clusterable> {
  final int minZoom;
  final int maxZoom;
  final int _radius = 150;

  /// Adjust the extent by powers of 2 (e.g. 512. 1024, ... max 8192) to get the
  /// desired distance between markers where they start to cluster.
  final int _extent = 2048;

  /// The size of the Quad-tree leaf node, which affects performance.
  final int _nodeSize = 64;

  final List<T> _points;

  final int clusterDensity;

  /// Store the clusters for each zoom level.
  final List<QuadTree?> _trees;

  final T Function(BaseCluster?, double?, double?)? _createCluster;

  final Map<String, CustomMarker> _markers = {};
  final Map<String, Cluster> _clusters = {};
  late ClusterAlgorithm _algorithm;
  late MarkerClusterOptions _options;

  MarkerCluster({
    required this.minZoom,
    required this.maxZoom,
    required this.clusterDensity,
    points,
    createCluster,
    required MarkerClusterOptions options,
  })  : _points = points,
        _trees = List.filled(maxZoom + 2, null),
        _createCluster = createCluster {
    _options = options;
    _algorithm = PrecachingDecorator(
      NonHierarchicalDistanceBasedAlgorithm(
        maxDistance: options.maxDistance,
      ),
    );

    var clusters = <BaseCluster>[];

    for (var i = 0; i < _points.length; i++) {
      if (_points[i].latitude == null || _points[i].longitude == null) {
        continue;
      }

      clusters.add(_createPointCluster(_points[i], i));
    }

    _trees[maxZoom + 1] = QuadTree(
      points: clusters,
      nodeSize: _nodeSize,
    );

    for (var z = maxZoom; z >= minZoom; z--) {
      clusters = _buildClusters(clusters, z);
      _trees[z] = QuadTree(points: clusters, nodeSize: _nodeSize);
    }
  }

  /// Returns a list of clusters that reside within the bounding box, where
  List<T> clusters(List<double> bbox, int zoom) {
    var minLng = ((bbox[0] + 180) % 360 + 360) % 360 - 180;
    var minLat = math.max<double>(-90, math.min(90, bbox[1]));
    var maxLng =
        bbox[2] == 180 ? 180.0 : ((bbox[2] + 180) % 360 + 360) % 360 - 180;
    var maxLat = math.max<double>(-90, math.min(90, bbox[3]));

    if (bbox[2] - bbox[0] >= 360) {
      minLng = -180;
      maxLng = 180.0;
    } else if (minLng > maxLng) {
      var easternHemisphere = clusters([minLng, minLat, 180, maxLat], zoom);
      var westernHemisphere = clusters([-180, minLat, maxLng, maxLat], zoom);

      easternHemisphere.addAll(westernHemisphere);

      return easternHemisphere;
    }

    var tree = _trees[_limitZoom(zoom)]!;
    List<int?> ids =
        tree.range(_lngX(minLng), _latY(maxLat), _lngX(maxLng), _latY(minLat));

    var result = <T>[];

    for (var id in ids) {
      var c = tree.points[id!];
      if (c.pointsSize != null && c.pointsSize! > 0) {
        if (c.pointsSize == 1) {
          result.add(c as T);
        } else if (c.pointsSize! > clusterDensity - 1) {
          result.add(_createCluster!(c, _xLng(c.x!), _yLat(c.y!)));
        } else {
          result.addAll(points(c.id!));
        }
      } else {
        result.add(_points[c.index!]);
      }
    }

    return result;
  }

  /// Returns a list of clusters that are children of the given cluster.
  List<T>? children(int? clusterId) {
    if (clusterId == null) {
      return null;
    }

    var originId = clusterId >> 5;
    var originZoom = clusterId % 32;

    var index = _trees[originZoom];
    if (index == null) {
      return null;
    }

    var origin = index.points[originId];

    var r = _radius / (_extent * math.pow(2, originZoom - 1));
    List<int?> ids = index.within(origin.x ?? 0.0, origin.y ?? 0.0, r);

    var children = <T>[];
    for (var id in ids) {
      var c = index.points[id!];

      if (c.parentId == clusterId) {
        children.add((c.pointsSize != null && c.pointsSize! > 0)
            ? _createCluster!(c, _xLng(c.x!), _yLat(c.y!))
            : _points[c.index!]);
      }
    }

    return children;
  }

  /// Returns a list of standalone points (not clusters) that are children
  List<T> points(int clusterId) {
    var points = <T>[];

    _extractClusterPoints(clusterId, points);

    return points;
  }

  /// Find the children that are individual media points, not other clusters.
  void _extractClusterPoints(int? clusterId, List<T> points) {
    var childList = children(clusterId);

    if (childList == null || childList.isEmpty) {
      return;
    } else {
      for (var child in childList) {
        if (child.isCluster!) {
          _extractClusterPoints(int.tryParse(child.markerId ?? ''), points);
        } else {
          points.add(child);
        }
      }
    }
  }

  PointCluster _createPointCluster(T feature, int id) {
    var x = _lngX(feature.longitude!);
    var y = _latY(feature.latitude!);

    return PointCluster(
        x: x, y: y, zoom: 24, index: id, markerId: feature.markerId);
  }

  List<BaseCluster> _buildClusters(List<BaseCluster> points, int zoom) {
    var clusters = <BaseCluster>[];
    var r = _radius / (_extent * math.pow(2, zoom));

    for (var i = 0; i < points.length; i++) {
      var p = points[i];
      if ((p.zoom ?? 0) <= zoom) {
        continue;
      }
      p.zoom = zoom;

      var tree = _trees[zoom + 1];
      var neighborIds = tree != null
          ? tree.within(
              p.x ?? 0.0,
              p.y ?? 0.0,
              r,
            )
          : [];

      var pointsSize = p.pointsSize ?? 1;
      var wx = (p.x ?? 0.0) * pointsSize;
      var wy = (p.y ?? 0.0) * pointsSize;

      String? childMarkerId;
      if (p.childMarkerId != null) {
        childMarkerId = p.childMarkerId;
      } else {
        childMarkerId = p.markerId;
      }

      var id = (i << 5) + (zoom + 1);

      for (int neighborId in neighborIds) {
        var b = tree?.points[neighborId];
        if (b == null) {
          continue;
        }

        if ((b.zoom ?? -1) <= zoom) {
          continue;
        }
        b.zoom = zoom;

        var pointsSize2 = b.pointsSize ?? 1;
        wx += (b.x ?? 0.0) * pointsSize2;
        wy += (b.y ?? 0.0) * pointsSize2;

        pointsSize += pointsSize2;
        b.parentId = id;
      }

      if (pointsSize == 1) {
        clusters.add(p);
      } else if (pointsSize > 1) {
        p.parentId = id;
        clusters.add(Cluster(
            id: id,
            position: LatLng(
              _xLng(wx / pointsSize),
              _yLat(wy / pointsSize),
            ),
            items: [],
            options: _options,
            pointsSize: pointsSize,
            childMarkerId: childMarkerId));
      }
    }

    return clusters;
  }

  double _lngX(double lng) {
    return lng / 360 + 0.5;
  }

  double _latY(double lat) {
    var sin = math.sin(lat * math.pi / 180);
    var y = 0.5 - 0.25 * math.log((1 + sin) / (1 - sin)) / math.pi;

    return y < 0
        ? 0
        : y > 1
            ? 1
            : y;
  }

  double _xLng(double x) {
    return (x - 0.5) * 360;
  }

  double _yLat(double y) {
    var y2 = (180 - y * 360) * math.pi / 180;
    return 360 * math.atan(math.exp(y2)) / math.pi - 90;
  }

  int _limitZoom(int z) {
    return math.max(minZoom, math.min(z, maxZoom + 1));
  }

  void updateMarkers(List<CustomMarker> markers) {
    // Clear existing markers
    _markers.clear();

    // Add new markers
    for (final marker in markers) {
      _markers[marker.id] = marker;
    }

    _recalculateClusters();
  }

  void _recalculateClusters() {
    final oldClusters = Map<String, Cluster>.from(_clusters);
    _clusters.clear();

    // Get new clusters from algorithm
    final points = _markers.values
        .map((m) => ClusterPoint(
              position: m.position,
              data: m,
            ))
        .toList();

    final newClusters = _algorithm.cluster(points);

    // Create new cluster objects
    for (final cluster in newClusters) {
      final String clusterId = _generateClusterId(cluster.points);

      _clusters[clusterId] = Cluster(
        id: int.parse(clusterId),
        position: cluster.center,
        items: cluster.points.map((p) => p.data as CustomMarker).toList(),
        options: _options,
      );
    }

    // Animate transitions
    _animateClusterChanges(oldClusters, _clusters);
  }

  void _animateClusterChanges(
    Map<String, Cluster> oldClusters,
    Map<String, Cluster> newClusters,
  ) {
    // Find clusters to animate
    final appearing = <String>{};
    final disappearing = <String>{};
    final moving = <String>{};

    for (final id in newClusters.keys) {
      if (!oldClusters.containsKey(id)) {
        appearing.add(id);
      } else if (oldClusters[id]!.position != newClusters[id]!.position) {
        moving.add(id);
      }
    }

    for (final id in oldClusters.keys) {
      if (!newClusters.containsKey(id)) {
        disappearing.add(id);
      }
    }

    // Apply animations
    for (final id in appearing) {
      _animateClusterAppear(newClusters[id]!);
    }

    for (final id in disappearing) {
      _animateClusterDisappear(oldClusters[id]!);
    }

    for (final id in moving) {
      _animateClusterMove(
        oldClusters[id]!,
        newClusters[id]!,
      );
    }
  }

  void _animateClusterAppear(Cluster cluster) {
    // Implement appear animation
    cluster.animateScale(
      begin: 0.0,
      end: 1.0,
      duration: _options.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _animateClusterDisappear(Cluster cluster) {
    // Implement disappear animation
    cluster.animateScale(
      begin: 1.0,
      end: 0.0,
      duration: _options.animationDuration,
      curve: Curves.easeInCubic,
    );
  }

  void _animateClusterMove(Cluster oldCluster, Cluster newCluster) {
    // Implement move animation
    newCluster.animatePosition(
      begin: oldCluster.position,
      end: newCluster.position,
      duration: _options.animationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  String _generateClusterId(List<ClusterPoint> points) {
    return points.map((p) => (p.data as CustomMarker).id).join('-');
  }
}

// Add new options class for customization
class MarkerClusterOptions {
  final double maxDistance;
  final Duration animationDuration;
  final Widget Function(Cluster)? clusterWidgetBuilder;
  final Widget Function(CustomMarker)? markerWidgetBuilder;

  const MarkerClusterOptions({
    this.maxDistance = 120,
    this.animationDuration = const Duration(milliseconds: 300),
    this.clusterWidgetBuilder,
    this.markerWidgetBuilder,
  });
}

// Add Cluster class
class Cluster extends BaseCluster {
  final LatLng position;
  final List<CustomMarker> items;
  final MarkerClusterOptions options;

  Cluster({
    required int id,
    required this.position,
    required this.items,
    required this.options,
    double? x,
    double? y,
    int? pointsSize,
    String? childMarkerId,
  }) : super(
          id: id,
          x: x,
          y: y,
          pointsSize: pointsSize,
          childMarkerId: childMarkerId,
        );

  Widget build(BuildContext context) {
    if (items.length == 1) {
      return options.markerWidgetBuilder?.call(items.first) ??
          _defaultMarkerWidget(items.first);
    }

    return options.clusterWidgetBuilder?.call(this) ?? _defaultClusterWidget();
  }

  Widget _defaultMarkerWidget(CustomMarker marker) {
    // Implement default marker widget
    return const Icon(Icons.location_pin, color: Colors.red);
  }

  Widget _defaultClusterWidget() {
    // Implement default cluster widget
    return Container(
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          items.length.toString(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // Animation methods
  void animateScale({
    required double begin,
    required double end,
    required Duration duration,
    required Curve curve,
  }) {
    // Implement scale animation
  }

  void animatePosition({
    required LatLng begin,
    required LatLng end,
    required Duration duration,
    required Curve curve,
  }) {
    // Implement position animation
  }
}
