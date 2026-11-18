// Refuses a C4 environment file before a build uses it, so a missing, extra,
// secret-looking or cross-environment value fails the build.
//
//   dart run tool/check_env_config.dart <c4-config.json> <dev|stg|prd>
//   dart run tool/check_env_config.dart <c4-stg.json> stg \
//     --others <c4-dev.json> <c4-prd.json>
//
// With --others, the file is also refused when it shares an API address,
// issuer, audience or client ID with another environment's file.

import 'dart:convert';
import 'dart:io';

import 'package:raad_mobile/config/environment_config.dart';

void main(List<String> args) {
  final others = args.indexOf('--others');
  final own = others < 0 ? args : args.sublist(0, others);
  final otherFiles = others < 0 ? <String>[] : args.sublist(others + 1);
  if (own.length != 2 || (others >= 0 && otherFiles.isEmpty)) {
    stderr.writeln(
      'Usage: dart run tool/check_env_config.dart <file> <dev|stg|prd> '
      '[--others <file>...]',
    );
    exit(64);
  }
  final expected = RaadEnvironment.tryParse(own[1]);
  if (expected == null) {
    stderr.writeln('The environment must be dev, stg or prd.');
    exit(64);
  }
  try {
    final config = EnvironmentConfig.parse(
      _read(own[0]),
      expectedEnvironment: expected,
    );
    EnvironmentConfig.refuseSharedValues(config, [
      for (final file in otherFiles) EnvironmentConfig.parse(_read(file)),
    ]);
    stdout.writeln(
      'C4 configuration is valid for ${config.environment.name}: '
      '${config.moneyApiBaseUrl}',
    );
  } on EnvironmentConfigException catch (error) {
    stderr.writeln('C4 configuration refused: ${error.message}');
    exit(1);
  }
}

Map<String, Object?> _read(String path) {
  final Object? json;
  try {
    json = jsonDecode(File(path).readAsStringSync());
  } on Object catch (error) {
    stderr.writeln('Cannot read $path: $error');
    exit(1);
  }
  if (json is! Map<String, Object?>) {
    stderr.writeln('$path must hold one JSON object.');
    exit(1);
  }
  return json;
}
