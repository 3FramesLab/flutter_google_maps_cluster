<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

### Set up Marker Cluster

Create a Marker Cluster instance once you have a set of points you'd like to cluster:

```dart
List<MapMarker> markers = getMarkers();

MarkerCluster<MapMarker> markerCluster = MarkerCluster<MapMarker>(
      minZoom: 0,
      maxZoom: 20,
      radius: 150,
      extent: 2048,
      nodeSize: 64,
      points: markers,
      createCluster: (BaseCluste? cluster, double? longitude, double? latitude) {
        lat ??= 0.0;
        lng ??= 0.0;
        final int row = ((lat + 90) ~/ gridManager.gridCellSize)
            .clamp(0, gridManager.rowCount - 1);
        final int column = ((lng + 180) ~/ gridManager.gridCellSize)
            .clamp(0, gridManager.columnCount - 1);
        return MapMarker(
            markerId: cluster.id.toString(),
            latitude: latitude,
            row: row,
            column: column,
            longitude: longitude,
            );
      });
```

### Get the clusters

You can then get the clusters for a given bounding box and zoom value, where the
bounding box = [southwestLng, southwestLat, northeastLng, northeastLat]:

```dart
List<MapMarker> clusters = markerCluster.clusters([-180, -85, 180, 85], _currentZoom);
```

### Get the cluster children

You can also get the children (points and sub-clusters inside a cluster at the
next zoom level, given the cluster id:

```dart
List<MapMarker> chilren = markerCluster.children(int clusterId);
```

### Get the cluster points

Get only the child points (not sub-clusters) of a cluster in all the remaining
zoom levels, given the cluster id:

```dart
List<MapMarker> points = markerCluster.points(clusterId);
```

