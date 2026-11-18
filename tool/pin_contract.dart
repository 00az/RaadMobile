// Pins a contract file from the repo that owns it, as the contract design's
// "Pinning in a consumer repo" describes. Run it with your own GitHub access
// (the `gh` CLI, signed in), then open a pull request with the result and the
// regenerated client.
//
//   dart run tool/pin_contract.dart c1-money-api contract/c1-money-api/v1.0.0-rc.1
//   dart run tool/pin_contract.dart c1-money-api --commit <40-character sha>
//
// For a tag, it reads the annotated tag, checks that the SHA-256 written in
// the tag message matches the file at the tagged commit, and records both.
// `--commit` makes a development pin, for a contract that has no tag yet.
// Afterwards run `dart run swagger_parser` for C1 and `flutter test`.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

const pinsPath = 'contracts/pins.yaml';

const known = {
  'c1-money-api': (
    owner: '00az/RaadMoneyService',
    file: 'openapi/raad-money-v1.yaml',
    copy: 'contracts/pinned/c1-money-api/raad-money-v1.yaml',
  ),
};

Future<void> main(List<String> args) async {
  if (args.length < 2 || (args[1] == '--commit' && args.length != 3)) {
    stderr.writeln(
      'Usage: dart run tool/pin_contract.dart <contract-id> <tag>\n'
      '       dart run tool/pin_contract.dart <contract-id> --commit <sha>',
    );
    exit(64);
  }
  final id = args[0];
  final source = known[id];
  if (source == null) {
    stderr.writeln('Unknown contract "$id". Known: ${known.keys.join(', ')}');
    exit(64);
  }

  String? tag;
  String commit;
  String? taggedSha256;
  if (args[1] == '--commit') {
    commit = args[2];
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      stderr.writeln('Give the full 40-character commit SHA.');
      exit(64);
    }
  } else {
    tag = args[1];
    final ref = await gh(['api', 'repos/${source.owner}/git/ref/tags/$tag']);
    final object = (jsonDecode(ref) as Map)['object'] as Map;
    if (object['type'] != 'tag') {
      stderr.writeln('$tag is not an annotated tag.');
      exit(1);
    }
    final tagObject = jsonDecode(
      await gh(['api', 'repos/${source.owner}/git/tags/${object['sha']}']),
    ) as Map;
    commit = (tagObject['object'] as Map)['sha'] as String;
    final match = RegExp(r'\b[0-9a-f]{64}\b')
        .firstMatch(tagObject['message'] as String);
    if (match == null) {
      stderr.writeln('The message of $tag carries no SHA-256.');
      exit(1);
    }
    taggedSha256 = match.group(0);
  }

  final bytes = await ghBytes([
    'api',
    '-H',
    'Accept: application/vnd.github.raw',
    'repos/${source.owner}/contents/${source.file}?ref=$commit',
  ]);
  final digest = sha256.convert(bytes).toString();
  if (taggedSha256 != null && taggedSha256 != digest) {
    stderr.writeln(
      'The file at $tag has SHA-256 $digest, but the tag message says '
      '$taggedSha256. Nothing was changed.',
    );
    exit(1);
  }

  File(source.copy)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  final entries = readPins()
    ..removeWhere((entry) => entry['contract'] == id)
    ..add({
      'contract': id,
      'owner': source.owner,
      'file': source.file,
      'copy': source.copy,
      'tag': tag,
      'commit': commit,
      'sha256': digest,
      if (tag == null)
        'note':
            'Development pin; no release tag exists yet. Replace it with '
            'a contract/$id tag once one is created.',
    });
  entries.sort((a, b) => '${a['contract']}'.compareTo('${b['contract']}'));
  writePins(entries);
  stdout.writeln('Pinned $id at ${tag ?? commit} ($digest).');
}

List<Map<String, Object?>> readPins() {
  final file = File(pinsPath);
  if (!file.existsSync()) return [];
  final yaml = loadYaml(file.readAsStringSync()) as YamlMap?;
  final pins = (yaml?['pins'] as YamlList?) ?? YamlList();
  return [
    for (final pin in pins.cast<YamlMap>())
      {for (final entry in pin.entries) '${entry.key}': entry.value},
  ];
}

void writePins(List<Map<String, Object?>> entries) {
  final out = StringBuffer()
    ..writeln(
      '# Contracts this repo consumes. Each entry pins one byte-for-byte copy under',
    )
    ..writeln(
      '# contracts/pinned/. Code generation and tests read only those copies, and',
    )
    ..writeln(
      "# test/contract_test.dart fails if a copy's SHA-256 differs from its entry.",
    )
    ..writeln(
      '# Change a pin only through a pull request, with tool/pin_contract.dart.',
    )
    ..writeln('pins:');
  const order = [
    'contract',
    'owner',
    'file',
    'copy',
    'tag',
    'commit',
    'sha256',
    'note',
  ];
  for (final entry in entries) {
    var first = true;
    for (final key in order) {
      if (!entry.containsKey(key)) continue;
      final value = entry[key];
      out.writeln('${first ? '  - ' : '    '}$key: ${value ?? 'null'}');
      first = false;
    }
  }
  File(pinsPath).writeAsStringSync(out.toString());
}

Future<String> gh(List<String> args) async => utf8.decode(await ghBytes(args));

Future<List<int>> ghBytes(List<String> args) async {
  final result = await Process.run('gh', args, stdoutEncoding: null);
  if (result.exitCode != 0) {
    stderr.writeln('gh ${args.join(' ')} failed: ${result.stderr}');
    exit(1);
  }
  return result.stdout as List<int>;
}
