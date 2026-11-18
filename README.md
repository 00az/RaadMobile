# RaadMobile

The RAAD digital wallet app for iOS and Android, in Flutter. Engineer 2 owns this repo. It calls the Money API in `RaadMoneyService` (contract C1) and signs in with the shared user pool from `Raad` (C3), configured per environment by C4.

What the app does (U1 walking skeleton, then U3):
- create an account, confirm it with the emailed code (and ask for a new code), sign in, reset a forgotten password, sign out;
- set the wallet up after sign-in and show the SAR balance, marked out of date with its time when a refresh fails;
- send simulated SAR to another RAAD user by email, with review before sending and a clear answer when the outcome is unknown;
- read the history page by page;
- work offline safely: sending is off, nothing is queued;
- Arabic (right to left) and English, chosen in the app.

No real payment system is connected and no card or bank detail is ever asked for. The card carousel and the international and bank-transfer tiles on the wallet are part of the design only and say they are not available yet. The card is labelled "Demo card" and carries no card network or wallet brand.

## Prerequisites

- **Flutter 3.47.2**, the version pinned in `pubspec.yaml`. The lockfile (`pubspec.lock`) is committed.
- **iOS builds and the iOS simulator:** macOS with Xcode and CocoaPods.
- **Android builds and the emulator:** the Android SDK and Java 17.
- **Changing a contract pin:** the `gh` CLI, signed in with your own GitHub access.

## Setup and test

```sh
flutter pub get --enforce-lockfile
```

```sh
flutter test --coverage && dart run tool/check_coverage.dart coverage/lcov.info 80
```

Run these checks locally before you open a pull request. CI runs the same checks on every pull request and every push to `main` (`.github/workflows/ci.yml`):

| Check | What it does |
|---|---|
| `dart format --set-exit-if-changed` | Fails on unformatted code. |
| `flutter analyze` | Runs the `flutter_lints` rules. Any issue fails. |
| `dart run tool/check_no_logging.dart` | Fails if the app's own code (everything in `lib/` except the generated client and localizations) uses `print`, `debugPrint` or its relatives, `stdout`, `stderr` or `log` from `dart:developer`. |
| `dart run swagger_parser --check` | Fails if the generated client differs from the pinned contract. |
| `dart run tool/check_l10n.dart` | Fails if a message is missing or empty in Arabic or English, or their placeholders differ. |
| `flutter gen-l10n` then `git diff` | Fails if the committed localizations are out of date. |
| `flutter test --coverage` | Runs the unit, widget, contract, accessibility and log-privacy tests. |
| Coverage floor | At least 80% line coverage of the app's own code. The generated C1 client is not counted. |
| C4 config check | Validates the example environment file. |
| Android dev build | Builds the `dev` flavour with the example C4 file. |
| gitleaks | Scans for committed secrets. |

## Environments and builds

There is one build per environment: the `dev`, `stg` and `prd` flavours. Each installs side by side with its own app identifier (suffix `.dev` or `.stg`; none for prd) and name (`RAAD DEV`, `RAAD STG`, `RAAD`), and takes that environment's C4 file:

```sh
dart run tool/check_env_config.dart config/c4-dev.json dev --others config/c4-stg.json config/c4-prd.json
flutter build apk --flavor dev --dart-define-from-file=config/c4-dev.json
flutter build ipa --flavor dev --dart-define-from-file=config/c4-dev.json
```

Use `stg` or `prd` in place of `dev` for the other environments. The C4 file holds non-secret deployment outputs, written by `Raad`'s `scripts/write_platform_config.py` from the environment's real outputs. Real files are not committed (`.gitignore`); `config/c4-dev.example.json` shows the shape. Until an environment is deployed only the example exists, so builds for real environments cannot be made yet; that is expected.

A build is refused when its C4 values:
- are missing or have an extra key;
- have a key or value that looks like a secret;
- are for another environment than the flavour (the Gradle task `checkC4<Flavour><Type>` on Android, the `Check C4` build phase on iOS);
- share an API address, issuer or client ID with another environment (`--others`).

The app checks again at start and shows only an error, before anything private, when the configuration is not valid for its flavour. Production builds may also pass `--dart-define=RAAD_BUILD_ENVIRONMENT=prd`; it must agree with the flavour.

The launcher icon is the bolt mark cut from the RAAD lockup (`assets/raad_bolt_icon.png`); regenerate the icons with `dart run flutter_launcher_icons`.

## Running the app without a network

