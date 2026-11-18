# RAAD MVP acceptance journey

This is the written procedure the Demo Reviewer follows to accept the RAAD MVP against the SOW's six success criteria (US6.4, AC6.4.1 to AC6.4.3; rule BR3.8). It is a procedure, not a record: nothing in this file has been run, and no result is claimed here. Each run writes its own evidence, as listed in each step.

The SOW's six success criteria:

1. Secure sign-in.
2. A transfer to another wallet.
3. A correct balance after the transfer.
4. A refused duplicate.
5. A visible history.
6. The application runs on AWS.

## Before you start

| Item | What is needed |
|---|---|
| Environment | `prd` for the formal acceptance (AC6.4.1). The same journey is first run on `dev` and then `stg`; `prd` is only deployed after the version passed on `stg` and a person approved the `prd` deploy (AC6.4.3). |
| App builds | The tester build of the environment's flavour from TestFlight (iOS) and Google Play internal testing (Android), built with that environment's C4 file: `flutter build ipa --flavor prd --dart-define-from-file=<c4-prd.json>` and `flutter build appbundle --flavor prd --dart-define-from-file=<c4-prd.json>`. Record the app version, build number and source commit. |
| Accounts | Two **new** test accounts, A and B, created during the journey with addresses the reviewer can receive mail at. No existing account is reused, so the opening credit is observable. |
| Revisions | Record the commit of each repo deployed to the environment (`Raad`, `RaadMoneyService`, `RaadMobile`), the pinned C1 version and the C4 `configVersion`. |
| Evidence folder | One folder per run, named `<environment>-<date>`, kept with the release record. Screenshots and screen recordings must not show passwords or confirmation codes. |

Never paste a password, a confirmation code or a token into the evidence, a chat or a command line.

## Step 1: The app runs against the environment, on AWS (criterion 6)

1. Install the tester build on one iPhone and one Android phone.
2. Open it. Check that a `DEV` or `STG` chip shows in those environments and that none shows in `prd`.
3. From a computer, run the environment's API smoke test from its pipeline (the post-deploy smoke test of `Raad` and of `RaadMoneyService`) and keep its log.

**Proves:** the build is tied to this environment only (AC6.2.2) and the platform and money service answer from AWS in that environment.
**Evidence:** screenshot of the sign-in screen with the chip (or its absence in `prd`); the smoke-test log with the run URL; the deployed commits.

## Step 2: Create two accounts and sign in securely (criterion 1)

1. On the iPhone, tap **Create an account**. Enter display name "Acceptance A", account A's address and a password that follows the rule shown under the field.
2. Try once with `abcdef12` as the password first: sign-up is refused with the rule (AC1.1.3).
3. Enter the emailed code on **Confirm your email**. Check that **Send the code again** shows "We sent a new code." and that the first code then no longer works (AC1.2.6).
4. Sign in as A. Then sign out from **Account**, and try signing in with a wrong password: the message is "The email address or password is not correct." Sign in again correctly.
5. Repeat sign-up and confirmation for account B on the Android phone.

**Proves:** accounts need a confirmed address and the password rule; a wrong password reveals nothing about the account; sign-in reaches the wallet only through the environment's own user pool.
**Evidence:** screenshots of the refusals and of the confirmation note (no codes visible); the time of each sign-in.

## Step 3: The opening credit is 1,000.00 SAR, once (AC1.2.3, AC6.4.2)

1. After A's first sign-in the wallet shows **1,000.00 SAR**.
2. Sign out and sign in again as A. The balance is still 1,000.00 SAR.
3. Check B the same way on Android.

**Proves:** each new wallet starts with 1,000.00 simulated SAR, credited once, also in `prd` (the person's decision, message 77a32fc9).
**Evidence:** wallet screenshots for A and B after the first and the second sign-in.

## Step 4: Send money to another wallet (criterion 2)

1. As A on the iPhone, tap **Send**. Enter B's address and **100**. Tap **Continue**.
2. The review screen shows B's display name and address, **100.00 SAR** and **Balance after 900.00 SAR**. Tap **Confirm and send** once.
3. The result screen shows **You sent 100.00 SAR to Acceptance B**, a reference, and **New balance 900.00 SAR**.

**Proves:** a transfer to another RAAD wallet completes after review, and the app shows the authoritative balance after it.
**Evidence:** screenshots of the review and result screens; the reference.

## Step 5: The balances are correct (criterion 3)

1. Tap **Done**. A's wallet shows **900.00 SAR**.
2. On the Android phone, as B, tap **Refresh**. B's wallet shows **1,100.00 SAR**.
3. Try to send **500.01** from A: the form refuses it with the limits before any request. Try to send more than A holds after a few transfers: "Your balance is too low for this transfer."

**Proves:** the sender's balance falls and the recipient's rises by exactly the amount, nothing else changes, and the limits and balance rules hold.
**Evidence:** wallet screenshots of A and B with times.

## Step 6: A duplicate is refused, and a replay moves money once (criterion 4)

The app makes one request key per confirmed transfer, so a person cannot send a duplicate by tapping twice. The service-side checks are proved directly against the API.

1. As A, review a transfer of **10** to B and tap **Confirm and send** twice quickly. One transfer completes; the balance falls by 10.00 SAR once.
2. Run `RaadMoneyService`'s replay check against the environment (the provider test that sends the same request twice with the same `Idempotency-Key`): the second answer is the first result with `Idempotency-Replayed: true`, and money moves once. The same key with a different amount is refused with `IDEMPOTENCY_KEY_REUSED`.
3. On `dev` or `stg` only, where a network fault can be arranged: put the phone in airplane mode just after tapping **Confirm and send**. The app says **We could not confirm the transfer** and sends nothing by itself. Turn the network back on and tap **Try again with the same details**: the same transfer is returned and the balance falls once.

**Proves:** a repeated request is refused or replayed without moving money twice, and the app never sends a transfer again on its own.
**Evidence:** A's balance before and after; the API check's output with request and correlation IDs (no tokens); screenshots of the uncertain and result screens.

## Step 7: The history is visible (criterion 5)

1. As A, open **Transactions** (or **See all**). The transfers to B show as **Sent to Acceptance B**, with B's address, the amount with a minus sign, the reference from Step 4 and the local time.
2. As B, they show as **Received from Acceptance A** with a plus sign and the same references.
3. Pull down to refresh; the order does not change. If there are more than 20 entries, **Load more** adds the next page with no entry repeated.

**Proves:** each completed transfer appears once in both people's history, with matching references; refused transfers do not appear.
**Evidence:** history screenshots for A and B.

## Step 8: Arabic and accessibility spot checks

1. On **Account**, choose **العربية**. Every screen switches to Arabic, right to left, without signing in again; amounts read `900.00 ر.س` with Western digits.
2. With VoiceOver (iOS) and TalkBack (Android), sign in, read the balance and send a transfer.
3. With system text at 200%, check that every control on sign-in, wallet, send and review is still visible and usable.

**Proves:** US5.1 and US5.2 on real devices. These are release evidence the automated tests cannot give.
**Evidence:** screen recordings with the reader's speech, kept without any password or code.

## Recording the result

For each step write **passed**, **failed** (with what was seen) or **not run** (with the reason) in the run's evidence folder, with the environment, the device and OS versions, the app version and build, and the deployed commits. Results from the local contract fakes or from `dev` do not stand in for `prd`, and an iOS result does not stand in for Android. The MVP is accepted when every step passes on `prd` and the reviewer signs the record.
