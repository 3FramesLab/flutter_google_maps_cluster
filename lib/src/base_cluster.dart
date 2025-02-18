class BaseCluster {
  double? x;
  double? y;
  int? id;
  int? zoom;
  int? parentId;
  int? pointsSize;
  int? index;
  bool isCluster = false;
  String? childMarkerId;
  String? markerId;

  BaseCluster({
    this.x,
    this.y,
    this.id,
    this.zoom,
    this.parentId,
    this.pointsSize,
    this.index,
    this.childMarkerId,
    this.markerId,
    this.isCluster = false,
  });
}
