import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_maps_cluster/flutter_google_maps_cluster.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ClusteredMapView extends StatefulWidget {
  const ClusteredMapView({Key? key}) : super(key: key);
  @override
  _ClusteredMapViewState createState() => _ClusteredMapViewState();
}

class _ClusteredMapViewState extends State<ClusteredMapView> {
  final List<MapMarker> markers = [];
  final LatLngBounds initialBounds = LatLngBounds(
    southwest: LatLng(37.0902, -95.7129),
    northeast: LatLng(39.5501, -90.0001),
  );
  late GoogleMapController mapController;
  late MarkerCluster<MapMarker> markerCluster;
  final Set<Marker> clusterMarkers = {};
  final Set<Marker> individualMarkers = {};
  final GridManager gridManager =
      GridManager(rowCount: 3, columnCount: 5, gridCellSize: 50.0);
  final double densityThreshold = 10.0;
  late BitmapDescriptor markerIcon;
  late BitmapDescriptor clusterIcon;

  @override
  void initState() {
    super.initState();
    getMarkerBitmap();
    createMarkers();
  }

  void initializeMarkerCluster() {
    final List<MapMarker> mapMarkers = markers
        .map((markerData) => MapMarker(
              id: markerData.markerId ?? '',
              position: LatLng(
                  markerData.position.latitude, markerData.position.longitude),
              row: 0,
              column: 0,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
            ))
        .toList();

    markerCluster = MarkerCluster<MapMarker>(
      minZoom: 0,
      maxZoom: 18,
      radius: 150,
      extent: 2048,
      nodeSize: 64,
      points: mapMarkers,
      createCluster: (BaseCluster? cluster, double? lng, double? lat) {
        lat ??= 0.0;
        lng ??= 0.0;
        final int row = ((lat + 90) ~/ gridManager.gridCellSize)
            .clamp(0, gridManager.rowCount - 1);
        final int column = ((lng + 180) ~/ gridManager.gridCellSize)
            .clamp(0, gridManager.columnCount - 1);
        return MapMarker(
          id: cluster?.id.toString() ?? '',
          position: LatLng(lat, lng),
          row: row,
          column: column,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      },
    );

    updateMarkerDensity(markers);
    applyClustering(6);
  }

  void updateMarkerDensity(List<MapMarker> markers) {
    for (final row in gridManager.grid) {
      for (final cell in row) {
        cell.density = 0;
      }
    }

    // Update density for each marker
    for (final marker in markers) {
      gridManager.updateDensity(marker.position);
    }
  }

  void applyClustering(double zoom) async {
    final int currentZoom = zoom.toInt();
    final clusters = markerCluster.clusters([-180, -85, 180, 85], currentZoom);

    // Clear existing markers
    clusterMarkers.clear();
    individualMarkers.clear();

    // Add cluster markers and individual markers based on density
    for (final cluster in clusters) {
      final gridCell = gridManager.getCell(cluster.row, cluster.column);

      if (gridCell.density >= densityThreshold) {
        // int points = fluster.points(int.parse(cluster.id)).length;
        // BitmapDescriptor icon =
        //     await Utility.getClusterBitmap(150, text: '$points');
        final clusterMarker = Marker(
            markerId: MarkerId(cluster.id.toString()),
            position: cluster.position,
            // Set cluster marker icon or styling
            icon: clusterIcon,
            onTap: () {
              onMarkerTapped(true, cluster);
            }
            // Add other properties and styling as needed
            );
        clusterMarkers.add(clusterMarker);
      } else {
        // Retrieve individual markers within the cluster
        if (cluster.clusterId == null) {
          final individualMarker = Marker(
              markerId: MarkerId(cluster.id),
              position: cluster.position,
              icon: markerIcon,
              onTap: () {
                // onMarkerTapped(false);
              }
              // Add other properties and styling as needed
              );
          individualMarkers.add(individualMarker);
        } else {
          final List<MapMarker> markersInCluster =
              markerCluster.children(cluster.clusterId) ?? [];

          // Add individual markers to the set
          for (final marker in markersInCluster) {
            final individualMarker = Marker(
                markerId: MarkerId(marker.id),
                position: marker.position,
                icon: markerIcon,
                onTap: () {
                  // onMarkerTapped(false);
                }
                // Add other properties and styling as needed
                );
            individualMarkers.add(individualMarker);
          }
        }
      }
    }

    // Update the map with the updated markers
    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    initializeMarkerCluster();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clustered Map View'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        markers: clusterMarkers.union(individualMarkers),
        initialCameraPosition: CameraPosition(
          target: LatLng(37.0902, -95.7129),
          zoom: 6,
        ),
        onCameraMove: (position) {
          applyClustering(position.zoom);
        },
        onTap: (latlng) {},
      ),
    );
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void getMarkerBitmap() async {
    Uint8List markerIconBytes =
        await getBytesFromAsset('assets/cluster.png', 100);
    clusterIcon = BitmapDescriptor.fromBytes(markerIconBytes);

    Uint8List markerIconBytesMarker =
        await getBytesFromAsset('assets/pin.png', 100);
    markerIcon = BitmapDescriptor.fromBytes(markerIconBytesMarker);
  }

