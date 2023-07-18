import 'package:flutter_google_maps_cluster/src/clusterable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarker extends Clusterable {
  final String id;
  final LatLng position;
  final BitmapDescriptor? icon;
  final int row;
  final int column;
  MapMarker({
    required this.id,
    required this.position,
    this.icon,
    required this.row,
    required this.column,
    isCluster = false,
    clusterId,
    pointsSize,
    childMarkerId,
  }) : super(
          markerId: id,
          latitude: position.latitude,
          longitude: position.longitude,
          isCluster: isCluster,
          clusterId: clusterId,
          pointsSize: pointsSize,
          childMarkerId: childMarkerId,
        );
}
