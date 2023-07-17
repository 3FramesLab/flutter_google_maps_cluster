import 'base_cluster.dart';

class PointCluster extends BaseCluster {
  PointCluster({
    double? x,
    double? y,
    int? id,
    int? pointsSize,
    String? childMarkerId,
    int? zoom,
  }) {
    this.x = x;
    this.y = y;
    this.id = id;
    this.pointsSize = pointsSize;
    this.childMarkerId = childMarkerId;

    isCluster = true;
    zoom = zoom;
    parentId = -1;
  }
}
