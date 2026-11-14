/// Mobile environment configuration, contract C4
/// (`raad-mobile-environment-config` v1.0).
///
/// Each build is tied to exactly one environment. The values are non-secret
/// deployment outputs supplied at build time with
/// `--dart-define-from-file=<c4 file>`. A missing, extra, secret-looking or
/// cross-environment value is refused: the app never falls back to another
/// environment.
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

  /// Reads the C4 keys supplied with `--dart-define-from-file`.
  ///
  /// `RAAD_BUILD_ENVIRONMENT`, when set by the build flavour, names the only
  /// environment this build accepts.
  static EnvironmentConfig fromDartDefines() {
    const values = <String, String>{
      'configVersion': String.fromEnvironment('configVersion'),
      'environment': String.fromEnvironment('environment'),
      'apiBaseUrl': String.fromEnvironment('apiBaseUrl'),
      'moneyBasePath': String.fromEnvironment('moneyBasePath'),
      'authIssuer': String.fromEnvironment('authIssuer'),
      'authAudience': String.fromEnvironment('authAudience'),
      'authClientId': String.fromEnvironment('authClientId'),
    };
    const buildEnvironment = String.fromEnvironment('RAAD_BUILD_ENVIRONMENT');
    RaadEnvironment? expected;
    if (buildEnvironment.isNotEmpty) {
      expected = RaadEnvironment.tryParse(buildEnvironment);
      if (expected == null) {
        throw const EnvironmentConfigException(
          'RAAD_BUILD_ENVIRONMENT must be dev, stg or prd.',
        );
      }
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
