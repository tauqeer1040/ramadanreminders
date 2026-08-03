import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_protocol.dart';
import '../services/analytics_service.dart';

final analyticsProvider = Provider<AnalyticsProtocol>((ref) {
  return AnalyticsService.instance;
});
