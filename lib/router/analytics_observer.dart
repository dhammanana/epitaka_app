import 'package:flutter/widgets.dart';

import '../core/services/app_analytics.dart';

class AnalyticsRouteObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      AppAnalytics.instance.logScreen(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(previousRoute);
    super.didPop(route, previousRoute);
  }
}
