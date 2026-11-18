import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'app/language.dart';
import 'app/raad_app.dart';
import 'auth/cognito_auth_service.dart';
import 'auth/session_store.dart';
import 'config/build_environment.dart';
import 'config/environment_config.dart';
import 'l10n/app_localizations.dart';

/// Runs against one real environment, named by the C4 file the build was
/// given:
///
///     flutter run --dart-define-from-file=<c4-config.json>
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final EnvironmentConfig config;
  try {
    config = configFromBuild();
  } on EnvironmentConfigException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
    return;
  }
  final auth = CognitoAuthService(config: config, store: SecureSessionStore());
  runApp(
    RaadApp(
      services: AppServices.create(
        auth: auth,
        moneyBaseUrl: config.moneyApiBaseUrl,
        environmentName: config.environment.name,
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
      supportedLocales: LanguageSetting.supportedLocales,
      localizationsDelegates: raadLocalizationsDelegates,
      localeListResolutionCallback: (locales, _) =>
          LanguageSetting.resolve(locales),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              // The detail names the build-time C4 problem for the people
              // who make builds; it holds no secret.
              child: Text(
                '${AppLocalizations.of(context).configErrorTitle}\n\n$message',
                key: const ValueKey('config.error'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
