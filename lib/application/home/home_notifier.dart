import 'dart:collection';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/models/data/order_detail.dart';
import 'package:driver/infrastructure/models/data/parcel_order.dart';
import 'package:driver/presentation/styles/style.dart';
import '../../infrastructure/services/services.dart';
import 'home_state.dart';

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());
  final ImageCropperMarker image = ImageCropperMarker();

  /// Threshold in meters — if driver is farther than this from the route,
  /// we consider them off-route and recalculate.
  static const double _offRouteThresholdMeters = 50.0;

  /// Minimum distance in meters from destination to stop rerouting.
  static const double _arrivedThresholdMeters = 50.0;

  /// Check if the driver is off the current route polyline.
  bool _isOffRoute(LatLng driverPosition) {
    final coords = state.polylineCoordinates;
    if (coords.isEmpty) return true; // No route = definitely need one

    double minDistance = double.infinity;
    for (final point in coords) {
      final d = _distanceMeters(driverPosition, point);
      if (d < minDistance) {
        minDistance = d;
        if (d < _offRouteThresholdMeters) return false; // Close enough
      }
    }
    return minDistance > _offRouteThresholdMeters;
  }

  /// Haversine distance in meters between two LatLng points.
  static double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLng = sin(dLng / 2);
    final h = sinLat * sinLat +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) * sinLng * sinLng;
    return 2 * R * asin(sqrt(h));
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Update the live route from the driver's current position to the destination.
  /// Detects off-route and recalculates. Called periodically while delivering.
  Future<void> updateLiveRoute({
    required LatLng driverPosition,
  }) async {
    final dest = state.destinationLatLng;
    final marker = state.destinationMarker;
    if (dest == null || marker == null) return;
    if (!state.isGoRestaurant && !state.isGoUser) return;
    if (!(await AppConnectivity.connectivity())) return;

    // Check if driver has arrived at destination
    final distToDest = _distanceMeters(driverPosition, dest);
    if (distToDest < _arrivedThresholdMeters) {
      // Close to destination - trim route to just show remaining
      state = state.copyWith(
        polylineCoordinates: [driverPosition, dest],
        markers: {marker},
      );
      return;
    }

    // Only recalculate if off-route or no route exists
    final offRoute = _isOffRoute(driverPosition);
    if (!offRoute && state.polylineCoordinates.isNotEmpty) {
      // On route - just trim the passed portion of the polyline
      final trimmed = _trimPolyline(driverPosition, state.polylineCoordinates);
      if (trimmed.isNotEmpty) {
        state = state.copyWith(
          polylineCoordinates: [driverPosition, ...trimmed],
          markers: {marker},
        );
      }
      return;
    }

    // Off-route or no route: fetch a new route from Google Directions
    debugPrint('==> Rerouting: driver is off-route or no route exists');
    final response = await drawRepository.getRouting(
      start: driverPosition,
      end: dest,
    );
    response.when(
      success: (data) {
        List<LatLng> list = [];
        List ls = data.features[0].geometry.coordinates;
        for (int i = 0; i < ls.length; i++) {
          list.add(LatLng(ls[i][1], ls[i][0]));
        }
        if (list.isNotEmpty) {
          state = state.copyWith(
            polylineCoordinates: list,
            markers: {marker},
          );
        }
      },
      failure: (failure, status) {
        debugPrint('==> reroute failure: $failure');
      },
    );
  }

  /// Trim the polyline by removing points the driver has already passed.
  List<LatLng> _trimPolyline(LatLng driverPos, List<LatLng> polyline) {
    if (polyline.isEmpty) return polyline;

    int closestIndex = 0;
    double closestDist = double.infinity;
    for (int i = 0; i < polyline.length; i++) {
      final d = _distanceMeters(driverPos, polyline[i]);
      if (d < closestDist) {
        closestDist = d;
        closestIndex = i;
      }
    }
    // Return from the closest point onwards
    return polyline.sublist(closestIndex);
  }

  fetchDeliveryZone({bool isFetch = false}) async {
    if (isFetch) {
      final response = await userRepository.getDeliveryZone();
      response.when(
        success: (data) {
          setDeliveryZone(data.data);
        },
        failure: (failure, status) {
          debugPrint('==> get delivery zone failure: $failure');
        },
      );
    } else {
      setDeliveryZone(LocalStorage.getUser()?.deliveryZone);
    }
  }

  setDeliveryZone(List<List<double>>? address) {
    if (address?.isNotEmpty ?? false) {
      final Set<Polygon> polygon = HashSet<Polygon>();
      final List<List<double>> addresses = address ?? [];
      List<LatLng> points = [];
      for (final address in addresses) {
        final latLng = LatLng(address[0], address[1]);
        points.add(latLng);
      }
      polygon.add(
        Polygon(
          polygonId: const PolygonId("zone"),
          points: points,
          fillColor: Style.primaryColor.withOpacity(0.01),
          strokeColor: Style.primaryColor,
          geodesic: false,
          strokeWidth: 8,
        ),
      );
      state = state.copyWith(
          polygon: polygon, isLoading: false, deliveryZone: points);
    }
  }

  void scrolling(bool scroll) {
    state = state.copyWith(isScrolling: scroll);
  }

  Future<void> getRoutingAll({
    required BuildContext context,
    required LatLng start,
    required LatLng end,
    required Marker market,
  }) async {
    if (await AppConnectivity.connectivity()) {
      debugPrint('==> getRoutingAll: start=${start.latitude},${start.longitude} end=${end.latitude},${end.longitude}');

      // Validate coordinates are not zero/default
      if (end.latitude == 0 && end.longitude == 0) {
        debugPrint('==> getRoutingAll: destination is 0,0 — skipping');
        return;
      }

      state = state.copyWith(
        polylineCoordinates: [],
        markers: {market},
        isLoading: true,
        destinationLatLng: end,
        destinationMarker: market,
      );
      final response = await drawRepository.getRouting(start: start, end: end);
      response.when(
        success: (data) {
          List<LatLng> list = [];
          List ls = data.features[0].geometry.coordinates;
          for (int i = 0; i < ls.length; i++) {
            list.add(LatLng(ls[i][1], ls[i][0]));
          }
          debugPrint('==> getRoutingAll: route has ${list.length} points');
          state = state.copyWith(
              polylineCoordinates: list, markers: {market}, isLoading: false);
        },
        failure: (failure, status) {
          debugPrint('==> getRoutingAll FAILED: $failure (status: $status)');
          // Still show the marker even if route fails
          state = state.copyWith(
              polylineCoordinates: [],
              markers: {market},
              isLoading: false);
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> getRouting(
      {required BuildContext context,
      required LatLng start,
      required bool isOnline}) async {
    if (await AppConnectivity.connectivity()) {
      state = state.copyWith(isLoading: state.isLoading);
      final response = await userRepository.setCurrentLocation(start);
      response.when(
        success: (data) {},
        failure: (failure, status) {
          if (status != 501) {
            AppHelpers.showCheckTopSnackBar(
              context,
              AppHelpers.getTranslation(failure),
            );
          }
        },
      );
    }
  }

  Future<void> goMarket(
      {required BuildContext context,
      String? orderId,
      OrderDetailData? order,
      bool setOrder = false,
      VoidCallback? onFailure,
      required VoidCallback onSuccess}) async {
    state = state.copyWith(isGoUser: false, isLoading: true);
    if (await AppConnectivity.connectivity()) {
      if (setOrder) {
        final response = await orderRepository.setOrder(orderId ?? "0");
        response.when(
          success: (data) {
            state = state.copyWith(
              isLoading: false,
              orderDetail: order,
              isGoRestaurant: true,
            );
            onSuccess();
          },
          failure: (failure, status) {
            state = state.copyWith(isLoading: false);
            onFailure?.call();
            AppHelpers.showCheckTopSnackBar(
              context,
              AppHelpers.getTranslation(failure),
            );
          },
        );
      } else {
        state = state.copyWith(
            isLoading: false, orderDetail: order, isGoRestaurant: true);
      }
    } else {
      state = state.copyWith(isLoading: false);
      onFailure?.call();
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> goMarketParcel(
      {required BuildContext context,
      String? parcelId,
      ParcelOrder? parcel,
      bool setOrder = false}) async {
    state =
        state.copyWith(isGoRestaurant: true, isGoUser: false, isLoading: true);
    if (await AppConnectivity.connectivity()) {
      if (setOrder) {
        final response = await parcelRepository.setParcel(parcelId ?? "0");
        response.when(
          success: (data) {
            state = state.copyWith(
              isLoading: false,
              parcelDetail: parcel,
            );
          },
          failure: (failure, status) {
            state = state.copyWith(isLoading: false);
            AppHelpers.showCheckTopSnackBar(
              context,
              AppHelpers.getTranslation(failure),
            );
          },
        );
      } else {
        state = state.copyWith(isLoading: false, parcelDetail: parcel);
      }
    } else {
      state = state.copyWith(isLoading: false);
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> fetchCurrentOrder(BuildContext context) async {
    fetchDeliveryZone();
    state = state.copyWith(
      isGoRestaurant: false,
      isGoUser: false,
    );
    if (await AppConnectivity.connectivity()) {
      final response = await orderRepository.fetchCurrentOrder();
      response.when(
        success: (data) async {
          if (data.data?.isNotEmpty ?? false) {
            state = state.copyWith(orderDetail: data.data?.first);
            if (data.data?.first.status == "on_a_way") {
              getRoutingAll(
                // ignore: use_build_context_synchronously
                context: context,
                start: LatLng(
                  LocalStorage.getAddressSelected()?.latitude ??
                      AppConstants.demoLatitude,
                  LocalStorage.getAddressSelected()?.longitude ??
                      AppConstants.demoLongitude,
                ),
                end: LatLng(
                  double.parse(data.data?.first.location?.latitude ?? "0"),
                  double.parse(data.data?.first.location?.longitude ?? "0"),
                ),
                market: Marker(
                  markerId: const MarkerId("User"),
                  position: LatLng(
                    double.parse(data.data?.first.location?.latitude ?? "0"),
                    double.parse(data.data?.first.location?.longitude ?? "0"),
                  ),
                  icon: await image.resizeAndCircle(
                      data.data?.first.user?.img ?? "", 100),
                ),
              );
              state = state.copyWith(
                  isGoRestaurant: false, isGoUser: true, isLoading: false);
            } else {
              state = state.copyWith(
                isGoRestaurant: true,
                isGoUser: false,
              );
              getRoutingAll(
                  // ignore: use_build_context_synchronously
                  context: context,
                  start: LatLng(
                      LocalStorage.getAddressSelected()?.latitude ??
                          AppConstants.demoLatitude,
                      LocalStorage.getAddressSelected()?.longitude ??
                          AppConstants.demoLongitude),
                  end: LatLng(
                    double.parse(
                        data.data?.first.shop?.location?.latitude ?? "0"),
                    double.parse(
                        data.data?.first.shop?.location?.longitude ?? "0"),
                  ),
                  market: Marker(
                      markerId: const MarkerId("Shop"),
                      position: LatLng(
                        double.parse(
                            data.data?.first.shop?.location?.latitude ?? "0"),
                        double.parse(
                            data.data?.first.shop?.location?.longitude ?? "0"),
                      ),
                      icon: await image.resizeAndCircle(
                          data.data?.first.shop?.logoImg ?? "", 120)));
            }
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(failure),
          );
        },
      );
    } else {
      state = state.copyWith(isLoading: false);
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> goClient(BuildContext context, int? orderId,
      {OrderDetailData? order}) async {
    state = state.copyWith(isGoUser: true, isGoRestaurant: false);
    if (await AppConnectivity.connectivity()) {
      if (order != null) {
        state = state.copyWith(orderDetail: order);
        return;
      }
      final response =
          await orderRepository.updateOrder(orderId ?? 0, "on_a_way");
      response.when(
        success: (data) {},
        failure: (failure, status) {
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(failure),
          );
        },
      );
      return;
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> goClientParcel(BuildContext context, int? parcelId,
      {ParcelOrder? parcel}) async {
    state = state.copyWith(isGoUser: true, isGoRestaurant: false);
    if (await AppConnectivity.connectivity()) {
      if (parcel != null) {
        state = state.copyWith(parcelDetail: parcel);
        return;
      }
      final response =
          await parcelRepository.updateParcel(parcelId ?? 0, "on_a_way");
      response.when(
        success: (data) {},
        failure: (failure, status) {
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(failure),
          );
        },
      );
      return;
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> addReview(
      {required BuildContext context,
      String? comment,
      double? rating,
      int? orderId}) async {
    if (await AppConnectivity.connectivity()) {
      orderRepository.addReview(orderId ?? 0,
          rating: rating ?? 0, comment: comment ?? "");
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> addReviewParcel(
      {required BuildContext context,
      String? comment,
      double? rating,
      int? parcelId}) async {
    if (await AppConnectivity.connectivity()) {
      parcelRepository.addReviewParcel(parcelId ?? 0,
          rating: rating ?? 0, comment: comment ?? "");
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> deliveredFinishParcel(
      {required BuildContext context, int? parcelId}) async {
    state = state.copyWith(
      isGoUser: false,
      isGoRestaurant: false,
      polylineCoordinates: [],
      endPolylineCoordinates: [],
      markers: {},
      destinationLatLng: null,
      destinationMarker: null,
    );
    if (await AppConnectivity.connectivity()) {
      parcelRepository.updateParcel(parcelId ?? 0, "delivered");
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<bool> deliveredFinish(
      {required BuildContext context, int? orderId, String? otp}) async {
    if (await AppConnectivity.connectivity()) {
      final response = await orderRepository.updateOrder(orderId ?? 0, "delivered", otp: otp);
      bool success = false;
      response.when(
        success: (data) {
          success = true;
          state = state.copyWith(
            isGoUser: false,
            isGoRestaurant: false,
            polylineCoordinates: [],
            endPolylineCoordinates: [],
            markers: {},
            destinationLatLng: null,
            destinationMarker: null,
          );
        },
        failure: (failure, status) {
          if (context.mounted) {
            AppHelpers.showCheckTopSnackBar(
              context,
              AppHelpers.getTranslation(failure),
            );
          }
        },
      );
      return success;
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
      return false;
    }
  }

  Future<void> cancelOrder(
      {required BuildContext context,
      required int orderId,
      required String note}) async {
    state = state.copyWith(isLoading: true);
    if (await AppConnectivity.connectivity()) {
      await orderRepository.cancelOrder(orderId, note);
      state = state.copyWith(
        isGoUser: false,
        isGoRestaurant: false,
        polylineCoordinates: [],
        endPolylineCoordinates: [],
        markers: {},
        destinationLatLng: null,
        destinationMarker: null,
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> uploadImage({
    required BuildContext context,
    required int? orderId,
    required String path,
  }) async {
    final res = await settingsRepository.uploadImage(path, UploadType.products);
    res.when(success: (success) {
      orderRepository.uploadImage(orderId, success.imageData?.title);
    }, failure: (failure, status) {
      AppHelpers.showCheckTopSnackBar(context, failure);
    });
  }

  Future<void> setOnline({
    required BuildContext context,
  }) async {
    if (await AppConnectivity.connectivity()) {
      final response = await userRepository.setOnline();
      response.when(
        success: (data) {
          LocalStorage.setOnline(!LocalStorage.getOnline());
        },
        failure: (failure, status) {
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(failure),
          );
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }
}
