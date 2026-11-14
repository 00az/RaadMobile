import 'package:flutter/material.dart';

import 'api/money_service.dart';
import 'app/app_services.dart';
import 'app/raad_app.dart';
import 'auth/cognito_auth_service.dart';
import 'auth/session_store.dart';
import 'config/environment_config.dart';

/// Runs against one real environment, named by the C4 file the build was
/// given:
///
///     flutter run --dart-define-from-file=<c4-config.json>
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final EnvironmentConfig config;
  try {
    config = EnvironmentConfig.fromDartDefines();
  } on EnvironmentConfigException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
    return;
  }
  final auth = CognitoAuthService(config: config, store: SecureSessionStore());
  final money = MoneyService.create(
    baseUrl: config.moneyApiBaseUrl,
    auth: auth,
  );
  runApp(
    RaadApp(
      services: AppServices(
        auth: auth,
        money: money,
        environmentChip: config.environment.chipLabel,
      ),
    ),
  );
}

/// Shown instead of the app when the build's environment configuration is
/// missing or invalid. The app makes no network call in this state.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This build has no valid environment configuration.\n\n$message',
              key: const ValueKey('config.error'),
            ),
          ),
        ),
      ),
    );
  }
}