  void createMarkers() async {
    Uint8List markerIconBytes = await getBytesFromAsset('assets/pin.png', 100);
    final BitmapDescriptor markerIcon =
        BitmapDescriptor.fromBytes(markerIconBytes);
    for (int i = 0; i < 1000; i++) {
      double latitude = initialBounds.southwest.latitude +
          (initialBounds.northeast.latitude -
                  initialBounds.southwest.latitude) *
              (Random().nextDouble());
      double longitude = initialBounds.southwest.longitude +
          (initialBounds.northeast.longitude -
                  initialBounds.southwest.longitude) *
              (Random().nextDouble());
      final int row = ((latitude + 90) ~/ gridManager.gridCellSize)
          .clamp(0, gridManager.rowCount - 1);
      final int column = ((longitude + 180) ~/ gridManager.gridCellSize)
          .clamp(0, gridManager.columnCount - 1);
      final marker = MapMarker(
        id: 'Marker $i',
        position: LatLng(
          latitude,
          longitude,
        ),
        row: row,
        column: column,
        icon: markerIcon,
      );
      markers.add(marker);
    }
  }

  void onMarkerTapped(bool isCluster, MapMarker cluster) async {
    if (isCluster) {
      LatLngBounds position = getClusterBounds(cluster);

      final zoomLevel = await mapController.getZoomLevel();
      calculateZoomLevel(position, zoomLevel);
      final latlng = latLngBoundCenter(
        position.northeast,
        position.southwest,
      );

      if (zoomLevel != null) {
        final newZoomLevel = zoomLevel + 3;

        await mapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            latlng,
            newZoomLevel > 20 ? 20 : newZoomLevel,
          ),
        );
      }
    }
  }

  void zoomToBounds(LatLngBounds bounds) async {
    const double maxZoomLevel = 18.0; // The maximum zoom level for the map
    const double minZoomLevel = 1.0; // The minimum zoom level for the map
    const double padding = 50.0; // The padding around the bounds

    LatLng center = latLngBoundCenter(bounds.northeast, bounds.southwest);
    double zoomLevel = maxZoomLevel;

    // Calculate the zoom level to fit the bounds
    while (zoomLevel > minZoomLevel) {
      final LatLngBounds newBounds = await mapController.getVisibleRegion();
      if (newBounds.contains(bounds.northeast) &&
          newBounds.contains(bounds.southwest)) {
        break;
      }
      zoomLevel -= 1.0;
      mapController.moveCamera(
        CameraUpdate.newLatLngZoom(center, zoomLevel),
      );
    }

    // Adjust the zoom level if needed to avoid excessive zooming
    if (zoomLevel < minZoomLevel) {
      zoomLevel = minZoomLevel;
    }

    // Move the camera to the adjusted position and zoom level
    mapController.moveCamera(
      CameraUpdate.newLatLngZoom(center, zoomLevel),
    );
  }

  LatLng latLngBoundCenter(LatLng northeast, LatLng southwest) {
    if ((southwest.longitude - northeast.longitude > 180) ||
        (northeast.longitude - southwest.longitude > 180)) {
      southwest = LatLng(southwest.latitude, southwest.longitude + 360);
      southwest = LatLng(southwest.latitude, southwest.longitude % 360);

      northeast = LatLng(northeast.latitude, northeast.longitude + 360);
      northeast = LatLng(northeast.latitude, northeast.longitude % 360);
    }

    return LatLng(
      (southwest.latitude + northeast.latitude) / 2,
      (southwest.longitude + northeast.longitude) / 2,
    );
  }

  LatLngBounds getClusterBounds(MapMarker cluster) {
    List<MapMarker> childrens = markerCluster.points(int.parse(cluster.id));
    double x0 = 0, x1 = 0, y0 = 0, y1 = 0;
    for (final marker in childrens) {
      final LatLng position = marker.position;
      if (x0 == 0) {
        x0 = x1 = position.latitude;
        y0 = y1 = position.longitude;
      } else {
        if (position.latitude > x1) {
          x1 = position.latitude;
        }
        if (position.latitude < x0) {
          x0 = position.latitude;
        }
        if (position.longitude > y1) {
          y1 = position.longitude;
        }
        if (position.longitude < y0) {
          y0 = position.longitude;
        }
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1, y1),
      southwest: LatLng(x0, y0),
    );
  }

  Future<double> calculateZoomLevel(
      LatLngBounds bounds, double desiredZoom) async {
    double zoom = 10.0;
    double maxZoom = 18.0; // Maximum zoom level for the map

    // Calculate the zoom level based on the bounds
    double boundsZoom = await mapController.getZoomLevel();

    // Use the smaller zoom level between desiredZoom and boundsZoom
    zoom = zoom < boundsZoom ? zoom : boundsZoom;

    // Ensure the zoom level is within the valid range
    zoom = zoom < 0 ? 0 : zoom;
    zoom = zoom > maxZoom ? maxZoom : zoom;

    return zoom;
  }
}
