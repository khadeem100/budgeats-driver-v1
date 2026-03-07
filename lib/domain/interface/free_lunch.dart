import 'package:driver/infrastructure/models/data/free_lunch_data.dart';
import 'package:driver/domain/handlers/handlers.dart';

abstract class FreeLunchRepositoryFacade {
  Future<ApiResult<FreeLunchResponse>> getFreeLunches();
  Future<ApiResult<dynamic>> redeemFreeLunch(int offerId);
}
