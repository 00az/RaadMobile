// Refuses a C4 environment file before a build uses it, so a missing, extra,
// secret-looking or cross-environment value fails the build.
//
//   dart run tool/check_env_config.dart <c4-config.json> <dev|stg|prd>

import 'dart:convert';
import 'dart:io';

import 'package:raad_mobile/config/environment_config.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/check_env_config.dart <file> <dev|stg|prd>',
    );
    exit(64);
  }
  final expected = RaadEnvironment.tryParse(args[1]);
  if (expected == null) {
    stderr.writeln('The environment must be dev, stg or prd.');
    exit(64);
  }
  final Object? json;
  try {
    json = jsonDecode(File(args[0]).readAsStringSync());
  } on Object catch (error) {
    stderr.writeln('Cannot read ${args[0]}: $error');
    exit(1);
  }
  if (json is! Map<String, Object?>) {
    stderr.writeln('${args[0]} must hold one JSON object.');
    exit(1);
  }
  try {
    final config = EnvironmentConfig.parse(json, expectedEnvironment: expected);
    stdout.writeln(
      'C4 configuration is valid for ${config.environment.name}: '
      '${config.moneyApiBaseUrl}',
    );
  } on EnvironmentConfigException catch (error) {
    stderr.writeln('C4 configuration refused: ${error.message}');
    exit(1);
  }
}
