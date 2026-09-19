import 'package:rast/core/api/api_services/home_api.dart';
import 'package:rast/core/api/api_services/services_api.dart';
import 'package:rast/core/api/api_services/providers_api.dart';
import 'package:rast/core/api/api_services/auth_api.dart';
import 'package:rast/core/api/api_services/bookings_api.dart';

/// نقاط الوصول للـ API
class Api {
  static final home = HomeApi();
  static final services = ServicesApi();
  static final providers = ProvidersApi();
  static final auth = AuthApi();
  static final bookings = BookingsApi();
}
