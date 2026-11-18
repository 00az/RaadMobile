// Fails when the app's own code under lib/ can write to the console or the
// debug log (NFR10.10; review-01 R-01). Passwords, tokens, codes and personal
// details must never reach a log, and the app keeps that simple by writing no
// log at all. The check looks for:
// - print, called or torn off;
// - debugPrint and its relatives (debugPrintStack, debugPrintSynchronously,
//   the debugPrint... flags) and the debugDump... tree dumps, which print
//   through debugPrint;
// - stdout and stderr from dart:io;
// - log from dart:developer, with or without an import prefix.
// Comments and the text of string literals are ignored; code inside a
// `${...}` interpolation is checked. The generated client
// (lib/api/generated/) and the generated localizations (lib/l10n/) are not
// scanned.
//
//   dart run tool/check_no_logging.dart [lib]

import 'dart:io';

/// Folders under the scanned root that hold generated code.
const generatedFolders = ['api/generated/', 'l10n/'];

/// Names that write to the console wherever they appear in code.
final RegExp _consoleWriters = RegExp(
  r'(?<![\w$])(print|debugPrint\w*|debugDump\w*|stdout|stderr)(?![\w$])',
);

/// An import of dart:developer, with its prefix when it has one.
final RegExp _developerImport = RegExp(
  r'''^[ \t]*import\s+(['"])dart:developer\1(?:\s+as\s+([A-Za-z_$][\w$]*))?''',
  multiLine: true,
);

/// One place where code can write to the console or the debug log.
final class LoggingCall {
  const LoggingCall(this.path, this.line, this.name);

  final String path;
  final int line;
  final String name;

  @override
  String toString() => '$path:$line: uses $name';
}

/// Every console or log write in [source], the file at [path], in the order
/// they appear.
List<LoggingCall> loggingCalls(String path, String source) {
  final code = codeOnly(source);
  final found = <(int, String)>[
    for (final match in _consoleWriters.allMatches(code))
      (match.start, match[1]!),
    for (final pattern in _developerLogPatterns(source, code))
      for (final match in pattern.allMatches(code))
        (match.start, 'log from dart:developer'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (offset, name) in found)
      LoggingCall(path, _lineAt(code, offset), name),
  ];
}

/// What a call to dart:developer's log looks like in this file: `log` alone
/// after an import without a prefix, `<prefix>.log` after a prefixed one.
List<RegExp> _developerLogPatterns(String source, String code) {
  final patterns = <String>{};
  for (final match in _developerImport.allMatches(source)) {
    // An import written inside a comment or a string is not an import.
    final keyword = match.start + match[0]!.indexOf('import');
    if (!code.startsWith('import', keyword)) continue;
    final prefix = match[2];
    patterns.add(
      prefix == null
          ? r'(?<![\w$.])log(?![\w$])'
          : '(?<![\\w\$])${RegExp.escape(prefix)}\\s*\\.\\s*log(?![\\w\$])',
    );
  }
  return [for (final pattern in patterns) RegExp(pattern)];
}

int _lineAt(String text, int offset) =>
    '\n'.allMatches(text.substring(0, offset)).length + 1;

/// [source] with every comment and the text of every string literal turned
/// into spaces. Line breaks and the length stay the same, so an offset in
/// the result is on the same line in [source]. Code inside `${...}` stays.
String codeOnly(String source) => (_Blanker(source)..code()).result;

final class _Blanker {
  _Blanker(this._source) : _out = _source.split('');

  final String _source;
  final List<String> _out;
  int _i = 0;

  String get result => _out.join();

  /// Reads code to the end, or, when [nested], up to the `}` that closes an
  /// interpolation (which it leaves for the caller).
  void code({bool nested = false}) {
    var depth = 0;
    while (_i < _source.length) {
      if (_source.startsWith('//', _i)) {
        _lineComment();
      } else if (_source.startsWith('/*', _i)) {
        _blockComment();
      } else if (_source[_i] == "'" || _source[_i] == '"') {
        _string();
      } else {
        if (_source[_i] == '{') depth++;
        if (_source[_i] == '}') {
          if (nested && depth == 0) return;
          depth--;
        }
        _i++;
      }
    }
  }

  void _lineComment() {
    final end = _source.indexOf('\n', _i);
    final stop = end < 0 ? _source.length : end;
    _blank(_i, stop);
    _i = stop;
  }

  /// Dart block comments nest.
  void _blockComment() {
    final start = _i;
    var depth = 0;
    while (_i < _source.length) {
      if (_source.startsWith('/*', _i)) {
        depth++;
        _i += 2;
      } else if (_source.startsWith('*/', _i)) {
        depth--;
        _i += 2;
        if (depth == 0) break;
      } else {
        _i++;
      }
    }
    _blank(start, _i);
  }

  void _string() {
    final raw =
        _i > 0 &&
        _source[_i - 1] == 'r' &&
        (_i < 2 || !_identifierPart.hasMatch(_source[_i - 2]));
    final quote = _source[_i];
    final close = _source.startsWith(quote * 3, _i) ? quote * 3 : quote;
    _i += close.length;
    var textStart = _i;
    while (_i < _source.length && !_source.startsWith(close, _i)) {
      if (close.length == 1 && _source[_i] == '\n') break; // never closed
      if (!raw && _source[_i] == r'\') {
        _i += 2;
      } else if (!raw && _source.startsWith(r'${', _i)) {
        _blank(textStart, _i + 2);
        _i += 2;
        code(nested: true);
        _i++; // the closing brace
        textStart = _i;
      } else {
        _i++;
      }
    }
    _blank(textStart, _i);
    if (_i < _source.length && _source.startsWith(close, _i)) {
      _i += close.length;
    }
  }

  void _blank(int from, int to) {
    for (var k = from; k < to && k < _out.length; k++) {
      if (_out[k] != '\n') _out[k] = ' ';
    }
  }
}

final RegExp _identifierPart = RegExp(r'[\w$]');

/// Whether [path], a file under [root], is the app's own code rather than
/// generated code.
bool isScanned(String path, {String root = 'lib'}) {
  final file = path.replaceAll(r'\', '/');
  return !generatedFolders.any((folder) => file.startsWith('$root/$folder'));
}

/// The Dart files under [root] that the check reads, sorted.
List<String> dartFilesToScan(String root) => [
  for (final entity in Directory(root).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart'))
      if (entity.path.replaceAll(r'\', '/') case final path
          when isScanned(path, root: root))
        path,
]..sort();

void main(List<String> args) {
  final given = args.isEmpty ? 'lib' : args.first;
  final root = given.endsWith('/')
      ? given.substring(0, given.length - 1)
      : given;
  if (!Directory(root).existsSync()) {
    stderr.writeln('There is no folder "$root" to check.');
    exit(2);
  }
  final files = dartFilesToScan(root);
  if (files.isEmpty) {
    stderr.writeln('There are no Dart files to check under $root/.');
    exit(2);
  }
  final calls = [
    for (final path in files)
      ...loggingCalls(path, File(path).readAsStringSync()),
  ];
  if (calls.isEmpty) {
    final skipped = generatedFolders.map((f) => '$root/$f').join(' and ');
    stdout.writeln(
      'No logging calls in ${files.length} files under $root/ '
      '($skipped hold generated code and are not checked).',
    );
    return;
  }
  stderr
    ..writeln(
      'The app must not write to the console or the debug log (NFR10.10):',
    )
    ..writeln(calls.map((call) => '  - $call').join('\n'));
  exit(1);
}
