abstract class AppConstants {
  AppConstants._();

  static const bool isDemo = false;

  /// api urls
  static const String baseUrl = 'https://api.budgeats.nl/';
  static const String drawingBaseUrl = 'https://api.openrouteservice.org';
  static const String googleApiKey = 'AIzaSyAo0EDk5sxDGBm7IXHDyEnNLVHIQtwsaRk';
  static const String adminPageUrl = 'https://admin.budgeats.nl';
  static const String webUrl = 'https://budgeats.nl';
  static const String routingKey =
      '5b3ce3597851110001cf62480384c1db92764d1b8959761ea2510ac8';

  /// hero tags
  static const String heroTagProfileAvatar = 'heroTagProfileAvatar';

  /// auth phone fields
  static const bool isSpecificNumberEnabled = false;
  static const bool isNumberLengthAlwaysSame = true;
  static const String countryCodeISO = 'SR';
  static const bool showFlag = true;
  static const bool showArrowIcon = true;

  /// location - Paramaribo, Suriname
  static const double demoLatitude = 5.8520355;
  static const double demoLongitude = -55.2038278;
  static const double pinLoadingMin = 0.116666667;
  static const double pinLoadingMax = 0.611111111;

  /// demo app info
  static const String demoSellerLogin = 'delivery@budgeats.nl';
  static const String demoSellerPassword = 'budgeats123';
}

enum UploadType {
  extras,
  brands,
  categories,
  shopsLogo,
  shopsBack,
  products,
  reviews,
  users,
  deliveryCar
}
