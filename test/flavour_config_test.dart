// Each flavour (dev, stg, prd) accepts only its own C4 file (US6.2, BR3.8,
// C4 validation rules): a missing, extra, secret-looking or
// cross-environment value is refused before the app shows anything.

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/config/environment_config.dart';

Map<String, String> c4(
  String environment, {
  String? host,
  String pool = 'us-east-1_Pool1',
  String client = 'client-1',
}) => {
  'configVersion': '1.0',
  'environment': environment,
  'apiBaseUrl': 'https://${host ?? 'api-$environment.raad.example'}',
  'moneyBasePath': '/money/v1',
  'authIssuer': 'https://cognito-idp.us-east-1.amazonaws.com/$pool',
  'authAudience': client,
  'authClientId': client,
};

Matcher refused([String fragment = '']) => throwsA(
  isA<EnvironmentConfigException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  group('each flavour takes its own file', () {
    for (final environment in RaadEnvironment.values) {
      test('${environment.name} accepts its own configuration', () {
        final config = EnvironmentConfig.fromDefines(
          c4(environment.name),
          flavor: environment.name,
        );
        expect(config.environment, environment);
        expect(config.moneyApiBaseUrl, endsWith('/money/v1'));
      });

      test('${environment.name} refuses every other environment\'s file', () {
        for (final other in RaadEnvironment.values.where(
          (e) => e != environment,
        )) {
          expect(
            () => EnvironmentConfig.fromDefines(
              c4(other.name),
              flavor: environment.name,
            ),
            refused('This build is for ${environment.name}'),
            reason: other.name,
          );
        }
      });
    }

    test('an AWS-assigned host with no environment label is fine', () {
      final config = EnvironmentConfig.fromDefines(
        c4('stg', host: 'd1abcdefghij.cloudfront.net'),
        flavor: 'stg',
      );
      expect(config.apiBaseUrl.host, 'd1abcdefghij.cloudfront.net');
    });

    test('the flavour and RAAD_BUILD_ENVIRONMENT must agree', () {
      expect(
        EnvironmentConfig.fromDefines(
          c4('prd'),
          flavor: 'prd',
          buildEnvironment: 'prd',
        ).environment,
        RaadEnvironment.prd,
      );
      expect(
        () => EnvironmentConfig.fromDefines(
          c4('dev'),
          flavor: 'dev',
          buildEnvironment: 'prd',
        ),
        refused('RAAD_BUILD_ENVIRONMENT=prd'),
      );
      expect(
        () => EnvironmentConfig.fromDefines(c4('dev'), flavor: 'qa'),
        refused('flavour "qa"'),
      );
    });

    test('a build with no flavour takes RAAD_BUILD_ENVIRONMENT alone', () {
      expect(
        () => EnvironmentConfig.fromDefines(c4('dev'), buildEnvironment: 'prd'),
        refused('This build is for prd'),
      );
    });
  });

  group('values', () {
    test('every missing value is refused', () {
      for (final key in EnvironmentConfig.keys) {
        final values = c4('dev')..[key] = '';
        expect(
          () => EnvironmentConfig.fromDefines(values, flavor: 'dev'),
          refused('Missing value for "$key"'),
          reason: key,
        );
      }
    });

    test('a value that looks like a secret is refused', () {
      // Built from parts so the secret scanner in CI does not flag the
      // AWS documentation example key in this file.
      for (final value in [
        ['AKIA', 'IOSFODNN7EXAMPLE'].join(),
        ['-----BEGIN', 'PRIVATE KEY-----'].join(' '),
      ]) {
        expect(
          () => EnvironmentConfig.fromDefines(
            c4('dev')..['authClientId'] = value,
            flavor: 'dev',
          ),
          refused('looks like a secret'),
          reason: value,
        );
      }
    });
  });

  group('values shared across environments (tool/check_env_config.dart)', () {
    EnvironmentConfig parse(Map<String, String> values) =>
        EnvironmentConfig.parse(values);

    test('distinct environments pass', () {
      EnvironmentConfig.refuseSharedValues(
        parse(c4('stg', pool: 'us-east-1_Stg', client: 'stg-client')),
        [
          parse(c4('dev', pool: 'us-east-1_Dev', client: 'dev-client')),
          parse(c4('prd', pool: 'us-east-1_Prd', client: 'prd-client')),
        ],
      );
    });

    test('a client ID copied from dev into stg is refused', () {
      expect(
        () => EnvironmentConfig.refuseSharedValues(
          parse(c4('stg', pool: 'us-east-1_Stg', client: 'same')),
          [parse(c4('dev', pool: 'us-east-1_Dev', client: 'same'))],
        ),
        refused('authAudience, authClientId of stg is the same as in dev'),
      );
    });

    test('one API host or issuer for two environments is refused', () {
      expect(
        () => EnvironmentConfig.refuseSharedValues(
          parse(
            c4(
              'prd',
              host: 'api.raad.example',
              pool: 'us-east-1_P',
              client: 'p',
            ),
          ),
          [
            parse(
              c4(
                'stg',
                host: 'api.raad.example',
                pool: 'us-east-1_S',
                client: 's',
              ),
            ),
          ],
        ),
        refused('apiBaseUrl'),
      );
      expect(
        () => EnvironmentConfig.refuseSharedValues(
          parse(c4('prd', pool: 'us-east-1_Same', client: 'p')),
          [parse(c4('dev', pool: 'us-east-1_Same', client: 'd'))],
        ),
        refused('authIssuer'),
      );
    });

    test('two files for one environment are refused', () {
      expect(
        () => EnvironmentConfig.refuseSharedValues(parse(c4('dev')), [
          parse(c4('dev', client: 'other')),
        ]),
        refused('Two files are for dev'),
      );
    });
  });
}
