import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMarker extends Marker {
  final String id;
  @override
  final LatLng position;

  CustomMarker({
    required this.id,
    required this.position,
    // ... other Marker parameters
  }) : super(
          markerId: MarkerId(id),
          position: position,
        );
}
