/// Mobile environment configuration, contract C4
/// (`raad-mobile-environment-config` v1.0).
///
/// Each build is tied to exactly one environment. The values are non-secret
/// deployment outputs supplied at build time with
/// `--dart-define-from-file=<c4 file>`. A missing, extra, secret-looking or
/// cross-environment value is refused: the app never falls back to another
/// environment.
///
/// This file is plain Dart so `tool/check_env_config.dart` can use it
/// outside Flutter; `build_environment.dart` reads the build's own values.
library;

enum RaadEnvironment {
  dev('DEV'),
  stg('STG'),
  prd(null);

  const RaadEnvironment(this.chipLabel);

  /// The environment chip shown in the app bar; production shows none.
  final String? chipLabel;

  static RaadEnvironment? tryParse(String value) {
    for (final environment in values) {
      if (environment.name == value) return environment;
    }
    return null;
  }
}

class EnvironmentConfigException implements Exception {
  const EnvironmentConfigException(this.message);

  final String message;

  @override
  String toString() => 'EnvironmentConfigException: $message';
}

final class EnvironmentConfig {
  const EnvironmentConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.moneyBasePath,
    required this.authIssuer,
    required this.authAudience,
    required this.authClientId,
  });

  static const String configVersion = '1.0';
  static const String requiredMoneyBasePath = '/money/v1';

  /// Every key of the closed C4 schema.
  static const List<String> keys = [
    'configVersion',
    'environment',
    'apiBaseUrl',
    'moneyBasePath',
    'authIssuer',
    'authAudience',
    'authClientId',
  ];

  /// Values no non-secret configuration holds: an AWS access key ID, a
  /// private key block or a client secret pasted into a value.
  static final RegExp _secretValue = RegExp(
    r'(AKIA|ASIA)[0-9A-Z]{16}|-----BEGIN|PRIVATE KEY|aws_secret',
    caseSensitive: false,
  );

  static const List<String> _secretMarkers = [
    'secret',
    'password',
    'token',
    'privatekey',
    'clientsecret',
  ];

  final RaadEnvironment environment;
  final Uri apiBaseUrl;
  final String moneyBasePath;
  final Uri authIssuer;
  final String authAudience;
  final String authClientId;

  /// Base URL the generated Money API client is given, for example
  /// `https://api.dev.example/money/v1`.
  String get moneyApiBaseUrl {
    final root = apiBaseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return '$root$moneyBasePath';
  }

  /// The Cognito user pool ID, which is the last path segment of the issuer.
  String get userPoolId => authIssuer.pathSegments.last;

  /// Validates a C4 document.
  ///
  /// [expectedEnvironment] is the environment the build was made for; a
  /// production build passes [RaadEnvironment.prd] and accepts nothing else.
  static EnvironmentConfig parse(
    Map<String, Object?> json, {
    RaadEnvironment? expectedEnvironment,
  }) {
    for (final key in json.keys) {
      final lower = key.toLowerCase();
      if (_secretMarkers.any(lower.contains)) {
        throw EnvironmentConfigException(
          'Key "$key" looks like a secret; C4 holds no secrets.',
        );
      }
      if (!keys.contains(key)) {
        throw EnvironmentConfigException('Unknown key "$key".');
      }
    }
    String read(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw EnvironmentConfigException('Missing value for "$key".');
      }
      if (_secretValue.hasMatch(value)) {
        throw EnvironmentConfigException(
          'The value of "$key" looks like a secret; C4 holds no secrets.',
        );
      }
      return value;
    }

    if (read('configVersion') != configVersion) {
      throw const EnvironmentConfigException(
        'configVersion must be "$configVersion".',
      );
    }
    final environment = RaadEnvironment.tryParse(read('environment'));
    if (environment == null) {
      throw const EnvironmentConfigException(
        'environment must be dev, stg or prd.',
      );
    }
    if (expectedEnvironment != null && environment != expectedEnvironment) {
      throw EnvironmentConfigException(
        'This build is for ${expectedEnvironment.name} but the configuration '
        'is for ${environment.name}.',
      );
    }
    final apiBaseUrl = _httpsUri(read('apiBaseUrl'), 'apiBaseUrl');
    if (apiBaseUrl.hasQuery || apiBaseUrl.hasFragment) {
      throw const EnvironmentConfigException(
        'apiBaseUrl must not carry a query or fragment.',
      );
    }
    _refuseOtherEnvironmentLabel(apiBaseUrl.host, environment, 'apiBaseUrl');
    final moneyBasePath = read('moneyBasePath');
    if (moneyBasePath != requiredMoneyBasePath) {
      throw const EnvironmentConfigException(
        'moneyBasePath must be "$requiredMoneyBasePath".',
      );
    }
    final authIssuer = _httpsUri(read('authIssuer'), 'authIssuer');
    final poolId = authIssuer.pathSegments.isEmpty
        ? ''
        : authIssuer.pathSegments.last;
    final poolMatch = RegExp(r'^([a-z]{2}(?:-[a-z]+)+-\d)_[0-9A-Za-z]+$')
        .firstMatch(poolId);
    if (authIssuer.pathSegments.length != 1 || poolMatch == null) {
      throw const EnvironmentConfigException(
        'authIssuer must end with one user pool ID such as us-east-1_AbC123.',
      );
    }
    final region = poolMatch.group(1)!;
    if (!authIssuer.host.contains(region)) {
      throw const EnvironmentConfigException(
        'authIssuer host and user pool ID name different regions.',
      );
    }
    final authAudience = read('authAudience');
    final authClientId = read('authClientId');
    return EnvironmentConfig._(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      moneyBasePath: moneyBasePath,
      authIssuer: authIssuer,
      authAudience: authAudience,
      authClientId: authClientId,
    );
  }

  /// Refuses [config] when it shares an API address, issuer, audience or
  /// client ID with the configuration of another environment: each
  /// environment has its own sign-in and API, so a shared value means a file
  /// was copied across environments.
  static void refuseSharedValues(
    EnvironmentConfig config,
    Iterable<EnvironmentConfig> others,
  ) {
    for (final other in others) {
      if (other.environment == config.environment) {
        throw EnvironmentConfigException(
          'Two files are for ${config.environment.name}.',
        );
      }
      final shared = <String>[
        if (other.apiBaseUrl.host == config.apiBaseUrl.host) 'apiBaseUrl',
        if (other.authIssuer == config.authIssuer) 'authIssuer',
        if (other.authAudience == config.authAudience) 'authAudience',
        if (other.authClientId == config.authClientId) 'authClientId',
      ];
      if (shared.isNotEmpty) {
        throw EnvironmentConfigException(
          '${shared.join(', ')} of ${config.environment.name} is the same as '
          'in ${other.environment.name}.',
        );
      }
    }
  }

  /// Validates the C4 values a build was given. The build flavour (`dev`,
  /// `stg` or `prd`) names the only environment the build accepts; so does
  /// `RAAD_BUILD_ENVIRONMENT` when it is set, and the two must agree.
  static EnvironmentConfig fromDefines(
    Map<String, String> values, {
    String? flavor,
    String buildEnvironment = '',
  }) {
    RaadEnvironment? expected;
    if (flavor != null && flavor.isNotEmpty) {
      expected = RaadEnvironment.tryParse(flavor);
      if (expected == null) {
        throw EnvironmentConfigException(
          'The build flavour "$flavor" is not dev, stg or prd.',
        );
      }
    }
    if (buildEnvironment.isNotEmpty) {
      final named = RaadEnvironment.tryParse(buildEnvironment);
      if (named == null) {
        throw const EnvironmentConfigException(
          'RAAD_BUILD_ENVIRONMENT must be dev, stg or prd.',
        );
      }
      if (expected != null && named != expected) {
        throw EnvironmentConfigException(
          'The ${expected.name} flavour was built with '
          'RAAD_BUILD_ENVIRONMENT=${named.name}.',
        );
      }
      expected = named;
    }
    return parse(values, expectedEnvironment: expected);
  }

  static Uri _httpsUri(String value, String key) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw EnvironmentConfigException('$key must be an https:// URL.');
    }
    return uri;
  }

  /// Refuses a host whose labels name a different RAAD environment, such as a
  /// `stg` build pointing at `api.dev.example`.
  static void _refuseOtherEnvironmentLabel(
    String host,
    RaadEnvironment environment,
    String key,
  ) {
    final labels = host.toLowerCase().split(RegExp(r'[.-]'));
    for (final other in RaadEnvironment.values) {
      if (other != environment && labels.contains(other.name)) {
        throw EnvironmentConfigException(
          '$key names environment ${other.name}, not ${environment.name}.',
        );
      }
    }
  }
}
