// Fails when line coverage of the app's own code is below the floor.
//
//   flutter test --coverage
//   dart run tool/check_coverage.dart [coverage/lcov.info] [80]
//
// Code generated from the pinned contract (lib/api/generated/) is left out:
// nobody writes it by hand, `dart run swagger_parser --check` guards it, and
// test/contract_test.dart exercises it. Every other file under lib/ counts.

import 'dart:io';

const excludedPrefixes = ['lib/api/generated/'];

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final floor = args.length > 1 ? double.parse(args[1]) : 80.0;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No coverage report at $path. Run flutter test --coverage.');
    exit(2);
  }

  final perFile = <String, (int, int)>{};
  String? current;
  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      final libIndex = current.indexOf('lib/');
      if (libIndex > 0) current = current.substring(libIndex);
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && current != null) {
      perFile[current] = (found, hit);
      current = null;
    }
  }

  var totalFound = 0;
  var totalHit = 0;
  final rows = <String>[];
  for (final entry
      in perFile.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    if (excludedPrefixes.any(entry.key.startsWith)) continue;
    final (lines, covered) = entry.value;
    totalFound += lines;
    totalHit += covered;
    final percent = lines == 0 ? 100 : covered * 100 / lines;
    rows.add('${percent.toStringAsFixed(1).padLeft(6)}%  ${entry.key}');
  }
  if (totalFound == 0) {
    stderr.writeln('The coverage report lists no app lines.');
    exit(2);
  }
  final total = totalHit * 100 / totalFound;
  stdout
    ..writeln(rows.join('\n'))
    ..writeln(
      'Line coverage: ${total.toStringAsFixed(2)}% '
      '($totalHit of $totalFound lines); floor ${floor.toStringAsFixed(0)}%.',
    );
  if (total < floor) {
    stderr.writeln('Coverage is below the floor.');
    exit(1);
  }
}
