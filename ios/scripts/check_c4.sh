#!/bin/sh
# Xcode build phase "Check C4": the iOS twin of the check in
# android/app/build.gradle.kts. A dev, stg or prd build of the real app
# (lib/main.dart) fails when its C4 values are missing, name another
# environment, or carry a key that looks like a secret. The offline preview
# and the integration journeys use the contract fakes and are not checked.
# Values are never printed.

set -eu

flavor="${RAAD_FLAVOR:-}"
target="${FLUTTER_TARGET:-lib/main.dart}"

if [ -z "$flavor" ]; then
  exit 0
fi
case "$target" in
  *lib/main.dart) ;;
  *) exit 0 ;;
esac

defines=$(printf '%s' "${DART_DEFINES:-}" | tr ',' '\n' | while read -r encoded; do
  [ -n "$encoded" ] && printf '%s' "$encoded" | base64 --decode && printf '\n'
done)

problems=""
for key in configVersion environment apiBaseUrl moneyBasePath authIssuer authAudience authClientId; do
  value=$(printf '%s\n' "$defines" | sed -n "s/^${key}=//p" | head -n 1)
  if [ -z "$value" ]; then
    problems="${problems} missing \"${key}\";"
  fi
done

environment=$(printf '%s\n' "$defines" | sed -n 's/^environment=//p' | head -n 1)
if [ -n "$environment" ] && [ "$environment" != "$flavor" ]; then
  problems="${problems} the ${flavor} flavour was given a C4 file for \"${environment}\";"
fi

secret_keys=$(printf '%s\n' "$defines" | sed -n 's/=.*//p' |
  grep -i -E 'secret|password|token|privatekey|clientsecret' || true)
if [ -n "$secret_keys" ]; then
  problems="${problems} a key looks like a secret;"
fi

if [ -n "$problems" ]; then
  echo "error: C4 configuration refused for ${flavor}:${problems} build with --flavor ${flavor} --dart-define-from-file=<c4-${flavor}.json>." >&2
  exit 1
fi
