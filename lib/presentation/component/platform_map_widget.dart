import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;

/// Thuisbezorgd-style green color for delivery waypoints.
const Color deliveryGreen = Color(0xFF00C853);

/// A platform-adaptive map widget that uses Apple Maps on iOS
/// and Google Maps on Android, similar to Thuisbezorgd.
///
/// This keeps all navigation in-app — the driver never needs
/// to leave the app to see directions.
class PlatformMapWidget extends StatelessWidget {
  final double initialLat;
  final double initialLng;
  final double zoom;
  final double tilt;
  final double bearing;
  final bool myLocationEnabled;
  final bool compassEnabled;
  final bool zoomControlsEnabled;
  final Set<gm.Marker> googleMarkers;
  final Set<gm.Polyline> googlePolylines;
  final Set<gm.Polygon> googlePolygons;
  final void Function(gm.GoogleMapController)? onGoogleMapCreated;
  final EdgeInsets padding;
  final VoidCallback? onCameraMoveStarted;
  final VoidCallback? onCameraIdle;

  const PlatformMapWidget({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.zoom = 17,
    this.tilt = 0,
    this.bearing = 0,
    this.myLocationEnabled = false,
    this.compassEnabled = false,
    this.zoomControlsEnabled = false,
    this.googleMarkers = const {},
    this.googlePolylines = const {},
    this.googlePolygons = const {},
    this.onGoogleMapCreated,
    this.padding = EdgeInsets.zero,
    this.onCameraMoveStarted,
    this.onCameraIdle,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildAppleMap();
    }
    return _buildGoogleMap();
  }

  Widget _buildGoogleMap() {
    return gm.GoogleMap(
      myLocationButtonEnabled: false,
      myLocationEnabled: myLocationEnabled,
      compassEnabled: compassEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      mapToolbarEnabled: false,
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(initialLat, initialLng),
        zoom: zoom,
        tilt: tilt,
        bearing: bearing,
      ),
      markers: googleMarkers,
      polylines: googlePolylines,
      polygons: googlePolygons,
      padding: padding,
      onMapCreated: onGoogleMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraIdle: onCameraIdle,
    );
  }

  Widget _buildAppleMap() {
    // Convert Google Maps markers to Apple Maps annotations
    final Set<am.Annotation> annotations = googleMarkers.map((marker) {
      return am.Annotation(
        annotationId: am.AnnotationId(marker.markerId.value),
        position: am.LatLng(marker.position.latitude, marker.position.longitude),
        infoWindow: marker.infoWindow.title != null
            ? am.InfoWindow(
                title: marker.infoWindow.title,
                snippet: marker.infoWindow.snippet,
              )
            : am.InfoWindow.noText,
      );
    }).toSet();

    // Convert Google Maps polylines to Apple Maps polylines
    final Set<am.Polyline> applePolylines = googlePolylines.map((polyline) {
      return am.Polyline(
        polylineId: am.PolylineId(polyline.polylineId.value),
        points: polyline.points
            .map((p) => am.LatLng(p.latitude, p.longitude))
            .toList(),
        color: polyline.color,
        width: polyline.width,
      );
    }).toSet();

    // Convert Google Maps polygons to Apple Maps polygons
    final Set<am.Polygon> applePolygons = googlePolygons.map((polygon) {
      return am.Polygon(
        polygonId: am.PolygonId(polygon.polygonId.value),
        points: polygon.points
            .map((p) => am.LatLng(p.latitude, p.longitude))
            .toList(),
        fillColor: polygon.fillColor,
        strokeColor: polygon.strokeColor,
        strokeWidth: polygon.strokeWidth,
      );
    }).toSet();

    return am.AppleMap(
      initialCameraPosition: am.CameraPosition(
        target: am.LatLng(initialLat, initialLng),
        zoom: zoom,
      ),
      annotations: annotations,
      polylines: applePolylines,
      polygons: applePolygons,
      myLocationEnabled: myLocationEnabled,
      compassEnabled: compassEnabled,
      myLocationButtonEnabled: false,
      padding: padding,
      mapType: am.MapType.standard,
      trackingMode: myLocationEnabled
          ? am.TrackingMode.followWithHeading
          : am.TrackingMode.none,
    );
  }
}
