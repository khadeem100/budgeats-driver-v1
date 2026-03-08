import 'package:get_it/get_it.dart';
import 'package:driver/domain/interface/notification.dart';
import 'package:driver/domain/interface/parcel.dart';
import 'package:driver/domain/interface/free_lunch.dart';
import 'package:driver/infrastructure/repositories/notification_repository.dart';
import 'package:driver/infrastructure/repositories/parcel_repository.dart';
import 'package:driver/infrastructure/repositories/free_lunch_repository.dart';

import '../../infrastructure/repositories/orders_repository.dart';
import '../../infrastructure/repositories/repositories.dart';
import '../../presentation/routes/app_router.dart';
import '../handlers/handlers.dart';
import '../interface/interfaces.dart';
import '../interface/orders.dart';

final GetIt getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  getIt.registerSingleton<HttpService>(HttpService());
  getIt.registerSingleton<SettingsRepository>(SettingsRepositoryImpl());
  getIt.registerSingleton<AuthRepository>(AuthRepositoryImpl());
  getIt.registerSingleton<DriverChatRepositoryFacade>(DriverChatRepositoryImpl());
  getIt.registerSingleton<UserRepository>(UserRepositoryImpl());
  getIt.registerSingleton<DrawRepository>(DrawRepositoryImpl());
  getIt.registerSingleton<OrdersRepositoryFacade>(OrdersRepository());
  getIt.registerSingleton<ParcelRepositoryFacade>(ParcelRepository());
  getIt.registerSingleton<AppRouter>(AppRouter());
  getIt.registerSingleton<NotificationRepositoryFacade>(NotificationRepositoryImpl());
  getIt.registerSingleton<FreeLunchRepositoryFacade>(FreeLunchRepository());
}

final dioHttp = getIt.get<HttpService>();
final settingsRepository = getIt.get<SettingsRepository>();
final authRepository = getIt.get<AuthRepository>();
final driverChatRepository = getIt.get<DriverChatRepositoryFacade>();
final userRepository = getIt.get<UserRepository>();
final drawRepository = getIt.get<DrawRepository>();
final orderRepository = getIt.get<OrdersRepositoryFacade>();
final parcelRepository = getIt.get<ParcelRepositoryFacade>();
final notificationRepo = getIt.get<NotificationRepositoryFacade>();
final freeLunchRepository = getIt.get<FreeLunchRepositoryFacade>();
final appRouter = getIt.get<AppRouter>();
