import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/config/environment_config.dart';

Map<String, Object?> devConfig([Map<String, Object?> changes = const {}]) => {
  'configVersion': '1.0',
  'environment': 'dev',
  'apiBaseUrl': 'https://api.dev.raad.example',
  'moneyBasePath': '/money/v1',
  'authIssuer':
      'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_AbCdEf123',
  'authAudience': '1example23456789',
  'authClientId': '1example23456789',
  ...changes,
};

Matcher refusedWith(String fragment) => throwsA(
  isA<EnvironmentConfigException>().having(
    (error) => error.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('accepts a complete dev configuration', () {
    final config = EnvironmentConfig.parse(devConfig());
    expect(config.environment, RaadEnvironment.dev);
    expect(config.moneyApiBaseUrl, 'https://api.dev.raad.example/money/v1');
    expect(config.userPoolId, 'us-east-1_AbCdEf123');
    expect(config.authClientId, '1example23456789');
    expect(config.environment.chipLabel, 'DEV');
  });

  test('joins the base URL and path without a double slash', () {
    final config = EnvironmentConfig.parse(
      devConfig({'apiBaseUrl': 'https://api.dev.raad.example/'}),
    );
    expect(config.moneyApiBaseUrl, 'https://api.dev.raad.example/money/v1');
  });

  test('shows a chip for dev and stg only', () {
    expect(RaadEnvironment.stg.chipLabel, 'STG');
    expect(RaadEnvironment.prd.chipLabel, isNull);
  });

  test('refuses a missing value', () {
    final config = devConfig()..remove('authClientId');
    expect(() => EnvironmentConfig.parse(config), refusedWith('authClientId'));
    expect(
      () => EnvironmentConfig.parse(devConfig({'apiBaseUrl': ''})),
      refusedWith('apiBaseUrl'),
    );
  });

  test('refuses an unknown key, because the schema is closed', () {
    expect(
      () => EnvironmentConfig.parse(devConfig({'region': 'us-east-1'})),
      refusedWith('Unknown key "region"'),
    );
  });

  test('refuses a key that looks like a secret', () {
    for (final key in [
      'clientSecret',
      'apiToken',
      'adminPassword',
      'privateKey',
    ]) {
      expect(
        () => EnvironmentConfig.parse(devConfig({key: 'x'})),
        refusedWith('looks like a secret'),
      );
    }
  });

  test('refuses another config version or environment name', () {
    expect(
      () => EnvironmentConfig.parse(devConfig({'configVersion': '2.0'})),
      refusedWith('configVersion'),
    );
    expect(
      () => EnvironmentConfig.parse(devConfig({'environment': 'qa'})),
      refusedWith('environment'),
    );
  });

  test('refuses plain http and a wrong money path', () {
    expect(
      () => EnvironmentConfig.parse(
        devConfig({'apiBaseUrl': 'http://api.dev.raad.example'}),
      ),
      refusedWith('https'),
    );
    expect(
      () => EnvironmentConfig.parse(devConfig({'moneyBasePath': '/money/v2'})),
      refusedWith('moneyBasePath'),
    );
  });

  test('refuses an API host that names another environment', () {
    expect(
      () => EnvironmentConfig.parse(
        devConfig({
          'environment': 'stg',
          'apiBaseUrl': 'https://api.dev.raad.example',
        }),
      ),
      refusedWith('names environment dev'),
    );
    expect(
      () => EnvironmentConfig.parse(
        devConfig({
          'environment': 'prd',
          'apiBaseUrl': 'https://stg-api.raad.example',
        }),
      ),
      refusedWith('names environment stg'),
    );
  });

  test('a production build accepts only the prd configuration', () {
    expect(
      () => EnvironmentConfig.parse(
        devConfig(),
        expectedEnvironment: RaadEnvironment.prd,
      ),
      refusedWith('This build is for prd'),
    );
    final prd = EnvironmentConfig.parse(
      devConfig({
        'environment': 'prd',
        'apiBaseUrl': 'https://api.raad.example',
      }),
      expectedEnvironment: RaadEnvironment.prd,
    );
    expect(prd.environment, RaadEnvironment.prd);
  });

  test('refuses an issuer without one user pool ID in its own region', () {
    expect(
      () => EnvironmentConfig.parse(
        devConfig({
          'authIssuer': 'https://cognito-idp.us-east-1.amazonaws.com/',
        }),
      ),
      refusedWith('user pool ID'),
    );
    expect(
      () => EnvironmentConfig.parse(
        devConfig({
          'authIssuer':
              'https://cognito-idp.eu-west-1.amazonaws.com/us-east-1_AbCdEf123',
        }),
      ),
      refusedWith('different regions'),
    );
  });

  test('a build without the C4 values refuses to start', () {
    expect(EnvironmentConfig.fromDartDefines, refusedWith('Missing value'));
  });
}
