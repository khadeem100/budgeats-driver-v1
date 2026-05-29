import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:driver/domain/handlers/handlers.dart';
import 'package:driver/domain/interface/interfaces.dart';
import '../models/models.dart';
import '../models/response/draw_routing_response.dart' as routing;
import '../services/services.dart';

class DrawRepositoryImpl implements DrawRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://maps.googleapis.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  Future<ApiResult<DrawRouting>> getRouting({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final response = await _dio.get(
        '/maps/api/directions/json',
        queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'mode': 'driving',
          'key': AppConstants.googleApiKey,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK' || (data['routes'] as List).isEmpty) {
        debugPrint('==> Google Directions API status: $status');
        return ApiResult.failure(
          error: 'Directions API returned: $status',
          statusCode: 0,
        );
      }

      // Decode the overview polyline into coordinate pairs
      final overviewPolyline =
          data['routes'][0]['overview_polyline']['points'] as String;
      final List<List<double>> coordinates = _decodePolyline(overviewPolyline);

      // Build a DrawRouting object compatible with existing code
      final drawRouting = DrawRouting(
        type: 'FeatureCollection',
        features: [
          Feature(
            bbox: [0, 0, 0, 0],
            type: 'Feature',
            properties: Properties(
              segments: [],
              summary: routing.Summary(distance: 0, duration: 0),
              wayPoints: [0, coordinates.length - 1],
            ),
            geometry: Geometry(
              coordinates: coordinates,
              type: 'LineString',
            ),
          ),
        ],
        bbox: [0, 0, 0, 0],
        metadata: Metadata(
          attribution: 'Google Maps',
          service: 'directions',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          query: Query(
            coordinates: [[start.longitude, start.latitude], [end.longitude, end.latitude]],
            profile: 'driving',
            format: 'json',
          ),
          engine: Engine(
            version: '1',
            buildDate: DateTime.now(),
            graphDate: DateTime.now(),
          ),
        ),
      );

      return ApiResult.success(data: drawRouting);
    } catch (e) {
      debugPrint('==> Google Directions error: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  /// Decodes an encoded polyline string into a list of [lng, lat] pairs
  /// (matching the ORS format the existing code expects).
  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Store as [longitude, latitude] to match ORS format
      points.add([lng / 1E5, lat / 1E5]);
    }

    return points;
  }
}
