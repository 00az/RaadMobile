import 'package:flutter/widgets.dart';

import '../api/money_service.dart';
import '../auth/auth_service.dart';

/// The services every screen uses, handed down the widget tree so tests can
/// swap in fakes.
final class AppServices {
  const AppServices({
    required this.auth,
    required this.money,
    this.environmentChip,
    this.now = _systemNow,
  });

  final AuthService auth;
  final MoneyService money;

  /// `DEV`, `STG`, `LOCAL`, or null for production.
  final String? environmentChip;

  final DateTime Function() now;

  static DateTime _systemNow() => DateTime.now();

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.services;
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
