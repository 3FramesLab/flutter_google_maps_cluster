class BaseCluster {
  double? x;
  double? y;
  int? zoom;
  int? pointsSize;
  int? parentId;
  int? index;
  int? id;
  bool isCluster = false;

  String? markerId;

  /// For clusters that wish to display one representation of its children.
  String? childMarkerId;
}
