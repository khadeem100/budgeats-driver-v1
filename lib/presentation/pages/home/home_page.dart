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
import 'package:driver/presentation/component/platform_map_widget.dart';
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
import 'package:driver/presentation/pages/push_order/push_order_slider.dart';

@RoutePage()
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final bool isLtr = LocalStorage.getLangLtr();
  PlatformMapController? mapController;
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
  bool _checkedInitialAvailableOrders = false;

  /// Pending push orders shown in the slider popup.
  final ValueNotifier<List<OrderDetailData>> _pendingPushOrders = ValueNotifier([]);
  bool _pushPopupShowing = false;

  Future<void> setCustomMarkerIcon() async {
    final Uint8List markerMyIcon =
        await AppHelpers.getBytesFromAsset(AppAssets.pngMyLocation, 120);
    myIcon = BitmapDescriptor.bytes(markerMyIcon);
  }

  checkPermission() async {
    FirebaseMessaging.instance.requestPermission(
      sound: true,
      alert: true,
      badge: false,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _openOrderFromMessage(initialMessage);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("New notification on message: ${jsonEncode(message.data)}");
      if (message.data["id"] != null && mounted) {
        AppHelpers.showCheckTopSnackBarInfo(
          context,
          "${message.notification?.body}",
        );
      }
      if (message.data["type"] == "new_order" || message.data["type"] == "deliveryman") {
        await _openOrderFromMessage(message);
      } else if (message.data["type"] == "status_changed") {
        // Withdrawal status changed — refresh balance and profile
        ref.read(financesProvider.notifier).fetchBalance();
        ref.read(financesProvider.notifier).fetchHistory();
        ref.read(profileSettingsProvider.notifier).fetchProfileDetails(context: context);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint("New notification oped app: ${jsonEncode(message.data)}");

      if (message.data["type"] == "new_order" || message.data["type"] == "deliveryman") {
        await _openOrderFromMessage(message);
      } else if (message.data["type"] == "status_changed") {
        // Withdrawal status changed — refresh balance and profile
        ref.read(financesProvider.notifier).fetchBalance();
        ref.read(financesProvider.notifier).fetchHistory();
        ref.read(profileSettingsProvider.notifier).fetchProfileDetails(context: context);
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
        mapController?.animateCamera(
          PlatformCameraUpdate.newLatLngZoom(
            latitude: latLng.latitude, longitude: latLng.longitude, zoomLevel: 15,
          ),
        );
      }
    } else {
      if (check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        mapController?.animateCamera(
          PlatformCameraUpdate.newLatLngZoom(
            latitude: latLng.latitude, longitude: latLng.longitude, zoomLevel: 15,
          ),
        );
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
        mapController?.animateCamera(
          PlatformCameraUpdate.newLatLngZoom(
            latitude: latLng.latitude, longitude: latLng.longitude, zoomLevel: 15,
          ),
        );
      }
    } else {
      if (check != LocationPermission.deniedForever) {
        var loc = await Geolocator.getCurrentPosition();
        latLng = LatLng(loc.latitude, loc.longitude);
        LocalStorage.setAddressSelected(latLng);
        mapController?.animateCamera(
          PlatformCameraUpdate.newLatLngZoom(
            latitude: latLng.latitude, longitude: latLng.longitude, zoomLevel: 15,
          ),
        );
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
    // Live route update every 10 seconds when there's an active delivery
    routeUpdateTimer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
      final state = ref.read(homeProvider);
      if (state.isGoRestaurant || state.isGoUser) {
        ref.read(homeProvider.notifier).updateLiveRoute(
              driverPosition: latLng,
            );
        // Follow driver position on the map during active delivery
        mapController?.animateCamera(
          PlatformCameraUpdate.newCameraPosition(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            zoomLevel: 16,
            tiltValue: 45,
            bearingValue: currentLocation?.heading ?? 0,
          ),
        );
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
    if (push == null) return;
    newOrder(push);
  }

  Future<void> newOrder(OrderDetailData? push) async {
    if (push == null || push.id == null) return;
    // Don't show new orders while driver is on an active delivery
    final homeState = ref.read(homeProvider);
    if (homeState.isGoRestaurant || homeState.isGoUser) return;

    // Add to pending list if not already there
    final currentList = _pendingPushOrders.value;
    if (currentList.any((o) => o.id == push.id)) return;

    _pendingPushOrders.value = [...currentList, push];

    // Show slider popup if not already showing
    if (!_pushPopupShowing) {
      _showPushSliderPopup();
    }
  }

  void _showPushSliderPopup() {
    if (!mounted || _pushPopupShowing) return;

    _pushPopupShowing = true;

    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Style.transparent,
        insetPadding: EdgeInsets.all(16.r),
        child: PushOrderSlider(
          pendingOrders: _pendingPushOrders,
          driverLocation: latLng,
          onClose: () {
            if (mounted && _pushPopupShowing) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    ).then((_) {
      _pushPopupShowing = false;
    });
  }

  Future<void> _openOrderFromMessage(RemoteMessage message) async {
    final orderId = int.tryParse(message.data['id']?.toString() ?? '');
    if (orderId == null) {
      return;
    }

    final res = await orderRepository.showOrders(orderId);
    res.map(
      success: (s) {
        final order = s.data.data;
        newOrder(order);
      },
      failure: (f) {},
    );
  }

  Future<void> _showInitialAvailableOrderIfNeeded() async {
    if (_checkedInitialAvailableOrders || !mounted) {
      return;
    }

    _checkedInitialAvailableOrders = true;

    if (!LocalStorage.getOnline()) {
      return;
    }

    final homeState = ref.read(homeProvider);
    if (homeState.isGoRestaurant || homeState.isGoUser) {
      return;
    }

    final response = await orderRepository.getAvailableOrders(1);
    response.when(
      success: (data) {
        ref.read(orderProvider.notifier).setAvailableOrders(data);
        // Show all available orders in the slider
        for (final order in data) {
          newOrder(order);
        }
      },
      failure: (_, __) {},
    );
  }

  @override
  void initState() {
    checkPermission();
    setCustomMarkerIcon();
    getMyLocation();
    // Initialize FCM: register token + listen for refreshes on every app start
    FcmService().initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(profileSettingsProvider.notifier)
          .fetchProfileStatistics(context: context);
      ref
          .read(profileSettingsProvider.notifier)
          .fetchRequestResponse(context: context);
      ref.read(homeProvider.notifier).fetchCurrentOrder(context);
      ref.read(orderProvider.notifier)
        ..fetchActiveOrders(context)
        ..fetchAvailableOrders(context);
      Future.delayed(const Duration(milliseconds: 800), _showInitialAvailableOrderIfNeeded);
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
    _pendingPushOrders.dispose();
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for route changes to auto-fit the map camera
    ref.listen<List<LatLng>>(
      homeProvider.select((s) => s.polylineCoordinates),
      (previous, next) {
        if (next.isNotEmpty && (previous == null || previous.isEmpty)) {
          // Route just appeared — zoom to fit
          Future.delayed(const Duration(milliseconds: 300), _fitMapToRoute);
        }
      },
    );
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
      child: PlatformMapWidget(
        initialLat: LocalStorage.getAddressSelected()?.latitude ??
            AppConstants.demoLatitude,
        initialLng: LocalStorage.getAddressSelected()?.longitude ??
            AppConstants.demoLongitude,
        zoom: 17,
        tilt: isDeliveryActive ? 45 : 0,
        bearing: 0,
        myLocationEnabled: isDeliveryActive,
        compassEnabled: isDeliveryActive,
        zoomControlsEnabled: false,
        googleMarkers: {
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
        googlePolygons: homeState.polygon,
        googlePolylines: isDeliveryActive
            ? {
                if (homeState.endPolylineCoordinates.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId("startLocation"),
                    points: homeState.endPolylineCoordinates,
                    color: _deliveryGreen.withValues(alpha: 0.3),
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
        onMapCreated: (controller) {
          mapController = controller;
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
    if (mapController == null) return;
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
    mapController!.animateCamera(
      PlatformCameraUpdate.newLatLngBounds(
        southwestLat: minLat,
        southwestLng: minLng,
        northeastLat: maxLat,
        northeastLng: maxLng,
        padding: 80,
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
          color: Style.white.withValues(alpha: 0.3),
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