The offline preview uses the local contract fakes (Money API with U2's rules, and sign-in):

```sh
flutter run -t lib/main_fake.dart --flavor dev
```

Sign in as `sara@raad.test` with the password `Local-preview-1`, then send to `omar@raad.test`. These accounts exist only inside the fake. The preview also shows fill-in shortcuts for them; real builds do not.

## API contract

The wire source of truth is the C1 OpenAPI file, pinned byte for byte at `contracts/pinned/c1-money-api/raad-money-v1.yaml`. Its source commit and SHA-256 are recorded in `contracts/pins.yaml`, and a test fails if the copy changes. No release tag exists yet, so the pin is the development commit `2b3660b` from `RaadMoneyService` branch `aidlc/u2-money-service`: the U2 pre-release, version `1.0.0-u2.1`, with saved and replayed transfer outcomes, the 1.00 to 500.00 SAR range and cursor paging of history.

To move the pin once a release is tagged:

```sh
dart run tool/pin_contract.dart c1-money-api contract/c1-money-api/v1.0.0
dart run swagger_parser
flutter test
```

The tool checks the file against the SHA-256 in the tag message. Open a pull request with the new pin and the regenerated client together.

The Dart client under `lib/api/generated/` is generated from the pinned copy by `swagger_parser`. It is configured in `pubspec.yaml` and must never be edited by hand. There are no hand-written wire models.

## How the app uses the Money API

| Flow | Request | Behaviour |
|---|---|---|
| Wallet setup | `PUT /money/v1/wallet` | Runs after sign-in, before the wallet shows. `200` and `201` are both success, and repeating it never credits the opening balance twice. On failure the app shows "We could not set up your wallet" with Try again. |
| Balance | `GET /money/v1/wallet` | Used on refresh (button or pull). The last balance is kept with its time per account and environment; a failed or offline refresh shows it marked out of date. With nothing kept the app shows an error, never a zero. |
| Recipient | `POST /money/v1/recipients/resolve` | Sends the normalized email in the body, never in a URL. |
| Transfer | `POST /money/v1/transfers` | Sends `recipientEmail` and integer `amountHalalas` with an `Idempotency-Key`. The key is made at the first Confirm and saved, with the recipient and amount, in the phone's protected storage before anything is sent. A definite refusal keeps the typed values and the next attempt gets a new key. |
| History | `GET /money/v1/transfers` | Pages of 20 in the order the service returns. Load more passes the exact `nextCursor` with the same page size; only a null cursor ends the list. An expired cursor starts again from page one. |

Other rules the app follows:
- **Errors** are flat: top-level `code`, `message` and `correlationId`. The app branches on `code` and shows its own Arabic or English text. A code it does not know gets the generic message.
- **Unknown transfer outcomes.** After a timeout, a lost answer, a `500`, a `503` or an undeclared status, the app says the outcome is unknown and never sends again by itself. The person may choose **Try again**, which sends exactly the same key and details: U2 then returns the first outcome, so money moves at most once. **Change details** drops the old key. The open intent survives a restart or a new sign-in as the same account; another account never sees it.
- **Retries.** A read gets one more try after a timeout, `500` or `503`, after a 250 to 750 ms pause or the `Retry-After` of a `503`, only while the 15-second deadline leaves room. A `429` is never retried by the app; it shows the wait.
- **Offline.** Without a connection Send, Confirm and Try again are off with a stated reason; they turn on again when it returns. Nothing is queued.
- **Money** is integer halalas everywhere. The app parses SAR text digit by digit (Arabic-Indic digits are read as Western ones) and formats with integer arithmetic, never floating point. Amounts show Western digits, `SAR` in English and `ر.س` in Arabic.
- **Sessions.** Concurrent requests share one token renewal. More than 30 days without use, or a clock that went backwards, asks for sign-in. Sign-out removes the tokens, the kept balance and the open transfer, and answers to requests from the old session are dropped.
- **Tokens and logging.** The access token goes only in `Authorization: Bearer`. Tokens and private records live only in the phone's secure storage. The app logs no requests, responses, tokens, codes, emails, amounts or keys. `test/log_privacy_test.dart` runs the account and money journeys with `print`, `debugPrint`, `stdout` and `stderr` captured, and fails if any password, code, token, account id, email, name, amount, request key or history cursor appears. `tool/check_no_logging.dart` fails on any of those calls, and on `log` from `dart:developer` (which a test cannot capture), in the app's own code.

## Integration tests

The journeys run on an iOS simulator and an Android emulator against the local fakes; they are fake-backed and prove nothing about a deployed environment:

```sh
flutter test integration_test/walking_skeleton_test.dart integration_test/u3_journeys_test.dart -d <ios-simulator-id>
flutter test integration_test/walking_skeleton_test.dart integration_test/u3_journeys_test.dart -d <android-emulator-id> --flavor dev
```

`walking_skeleton_test.dart` can also run against `dev` once it is deployed:

```sh
flutter test integration_test/walking_skeleton_test.dart --flavor dev \
  --dart-define-from-file=<c4-dev.json> \
  --dart-define-from-file=<temporary-accounts.json>
```

The dev run takes `RAAD_E2E_TARGET=dev` and the two test accounts from a temporary define file that the verification script writes from Secrets Manager and deletes afterwards. Passwords never go on the command line or into the repo.

`docs/acceptance-journey.md` is the written procedure for accepting the MVP on a deployed environment.

## Layout

```
lib/
  api/            Money API wrapper (money_service.dart); generated/ client
  app/            app shell, services, language, connectivity, protected storage
  auth/           C3 adapter (Cognito), session boundary, token store
  config/         C4 environment configuration
  l10n/           Arabic and English catalogs and their generated lookups
  money/          halalas, pending transfer, submission, wallet and history controllers
  screens/        account screens, wallet, send, review, result, history, account
  widgets/        shared fields, status banners, language choice, card carousel
  ui/             theme, text for outcomes, formatting of amounts and times
  dev/            contract fakes of the Money API and sign-in
contracts/        pins.yaml and pinned contract copies
tool/             coverage floor, C4 check, catalog check, no-logging check, contract pinning
test/             unit, widget, contract and accessibility tests
integration_test/ walking skeleton and U3 journeys
docs/             acceptance journey
```
