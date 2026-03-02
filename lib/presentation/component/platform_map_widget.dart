import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;

/// Thuisbezorgd-style green color for delivery waypoints.
const Color deliveryGreen = Color(0xFF00C853);

// ---------------------------------------------------------------------------
// Unified map controller that wraps Google Maps / Apple Maps controllers
// ---------------------------------------------------------------------------

/// Platform-agnostic camera update descriptor.
class PlatformCameraUpdate {
  final double? lat;
  final double? lng;
  final double? zoom;
  final double? tilt;
  final double? bearing;

  // For bounds-based updates
  final double? swLat;
  final double? swLng;
  final double? neLat;
  final double? neLng;
  final double? boundsPadding;

  const PlatformCameraUpdate.newLatLngZoom({
    required double latitude,
    required double longitude,
    required double zoomLevel,
  })  : lat = latitude,
        lng = longitude,
        zoom = zoomLevel,
        tilt = null,
        bearing = null,
        swLat = null,
        swLng = null,
        neLat = null,
        neLng = null,
        boundsPadding = null;

  const PlatformCameraUpdate.newCameraPosition({
    required double latitude,
    required double longitude,
    required double zoomLevel,
    required double tiltValue,
    required double bearingValue,
  })  : lat = latitude,
        lng = longitude,
        zoom = zoomLevel,
        tilt = tiltValue,
        bearing = bearingValue,
        swLat = null,
        swLng = null,
        neLat = null,
        neLng = null,
        boundsPadding = null;

  const PlatformCameraUpdate.newLatLngBounds({
    required double southwestLat,
    required double southwestLng,
    required double northeastLat,
    required double northeastLng,
    required double padding,
  })  : swLat = southwestLat,
        swLng = southwestLng,
        neLat = northeastLat,
        neLng = northeastLng,
        boundsPadding = padding,
        lat = null,
        lng = null,
        zoom = null,
        tilt = null,
        bearing = null;

  bool get _isBounds => swLat != null;
}

/// Wraps either a [gm.GoogleMapController] or an [am.AppleMapController]
/// and exposes a unified `animateCamera` / `dispose` interface.
class PlatformMapController {
  gm.GoogleMapController? _google;
  am.AppleMapController? _apple;

  void setGoogle(gm.GoogleMapController c) => _google = c;
  void setApple(am.AppleMapController c) => _apple = c;

  /// Access the underlying Google controller (needed for legacy code paths).
  gm.GoogleMapController? get google => _google;

  Future<void> animateCamera(PlatformCameraUpdate update) async {
    if (_google != null) {
      if (update._isBounds) {
        await _google!.animateCamera(
          gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(
              southwest: gm.LatLng(update.swLat!, update.swLng!),
              northeast: gm.LatLng(update.neLat!, update.neLng!),
            ),
            update.boundsPadding!,
          ),
        );
      } else if (update.tilt != null) {
        await _google!.animateCamera(
          gm.CameraUpdate.newCameraPosition(
            gm.CameraPosition(
              target: gm.LatLng(update.lat!, update.lng!),
              zoom: update.zoom!,
              tilt: update.tilt!,
              bearing: update.bearing ?? 0,
            ),
          ),
        );
      } else {
        await _google!.animateCamera(
          gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(update.lat!, update.lng!),
            update.zoom!,
          ),
        );
      }
    }

    if (_apple != null) {
      if (update._isBounds) {
        await _apple!.moveCamera(
          am.CameraUpdate.newLatLngBounds(
            am.LatLngBounds(
              southwest: am.LatLng(update.swLat!, update.swLng!),
              northeast: am.LatLng(update.neLat!, update.neLng!),
            ),
            update.boundsPadding!,
          ),
        );
      } else if (update.tilt != null) {
        await _apple!.moveCamera(
          am.CameraUpdate.newCameraPosition(
            am.CameraPosition(
              target: am.LatLng(update.lat!, update.lng!),
              zoom: update.zoom!,
            ),
          ),
        );
      } else {
        await _apple!.moveCamera(
          am.CameraUpdate.newLatLngZoom(
            am.LatLng(update.lat!, update.lng!),
            update.zoom!,
          ),
        );
      }
    }
  }

  void dispose() {
    _google?.dispose();
    _google = null;
    _apple = null;
  }
}

// ---------------------------------------------------------------------------
// Platform-adaptive map widget
// ---------------------------------------------------------------------------

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
  final void Function(PlatformMapController controller)? onMapCreated;
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
    this.onMapCreated,
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
      onMapCreated: (controller) {
        final c = PlatformMapController()..setGoogle(controller);
        onMapCreated?.call(c);
      },
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraIdle: onCameraIdle,
    );
  }

  Widget _buildAppleMap() {
    // Convert Google Maps markers to Apple Maps annotations
    final Set<am.Annotation> annotations = googleMarkers.map((marker) {
      return am.Annotation(
        annotationId: am.AnnotationId(marker.markerId.value),
        position:
            am.LatLng(marker.position.latitude, marker.position.longitude),
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
      onMapCreated: (controller) {
        final c = PlatformMapController()..setApple(controller);
        onMapCreated?.call(c);
      },
    );
  }
}
