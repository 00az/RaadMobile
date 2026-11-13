# RaadMobile — U1 co-engineer handoff

This repository is owned by Engineer 2. It contains the RAAD Flutter app for iOS and Android. The U1 mobile work is being developed separately from `Raad` and `RaadMoneyService` so the engineers can work side by side.

## U1 goal

Build the walking-skeleton flow: a signed-in user sees their SAR wallet balance, resolves another user by email, reviews and confirms one simulated transfer, sees the result, and sees the transfer in the first history page.

## API contract

Use the pinned OpenAPI contract at `../money-service/openapi/raad-money-v1.yaml` as the wire source of truth. Configure the API base URL per environment; do not hard-code a public hostname. Send the Cognito access token as `Authorization: Bearer <token>` on every Money API request. Do not send identity fields to select the caller; the service derives the caller from the verified token.

All amounts are integer halalas. Display `amountHalalas / 100` as SAR with two decimal places. Never use floating point for money calculations; parse user-entered decimal text into whole halalas.

U1 calls:

| Flow | Request | U1 behavior |
|---|---|---|
| Ensure wallet | `PUT /money/v1/wallet` | Safe setup call; accept `200` (existing wallet) or `201` (created). |
| Read balance | `GET /money/v1/wallet` | Show `balance.amountHalalas` and `balance.currency` (`SAR`). |
| Resolve recipient | `POST /money/v1/recipients/resolve` with `{"email":"..."}` | Show returned `displayName` and normalized `email` on review. A not-found message must not disclose whether the email is registered. |
| Send transfer | `POST /money/v1/transfers` with `recipientEmail` and integer `amountHalalas`; include an `Idempotency-Key` header | Show recipient, amount and projected balance before confirmation. Disable repeat taps while sending; show the returned reference and balance after success. Preserve form values on a business refusal. |
| First history page | `GET /money/v1/transfers` | Show returned entries and sent/received direction. U1 uses the first page only; cursor pagination belongs to U2. |

Treat errors by status and the response `error.code`, not by parsing the English message. Never log access tokens, passwords, personal details or full recipient email addresses.

## Suggested app structure

Keep authentication/session, API client, money parsing/formatting and screens separate enough to test independently. The minimum screens are sign-in, wallet/balance, recipient entry, transfer review/confirmation, transfer result and history. Require an explicit confirmation tap before sending money. Cancellation sends no transfer request.

## Setup and checks
