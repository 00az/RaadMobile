// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RAAD';

  @override
  String get signInNoticeSessionEnded =>
      'Your session has ended. Sign in again.';

  @override
  String get signInNoticeIdle => 'For your security, please sign in again.';

  @override
  String get signInNoticeEmailConfirmed =>
      'Your email is confirmed. Please sign in.';

  @override
  String get signInNoticePasswordChanged =>
      'Your password was changed. Please sign in.';

  @override
  String get currencySar => 'SAR';

  @override
  String get tryAgain => 'Try again';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get notAvailableYet => 'Not available yet';

  @override
  String get offlineBanner =>
      'No connection. Check your network and try again.';

  @override
  String get walletTitle => 'RAAD WALLET';

  @override
  String get walletAccountType => 'Individual account';

  @override
  String get walletAvailableBalance => 'Available balance';

  @override
  String get walletBalanceHidden => 'Balance hidden';

  @override
  String get walletShowBalance => 'Show balance';

  @override
  String get walletHideBalance => 'Hide balance';

  @override
  String walletBalanceUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String walletBalanceStale(String time) {
    return 'Out of date. Last updated $time.';
  }

  @override
  String get walletBalanceError => 'We could not load your balance.';

  @override
  String walletBalanceSemantics(String amount) {
    return 'Balance, $amount';
  }

  @override
  String get walletActionSend => 'Send';

  @override
  String get walletActionTransactions => 'Transactions';

  @override
  String get walletActionAccount => 'Account';

  @override
  String get walletServices => 'Services';

  @override
  String get walletViewAll => 'View all';

  @override
  String get walletServiceRaad => 'Transfer to RAAD wallet';

  @override
  String get walletServiceInternational => 'International transfer';

  @override
  String get walletServiceBank => 'Local bank transfer';

  @override
  String get walletHistory => 'History';

  @override
  String get walletRecentActivity => 'Recent activity';

  @override
  String get walletSettingUp => 'Setting up your wallet…';

  @override
  String get walletSetupFailedTitle => 'We could not set up your wallet';

  @override
  String get walletSetupFailedBody => 'Nothing was lost. Please try again.';

  @override
  String get walletSetupEmailInUse =>
      'Your email address is already linked to another wallet. Contact RAAD support.';

  @override
  String get walletSendOffline => 'Sending needs a connection.';

  @override
  String get walletPendingTitle => 'A transfer may not have gone through';

  @override
  String walletPendingBody(String amount, String name) {
    return '$amount to $name. Review it before you send again.';
  }

  @override
  String get walletPendingReview => 'Review';

  @override
  String get genericError => 'Something went wrong. Try again.';

  @override
  String get networkError =>
      'We can\'t reach RAAD right now. Check your connection and try again.';

  @override
  String get tooManyAttempts =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String tooManyAttemptsSeconds(int seconds) {
    return 'Too many attempts. Try again in $seconds seconds.';
  }

  @override
  String get signInRefused => 'The email address or password is not correct.';

  @override
  String get emailInUse =>
      'This email address is already in use. Sign in instead?';

  @override
  String get passwordRule =>
      'At least 8 characters, with a lower-case letter, an upper-case letter and a digit.';

  @override
  String get passwordRuleBroken =>
      'The password needs at least 8 characters, a lower-case letter, an upper-case letter and a digit.';

  @override
  String get codeInvalid => 'This code is not valid. Check it and try again.';

  @override
  String get sendTitle => 'Send money';

  @override
  String get sendRecipientSection => 'Recipient';

  @override
  String get sendRecipientLabel => 'Recipient\'s email address';

  @override
  String get sendAmountSection => 'Transfer amount';

  @override
  String get sendAmountLabel => 'Amount (SAR)';

  @override
  String get sendAmountHint => 'From 1.00 to 500.00 SAR';

  @override
  String sendAvailable(String amount) {
    return 'Available: $amount';
  }

  @override
  String sendQuickAmount(String amount) {
    return 'Fill in $amount';
  }

  @override
  String get sendMax => 'Max';

  @override
  String sendMaxHint(String amount) {
    return 'Fill in the most you can send: $amount';
  }

  @override
  String sendDemoFill(String email) {
    return 'Demo: fill in $email';
  }

  @override
  String get sendContinue => 'Continue';

  @override
  String get sendEmailRequired => 'Enter the recipient\'s email address.';

  @override
  String get sendEmailInvalid => 'Enter a complete email address.';

  @override
  String get sendAmountRequired => 'Enter an amount.';

  @override
  String get sendAmountInvalid =>
      'Enter an amount in SAR with up to two decimals.';

  @override
  String get amountRange => 'The amount must be between 1.00 and 500.00 SAR.';

  @override
  String get balanceLow => 'Your balance is too low for this transfer.';

  @override
  String get ownAddress => 'You cannot send money to yourself.';

  @override
  String get noSuchUser => 'No RAAD user has this email address.';

  @override
  String get sendingNeedsConnection => 'Sending needs a connection.';

  @override
  String get checkHistoryFirst =>
      'Check your History first. Your earlier transfer may have gone through.';

  @override
  String get requestBlocked => 'This request was blocked. Try again later.';

  @override
  String get startNewTransfer =>
      'This transfer could not be sent. Start a new transfer.';

  @override
  String get checkDetails =>
      'Check the email address and amount, then try again.';

  @override
  String get reviewTitle => 'Review transfer';

  @override
  String get reviewTo => 'To';

  @override
  String get reviewEmail => 'Email';

  @override
  String get reviewAmount => 'Amount';

  @override
  String get reviewBalanceAfter => 'Balance after';

  @override
  String get reviewConfirm => 'Confirm and send';

  @override
  String get reviewSending => 'Sending…';

  @override
  String get reviewCancel => 'Cancel';

  @override
  String get reviewWalletReady =>
      'Your wallet is ready now. Tap Confirm to send.';

  @override
  String get reviewNotSent =>
      'The transfer was not sent. Check your connection and confirm again.';

  @override
  String get reviewNotSaved =>
      'The transfer was not sent because it could not be saved safely on this phone. Try again.';

  @override
  String get transferUnconfirmedTitle => 'We could not confirm the transfer';

  @override
  String get transferUnconfirmedBody =>
      'Your money may or may not have been sent. Check your History before you try again.';

  @override
  String get uncertainCheck => 'Check my balance and history';

  @override
  String get uncertainTryAgain => 'Try again with the same details';

  @override
  String get uncertainTryAgainNote =>
      'Try again sends the same request. If the first one went through, the money moves only once.';

  @override
  String get uncertainChangeDetails => 'Change details';

  @override
  String get resultTitle => 'Transfer sent';

  @override
  String resultSummary(String amount, String name) {
    return 'You sent $amount to $name.';
  }

  @override
  String get resultReference => 'Reference';

  @override
  String get resultNewBalance => 'New balance';

  @override
  String get resultDone => 'Done';

  @override
  String historySentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String historyReceivedFrom(String name) {
    return 'Received from $name';
  }

  @override
  String historyReference(String reference) {
    return 'Ref $reference';
  }

  @override
  String historyEntrySemantics(
    String title,
    String email,
    String amount,
    String time,
    String reference,
  ) {
    return '$title, $email, $amount, $time, reference $reference';
  }

  @override
  String get historyEmpty => 'No transfers yet.';

  @override
  String get historyError => 'We could not load your history.';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String get historyLoadMoreFailed => 'We could not load more. Try again.';

  @override
  String get historyRestarted =>
      'Your history was reloaded from the newest transfer because the list had expired.';

  @override
  String get historySeeAll => 'See all';

  @override
  String get historyCheck => 'Check my history';

  @override
  String get historyEnd => 'That is all your transfers.';

  @override
  String get logoLabel => 'RAAD';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInTagline => 'Lightning-fast digital transfers';

  @override
  String get signInSubmit => 'Sign in';

  @override
  String get signInBusy => 'Signing in…';

  @override
  String get signInForgot => 'Forgot password?';

  @override
  String get signInNewToRaad => 'New to RAAD?';

  @override
  String get signInCreateAccount => 'Create an account';

  @override
  String get signInHaveCode => 'Have a confirmation code?';

  @override
  String get signInEmailRequired => 'Enter your email address.';

  @override
  String get signInEmailInvalid => 'Enter a valid email address.';

  @override
  String get signInPasswordRequired => 'Enter your password.';

  @override
  String get signInDemoFill => 'Demo: fill in Sara';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpDisplayName => 'Display name';

  @override
  String get signUpDisplayNameRequired => 'Enter a display name.';

  @override
  String get signUpSubmit => 'Create account';

  @override
  String get signUpBusy => 'Creating your account…';

  @override
  String get signUpSignInInstead => 'Sign in instead';

  @override
  String get signUpPrivacy =>
      'We keep only your email address and display name. RAAD never asks for card or bank details.';

  @override
  String get confirmTitle => 'Confirm your email';

  @override
  String get confirmIntro =>
      'We sent a code to your email address. Enter it below.';

  @override
  String get confirmCode => 'Confirmation code';

  @override
  String get confirmCodeRequired => 'Enter the code from the email.';

  @override
  String get confirmSubmit => 'Confirm';

  @override
  String get confirmBusy => 'Confirming…';

  @override
  String get confirmResend => 'Send the code again';

  @override
  String get codeResent => 'We sent a new code.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotIntro =>
      'Enter your email address and we will send you a code.';

  @override
  String get forgotSubmit => 'Send code';

  @override
  String get forgotBusy => 'Sending…';

  @override
  String get resetCodeSent =>
      'If an account exists for this address, we sent a code.';

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetCode => 'Code';

  @override
  String get resetNewPassword => 'New password';

  @override
  String get resetSubmit => 'Change password';

  @override
  String get resetBusy => 'Changing your password…';

  @override
  String get resetUncertain =>
      'We could not confirm whether your password changed. Try signing in with the new password. If that does not work, ask for a new code.';

  @override
  String get resetGoToSignIn => 'Go to sign in';

  @override
  String get resetNewCode => 'Ask for a new code';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountLanguage => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get cardsTitle => 'My cards';

  @override
  String get cardsPreview => 'Virtual card design';

  @override
  String get cardsDemo => 'Demo card';

  @override
  String get cardsVirtualCard => 'Virtual card';

  @override
  String get cardsSilver => 'Silver';

  @override
  String get cardsGold => 'Gold';

  @override
  String get cardsPlatinum => 'Platinum';

  @override
  String get configErrorTitle =>
      'This build has no valid environment configuration.';
}
