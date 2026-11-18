/// The C4 configuration this build was made with (US6.2, BR3.8).
///
///     flutter build apk --flavor dev --dart-define-from-file=<c4-dev.json>
///
/// The values come from `--dart-define-from-file`; the flavour comes from
/// `--flavor`. A build whose file names another environment, or misses a
/// value, refuses to start before anything private is shown.
library;

import 'package:flutter/services.dart' show appFlavor;

import 'environment_config.dart';

/// Throws [EnvironmentConfigException] when the build's values are not a
/// valid C4 configuration for its own flavour.
EnvironmentConfig configFromBuild() => EnvironmentConfig.fromDefines(
  const {
    'configVersion': String.fromEnvironment('configVersion'),
    'environment': String.fromEnvironment('environment'),
    'apiBaseUrl': String.fromEnvironment('apiBaseUrl'),
    'moneyBasePath': String.fromEnvironment('moneyBasePath'),
    'authIssuer': String.fromEnvironment('authIssuer'),
    'authAudience': String.fromEnvironment('authAudience'),
    'authClientId': String.fromEnvironment('authClientId'),
  },
  flavor: appFlavor,
  buildEnvironment: const String.fromEnvironment('RAAD_BUILD_ENVIRONMENT'),
);
