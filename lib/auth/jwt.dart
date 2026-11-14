/// Reads claims from a JWT the app already holds. It does not verify the
/// signature: the Money API and the edge verify every token (C5). The app
/// uses these claims only to decide when to refresh.
library;

import 'dart:convert';

/// The decoded payload, or null when the token is not a readable JWT.
Map<String, Object?>? jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final payload = jsonDecode(decoded);
    return payload is Map<String, Object?> ? payload : null;
  } on FormatException {
    return null;
  }
}

/// When the token expires, from its `exp` claim.
DateTime? jwtExpiry(String token) {
  final exp = jwtPayload(token)?['exp'];
  if (exp is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
}

/// True when the token has expired or will within [skew]. A token without a
/// readable expiry counts as expired.
bool jwtIsExpired(
  String token, {
  required DateTime now,
  Duration skew = const Duration(seconds: 60),
}) {
  final expiry = jwtExpiry(token);
  if (expiry == null) return true;
  return !now.toUtc().add(skew).isBefore(expiry);
}
