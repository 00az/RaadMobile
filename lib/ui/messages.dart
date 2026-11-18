/// The app's own text for every outcome, in the person's language. Screens
/// branch on stable codes and never show provider or server message text;
/// an `Error.code` this version does not know gets the generic message, as
/// C1 asks.
library;

import '../api/money_service.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';

abstract final class Messages {
  static String forAuthFailure(AppLocalizations l10n, AuthFailureCode code) =>
      switch (code) {
        AuthFailureCode.signInFailed => l10n.signInRefused,
        AuthFailureCode.rateLimited => l10n.tooManyAttempts,
        AuthFailureCode.network => l10n.networkError,
        AuthFailureCode.sessionExpired => l10n.signInNoticeSessionEnded,
        AuthFailureCode.emailInUse => l10n.emailInUse,
        AuthFailureCode.passwordRuleFailed => l10n.passwordRuleBroken,
        AuthFailureCode.codeInvalidOrExpired => l10n.codeInvalid,
        AuthFailureCode.failed => l10n.genericError,
      };

  /// Text for a Money API refusal.
  static String forMoneyError(AppLocalizations l10n, MoneyApiException error) {
    final code = error.code;
    if (code == MoneyErrorCode.recipientNotFound) return l10n.noSuchUser;
    if (code == MoneyErrorCode.selfTransfer) return l10n.ownAddress;
    if (code == MoneyErrorCode.insufficientFunds) return l10n.balanceLow;
    if (code == MoneyErrorCode.amountOutOfRange) return l10n.amountRange;
    if (code == MoneyErrorCode.validation) return l10n.checkDetails;
    if (error.isRateLimited) return rateLimited(l10n, error.retryAfter);
    if (code == MoneyErrorCode.forbidden) return l10n.requestBlocked;
    if (code == MoneyErrorCode.idempotencyKeyReused) {
      return l10n.startNewTransfer;
    }
    if (error.isAuthenticationRequired) return l10n.signInNoticeSessionEnded;
    if (code == MoneyErrorCode.network) return l10n.networkError;
    return l10n.genericError;
  }

  /// A rate limit, with the wait from `Retry-After` when the service gave
  /// one.
  static String rateLimited(AppLocalizations l10n, Duration? retryAfter) =>
      retryAfter == null
      ? l10n.tooManyAttempts
      : l10n.tooManyAttemptsSeconds(retryAfter.inSeconds);
}
