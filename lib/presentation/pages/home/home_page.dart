import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver/application/order/order_provider.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/models/data/order_detail.dart';
import 'package:driver/presentation/component/loading.dart';
import 'package:driver/presentation/pages/home/parcel_bottom_sheet.dart';
import 'package:driver/presentation/pages/pages.dart';
import 'package:workmanager/workmanager.dart';
import 'package:driver/application/providers.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/main.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/routes/app_router.gr.dart';
import 'package:driver/presentation/styles/style.dart';
import 'bottom_sheet_screen.dart';
import 'delivery_bottom_sheet.dart';

@RoutePage()
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final bool isLtr = LocalStorage.getLangLtr();
  GoogleMapController? googleMapController;
  BitmapDescriptor myIcon = BitmapDescriptor.defaultMarker;
  OrderDetailData? push;
  Timer? timer;
  Timer? routeUpdateTimer;
  LatLng latLng = LatLng(
    (LocalStorage.getAddressSelected()?.latitude ?? AppConstants.demoLatitude),
    (LocalStorage.getAddressSelected()?.longitude ??
        AppConstants.demoLongitude),
  );
  Position? currentLocation;
  dynamic check;
  final _delayed = Delayed(milliseconds: 36000);
  StreamSubscription<Position>? _positionSubscription;

  Future<void> setCustomMarkerIcon() async {
    final Uint8List markerMyIcon =
        await AppHelpers.getBytesFromAsset(AppAssets.pngMyLocation, 120);
    myIcon = BitmapDescriptor.fromBytes(markerMyIcon);
  }

  checkPermission() async {
    FirebaseMessaging.instance.requestPermission(
      sound: true,
      alert: true,
      badge: false,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("New notification on message: ${jsonEncode(message.data)}");
      if (message.data["id"] != null && mounted) {
        AppHelpers.showCheckTopSnackBarInfo(
          context,
          "${message.notification?.body}",
        );
      }
      if (message.data["type"] == "new_order") {
        final res = await orderRepository
            .showOrders(int.tryParse(message.data["id"].toString()) ?? 0);
        res.map(
            success: (s) {
              attachOrder(s.data.data);
            },
            failure: (f) {});
      } else if (message.data["type"] == "deliveryman") {
        final res = await orderRepository
            .showOrders(int.tryParse(message.data["id"].toString()) ?? 0);
        res.map(
            success: (s) {
              newOrder(s.data.data);
            },
            failure: (f) {});
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint("New notification oped app: ${jsonEncode(message.data)}");

      if (message.data["type"] == "new_order") {
        final res = await orderRepository
            .showOrders(int.tryParse(message.data["id"].toString()) ?? 0);
        res.map(
            success: (s) {
              attachOrder(s.data.data);
            },
            failure: (f) {});
      } else if (message.data["type"] == "deliveryman") {
        final res = await orderRepository
            .showOrders(int.tryParse(message.data["id"].toString()) ?? 0);
        res.map(
            success: (s) {
              newOrder(s.data.data);
            },
            failure: (f) {});
      }
    });

    check = await _geolocatorPlatform.checkPermission();
    if (check == LocationPermission.denied) {
      check = await Geolocator.requestPermission();
      if (check != LocationPermission.denied &&
          check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        googleMapController!
            .animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    } else {
      if (check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        googleMapController!
            .animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    }
  }

  Future<void> getMyLocation() async {
    if (check == LocationPermission.denied) {
      check = await Geolocator.requestPermission();
      if (check != LocationPermission.denied &&
          check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        googleMapController!
            .animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    } else {
      if (check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        googleMapController!
            .animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    }
  }

  void getSetProgressLocation() {
    timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
      ref.read(homeProvider.notifier).getRouting(
            context: context,
            start: latLng,
            isOnline: (LocalStorage.getOnline()),
          );
    });
    // Live route update every 15 seconds when there's an active delivery
    routeUpdateTimer = Timer.periodic(const Duration(seconds: 15), (Timer t) {
      final state = ref.read(homeProvider);
      if (state.isGoRestaurant || state.isGoUser) {
        ref.read(homeProvider.notifier).updateLiveRoute(
              driverPosition: latLng,
            );
        // Follow driver position on the map during active delivery
        if (googleMapController != null) {
          googleMapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16, tilt: 45, bearing: currentLocation?.heading ?? 0),
            ),
          );
        }
      }
    });
  }

  void getCurrentLocation() async {
    getSetProgressLocation();
    _geolocatorPlatform.getCurrentPosition().then(
      (location) {
        currentLocation = location;
        latLng = LatLng(currentLocation?.latitude ?? latLng.latitude,
            currentLocation?.longitude ?? latLng.longitude);
      },
    );
    _positionSubscription = _geolocatorPlatform.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(
      (newLoc) {
        currentLocation = newLoc;
        latLng = LatLng(currentLocation?.latitude ?? latLng.latitude,
            currentLocation?.longitude ?? latLng.longitude);
        _delayed.run(() {
          LocalStorage.setAddressSelected(LatLng(
              currentLocation?.latitude ?? latLng.latitude,
              currentLocation?.longitude ?? latLng.longitude));
        });
        // Update driver marker position in real-time during delivery
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> attachOrder(OrderDetailData? push) async {
    AppHelpers.showAlertDialog(
      context: context,
      child: PushOrder(
        pushModel: push ?? OrderDetailData(),
        isActive: false,
      ),
    );
    final ImageCropperMarker image = ImageCropperMarker();
    ref.read(homeProvider.notifier).goMarket(
        context: context,
        orderId: (push?.id ?? 0).toString(),
        order: push,
        onSuccess: () async {
          ref.read(homeProvider.notifier).getRoutingAll(
                // ignore: use_build_context_synchronously
                context: context,
                start: LatLng(
                    LocalStorage.getAddressSelected()?.latitude ??
                        AppConstants.demoLatitude,
                    LocalStorage.getAddressSelected()?.longitude ??
                        AppConstants.demoLongitude),
                end: LatLng(
                  double.parse(push?.shop?.location?.latitude ?? "0"),
                  double.parse(push?.shop?.location?.longitude ?? "0"),
                ),
                market: Marker(
                  markerId: const MarkerId("Shop"),
                  position: LatLng(
                    double.parse(push?.shop?.location?.latitude ?? "0"),
                    double.parse(push?.shop?.location?.longitude ?? "0"),
                  ),
                  icon: await image.resizeAndCircle(
                      push?.shop?.logoImg ?? "", 120),
                  infoWindow: InfoWindow(
                    title: push?.shop?.translation?.title ?? "Restaurant",
                  ),
                ),
              );
          // Zoom camera to show both driver and destination
          _fitMapToRoute();
        });
  }

  Future<void> newOrder(OrderDetailData? push) async {
    AppHelpers.showAlertDialog(
      context: context,
      child: PushOrder(
        pushModel: push ?? OrderDetailData(),
        isActive: true,
      ),
    );
  }

  @override
  void initState() {
    checkPermission();
    setCustomMarkerIcon();
    getMyLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(profileSettingsProvider.notifier)
          .fetchProfileStatistics(context: context);
      ref
          .read(profileSettingsProvider.notifier)
          .fetchRequestResponse(context: context);
      ref.read(homeProvider.notifier).fetchCurrentOrder(context);
      ref.read(orderProvider.notifier).fetchActiveOrders(context);
    });
    if (LocalStorage.getOnline()) {
      Workmanager().registerPeriodicTask(
        "${DateTime.now().year}${DateTime.now().day}${DateTime.now().minute}${DateTime.now().second}",
        fetchBackground,
        frequency: const Duration(minutes: 10),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getCurrentLocation();
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    routeUpdateTimer?.cancel();
    _positionSubscription?.cancel();
    googleMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(homeProvider);
            return Stack(
              children: [
                _map(context, ref),
                state.isGoRestaurant || state.isGoUser
                    ? state.parcelDetail == null
                        ? DeliverBottomSheetScreen(
                            order: push ??
                                (state.orderDetail ?? OrderDetailData()),
                          )
                        : ParcelBottomSheetScreen(parcel: state.parcelDetail)
                    : BottomSheetScreen(
                        isScrolling: state.isScrolling,
                      ),
                state.isGoRestaurant || state.isGoUser
                    ? const SizedBox.shrink()
                    : _myFindButton(ref),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  top: MediaQuery.paddingOf(context).top + 10.h,
                  left: state.isScrolling ? -64.w : 16.w,
                  child: ButtonsBouncingEffect(
                    child: GestureDetector(
                      onTap: () => context.pushRoute(const ProfileRoute()),
                      child: Hero(
                        tag: AppConstants.heroTagProfileAvatar,
                        child: Consumer(
                          builder: (context, ref, child) {
                            ref.watch(profileImageProvider);
                            return DriverAvatar(
                              imageUrl: LocalStorage.getUser()?.img,
                              rate: LocalStorage.getUser()?.rate,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  top: MediaQuery.paddingOf(context).top + 80.h,
                  left: state.isScrolling ? -64.w : 12.w,
                  child: ButtonsBouncingEffect(
                    child: Consumer(
                      builder: (context, ref, child) {
                        ref.watch(profileImageProvider);
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Style.primaryColor,
                                  borderRadius: BorderRadius.circular(16.r)),
                              margin: EdgeInsets.all(8.r),
                              child: IconButton(
                                  onPressed: () =>
                                      context.pushRoute(const OrdersRoute()),
                                  icon: const Icon(
                                    FlutterRemix.history_fill,
                                    color: Style.white,
                                  )),
                            ),
                            Positioned(
                                top: 2.r,
                                right: 8.r,
                                child: Text(
                                  ref
                                      .watch(orderProvider)
                                      .totalActiveOrder
                                      .toString(),
                                  style: Style.interBold(
                                      color: Style.black, size: 18),
                                ))
                          ],
                        );
                      },
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  top: MediaQuery.paddingOf(context).top + 10.h,
                  right: state.isScrolling ? -120.w : 16.w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Style.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.all(6.r),
                    child: CustomToggle(
                      isOnline: (LocalStorage.getOnline()),
                      onChange: (bool value) {
                        if (value) {
                          Workmanager().registerPeriodicTask(
                            "${DateTime.now().year}${DateTime.now().day}${DateTime.now().minute}${DateTime.now().second}",
                            fetchBackground,
                            frequency: const Duration(minutes: 10),
                          );
                          getCurrentLocation();
                        } else {
                          timer?.cancel();
                          routeUpdateTimer?.cancel();
                          _positionSubscription?.cancel();
                          Workmanager().cancelAll();
                        }
                        ref
                            .read(homeProvider.notifier)
                            .setOnline(context: context);
                      },
                    ),
                  ),
                ),
                if (state.isLoading)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    child: _customLoading(context),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Thuisbezorgd-style green color for delivery waypoints
  static const Color _deliveryGreen = Color(0xFF00C853);

  Widget _map(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final isDeliveryActive = homeState.isGoRestaurant || homeState.isGoUser;
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      child: GoogleMap(
        myLocationButtonEnabled: false,
        myLocationEnabled: isDeliveryActive,
        initialCameraPosition: CameraPosition(
          bearing: 0,
          target: LatLng(
            (LocalStorage.getAddressSelected()?.latitude ??
                AppConstants.demoLatitude),
            (LocalStorage.getAddressSelected()?.longitude ??
                AppConstants.demoLongitude),
          ),
          tilt: isDeliveryActive ? 45 : 0,
          zoom: 17,
        ),
        markers: {
          Marker(
            markerId: const MarkerId("source"),
            icon: myIcon,
            position: LatLng(currentLocation?.latitude ?? latLng.latitude,
                currentLocation?.longitude ?? latLng.longitude),
            rotation: currentLocation?.heading ?? 0,
            anchor: const Offset(0.5, 0.5),
            flat: true,
          ),
          ...homeState.markers
        },
        polygons: homeState.polygon,
        polylines: isDeliveryActive
            ? {
                if (homeState.endPolylineCoordinates.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId("startLocation"),
                    points: homeState.endPolylineCoordinates,
                    color: _deliveryGreen.withOpacity(0.3),
                    width: 6,
                  ),
                if (homeState.polylineCoordinates.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId("market"),
                    points: homeState.polylineCoordinates,
                    color: _deliveryGreen,
                    width: 6,
                    patterns: [PatternItem.dot, PatternItem.gap(10)],
                  ),
              }
            : {},
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: isDeliveryActive,
        onMapCreated: (controller) {
          googleMapController = controller;
        },
        onCameraMoveStarted: () {
          if (!(LocalStorage.getUser()?.active ?? false)) {
            ref.read(homeProvider.notifier).scrolling(true);
          }
        },
        onCameraIdle: () {
          _delayed.run(() {
            ref.read(homeProvider.notifier).scrolling(false);
          });
        },
        padding: EdgeInsets.only(
          bottom: homeState.isGoRestaurant
              ? 90.h
              : homeState.isScrolling
                  ? 60.h
                  : 330.h,
        ),
      ),
    );
  }

  /// Fit the map camera to show both the driver and destination markers
  void _fitMapToRoute() {
    if (googleMapController == null) return;
    final state = ref.read(homeProvider);
    final coords = [
      LatLng(currentLocation?.latitude ?? latLng.latitude,
          currentLocation?.longitude ?? latLng.longitude),
      ...state.markers.map((m) => m.position),
    ];
    if (coords.length < 2) return;
    double minLat = coords.map((e) => e.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = coords.map((e) => e.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = coords.map((e) => e.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = coords.map((e) => e.longitude).reduce((a, b) => a > b ? a : b);
    googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Widget _customLoading(BuildContext context) {
    return BlurWrap(
      radius: BorderRadius.zero,
      blur: 1,
      child: Container(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          color: Style.white.withOpacity(0.3),
          child: const Loading()),
    );
  }

  Widget _myFindButton(WidgetRef ref) {
    return AnimatedPositioned(
      bottom: 342.h,
      right: ref.watch(homeProvider).isScrolling ? -64.w : 16.w,
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () async => await getMyLocation(),
        child: Container(
          width: 50.r,
          height: 50.r,
          decoration: BoxDecoration(
            color: Style.white,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const [
              BoxShadow(
                color: Style.shadowColor,
                blurRadius: 2,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: const Icon(FlutterRemix.focus_3_fill),
        ),
      ),
    );
  }
}
