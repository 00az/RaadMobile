# RaadMobile

The RAAD digital wallet app for iOS and Android, in Flutter. Engineer 2 owns this repo. It calls the Money API in `RaadMoneyService` and signs in with the shared user pool from `Raad`.

U1 (the walking skeleton) covers:
- sign-in;
- the SAR balance;
- one simulated transfer to another RAAD wallet (form, review, confirm, result);
- the first page of history.

Everything is in English. Sign-up, Arabic and the other screens come in U3.

## Prerequisites

- **Flutter 3.47.2**, the version pinned in `pubspec.yaml`. The lockfile is committed.
- **Simulator and device runs:** Xcode with CocoaPods for iOS, and the Android SDK with an emulator for Android.
- **Changing a contract pin:** the `gh` CLI, signed in with your own GitHub access.

## Setup and checks

```sh
flutter pub get
flutter test --coverage && dart run tool/check_coverage.dart
```

CI runs the same checks on every pull request and every push to `main` (`.github/workflows/ci.yml`):

| Check | What it does |
|---|---|
| `dart format --set-exit-if-changed` | Fails on unformatted code. |
| `flutter analyze` | Runs the `flutter_lints` rules. Any issue fails. |
| `dart run swagger_parser --check` | Fails if the generated client differs from the pinned contract. |
| `flutter test --coverage` | Runs the unit, widget and contract tests. |
| Coverage floor | At least 80% line coverage of the app's own code. Generated client code is not counted. |
| C4 config check | Validates the example environment file. |
| gitleaks | Scans for committed secrets. |

## Running the app

The offline preview needs no network. It uses the local contract fake:

```sh
flutter run -t lib/main_fake.dart
```

Sign in as `sara@raad.test` with the password `Local-preview-1`, then send to `omar@raad.test`. These accounts exist only inside the fake.

To run against a real environment, give the build that environment's C4 file:

```sh
dart run tool/check_env_config.dart <c4-config.json> dev
flutter run --dart-define-from-file=<c4-config.json>
```

The C4 file holds non-secret deployment outputs. `config/c4-dev.example.json` shows its shape. The build refuses a file that:
- is missing a value or has an extra key;
- has a key that looks like a secret;
- names another environment.

Production builds also pass `--dart-define=RAAD_BUILD_ENVIRONMENT=prd`, so they accept only a `prd` file.

## API contract

The wire source of truth is the C1 OpenAPI file, pinned byte for byte at `contracts/pinned/c1-money-api/raad-money-v1.yaml`. Its source commit and SHA-256 are recorded in `contracts/pins.yaml`. A test fails if the copy changes. No release tag exists yet, so the pin is the development commit `5dd760d` from `RaadMoneyService` branch `aidlc/u1-contract-handoff`.

To move the pin once Engineer 1 tags a release:

```sh
dart run tool/pin_contract.dart c1-money-api contract/c1-money-api/v1.0.0-rc.1
dart run swagger_parser
flutter test
```

The tool checks the file against the SHA-256 in the tag message. Open a pull request with the new pin and the regenerated client together.

The Dart client under `lib/api/generated/` is generated from the pinned copy by `swagger_parser`. It is configured in `pubspec.yaml` and must never be edited by hand. There are no hand-written wire models.

## How the app uses the Money API in U1

| Flow | Request | Behavior |
|---|---|---|
| Wallet setup | `PUT /money/v1/wallet` | Runs on the first wallet load. `200` (existing) and `201` (created) are both success. On failure, the app shows Retry. |
| Balance | `GET /money/v1/wallet` | Used on refresh. It never creates a wallet: on `WALLET_NOT_FOUND` the app runs setup. |
| Recipient | `POST /money/v1/recipients/resolve` | Sends the normalized email in the body, never in a URL. An unknown address shows "No RAAD user has that address." (AC3.5.1). |
| Transfer | `POST /money/v1/transfers` | Sends `recipientEmail` and integer `amountHalalas`, plus a new `Idempotency-Key` for each review. The review screen shows the recipient, amount and balance after. Confirm works once per tap. Cancel sends nothing. A definite refusal returns to the form with the values kept. |
| History | `GET /money/v1/transfers` | Shows the first page only and never follows `nextCursor`. If another page exists, the app says it is showing the latest transfers. |

Other rules the app follows:
- **Errors** are flat: top-level `code`, `message` and `correlationId`. The app branches on `code` and shows its own text. A code it does not know gets the generic message.
- **Unknown transfer outcomes.** After a timeout, a lost answer, a `500`, a `503` or an undeclared status on a transfer, the outcome is unknown. The app does not send the transfer again, automatically or by the person. It sends them back to the wallet, which re-reads the balance and history.
- **Read retries.** Reads retry once after a timeout or `500`. They never retry `429` or `503`.
- **Money** is integer halalas everywhere. The app parses SAR text digit by digit and formats with integer arithmetic, never floating point.
- **Tokens and logging.** The access token goes only in `Authorization: Bearer`. Access and refresh tokens are kept only in secure storage. The app logs no requests, responses, tokens or personal details.

## Integration test

`integration_test/walking_skeleton_test.dart` runs the whole U1 journey on a simulator or emulator:
1. The sender signs in and sees their balance.
2. They review and send 100 SAR and see the result.
3. The sent entry shows in their history.
4. The recipient signs in and sees the same reference as received.

```sh
flutter test integration_test                      # against the contract fake
flutter test integration_test \
  --dart-define-from-file=<c4-dev.json> \
  --dart-define-from-file=<temporary-accounts.json>  # against dev
```

The dev run takes `RAAD_E2E_TARGET=dev` and the two test accounts from a temporary define file. The verification script writes that file from Secrets Manager and deletes it afterwards. Passwords never go on the command line or into the repo.

## Layout

```
lib/
  api/            Money API wrapper (money_service.dart); generated/ client
  auth/           sign-in interface, Cognito adapter, secure token store
  config/         C4 environment configuration
  money/          halalas parsing and formatting
  screens/        sign-in, wallet and history, send form, review, result
  dev/            contract fake of the Money API, and fake sign-in
contracts/        pins.yaml and pinned contract copies
tool/             coverage floor, C4 check, contract pinning
test/             unit, widget and contract tests
integration_test/ walking-skeleton journey
```
