/// The app's own English text for every outcome. Screens branch on codes and
/// never show provider or server message text.
library;

import '../api/money_service.dart';
import '../auth/auth_service.dart';

abstract final class Messages {
  static const signInFailed =
      "We couldn't sign you in. Check your email and password.";
  static const signInRateLimited =
      'Too many attempts. Wait a few minutes, then try again.';
  static const network =
      "We can't reach RAAD right now. Check your connection and try again.";
  static const sessionExpired = 'Your session has ended. Sign in again.';

  static const recipientNotFound = 'No RAAD user has that address.';
  static const selfTransfer = "You can't send money to your own wallet.";
  static const insufficientFunds = 'Your balance is too low for this amount.';
  static const amountOutOfRange =
      'Enter an amount between 1.00 and 500.00 SAR.';
  static const checkDetails =
      'Check the email address and amount, then try again.';
  static const rateLimited =
      'Too many requests. Wait a moment, then try again.';
  static const blocked = 'This request was blocked. Try again later.';
  static const startNewTransfer =
      'This transfer could not be sent. Start a new transfer.';
  static const generic = 'Something went wrong. Try again.';

  static const walletSetupFailed = "We couldn't set up your wallet.";
  static const walletEmailInUse =
      'Your email address is already linked to another wallet. '
      'Contact RAAD support.';
  static const walletReadyConfirmAgain =
      'Your wallet is ready now. Tap Confirm to send.';

  static const outcomeUnknownTitle = "We couldn't confirm this transfer";
  static const outcomeUnknownBody =
      'It may or may not have gone through. Check your balance and history '
      'before you send again.';

  static String forAuthFailure(AuthFailureCode code) => switch (code) {
    AuthFailureCode.signInFailed => signInFailed,
    AuthFailureCode.rateLimited => signInRateLimited,
    AuthFailureCode.network => network,
    AuthFailureCode.sessionExpired => sessionExpired,
  };

  /// Text for a Money API refusal. A code this app version does not know
  /// falls back to the generic message, as C1 asks.
  static String forMoneyError(MoneyApiException error) {
    final code = error.code;
    if (code == MoneyErrorCode.recipientNotFound) return recipientNotFound;
    if (code == MoneyErrorCode.selfTransfer) return selfTransfer;
    if (code == MoneyErrorCode.insufficientFunds) return insufficientFunds;
    if (code == MoneyErrorCode.amountOutOfRange) return amountOutOfRange;
    if (code == MoneyErrorCode.validation) return checkDetails;
    if (code == MoneyErrorCode.rateLimited) return rateLimited;
    if (code == MoneyErrorCode.forbidden) return blocked;
    if (code == MoneyErrorCode.idempotencyKeyReused) return startNewTransfer;
    if (code == MoneyErrorCode.authenticationRequired) return sessionExpired;
    if (code == MoneyErrorCode.network) return network;
    return generic;
  }
}
