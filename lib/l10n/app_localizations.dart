import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RAAD'**
  String get appTitle;

  /// No description provided for @signInNoticeSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again.'**
  String get signInNoticeSessionEnded;

  /// No description provided for @signInNoticeIdle.
  ///
  /// In en, this message translates to:
  /// **'For your security, please sign in again.'**
  String get signInNoticeIdle;

  /// No description provided for @signInNoticeEmailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your email is confirmed. Please sign in.'**
  String get signInNoticeEmailConfirmed;

  /// No description provided for @signInNoticePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. Please sign in.'**
  String get signInNoticePasswordChanged;

  /// No description provided for @currencySar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currencySar;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @notAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get notAvailableYet;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get offlineBanner;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'RAAD WALLET'**
  String get walletTitle;

  /// No description provided for @walletAccountType.
  ///
  /// In en, this message translates to:
  /// **'Individual account'**
  String get walletAccountType;

  /// No description provided for @walletAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get walletAvailableBalance;

  /// No description provided for @walletBalanceHidden.
  ///
  /// In en, this message translates to:
  /// **'Balance hidden'**
  String get walletBalanceHidden;

  /// No description provided for @walletShowBalance.
  ///
  /// In en, this message translates to:
  /// **'Show balance'**
  String get walletShowBalance;

  /// No description provided for @walletHideBalance.
  ///
  /// In en, this message translates to:
  /// **'Hide balance'**
  String get walletHideBalance;

  /// No description provided for @walletBalanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String walletBalanceUpdated(String time);

  /// No description provided for @walletBalanceStale.
  ///
  /// In en, this message translates to:
  /// **'Out of date. Last updated {time}.'**
  String walletBalanceStale(String time);

  /// No description provided for @walletBalanceError.
  ///
  /// In en, this message translates to:
  /// **'We could not load your balance.'**
  String get walletBalanceError;

  /// No description provided for @walletBalanceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Balance, {amount}'**
  String walletBalanceSemantics(String amount);

  /// No description provided for @walletActionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get walletActionSend;

  /// No description provided for @walletActionTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletActionTransactions;

  /// No description provided for @walletActionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get walletActionAccount;

  /// No description provided for @walletServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get walletServices;

  /// No description provided for @walletViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get walletViewAll;

  /// No description provided for @walletServiceRaad.
  ///
  /// In en, this message translates to:
  /// **'Transfer to RAAD wallet'**
  String get walletServiceRaad;

  /// No description provided for @walletServiceInternational.
  ///
  /// In en, this message translates to:
  /// **'International transfer'**
  String get walletServiceInternational;

  /// No description provided for @walletServiceBank.
  ///
  /// In en, this message translates to:
  /// **'Local bank transfer'**
  String get walletServiceBank;

  /// No description provided for @walletHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get walletHistory;

  /// No description provided for @walletRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get walletRecentActivity;

  /// No description provided for @walletSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up your wallet…'**
  String get walletSettingUp;

  /// No description provided for @walletSetupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not set up your wallet'**
  String get walletSetupFailedTitle;

  /// No description provided for @walletSetupFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was lost. Please try again.'**
  String get walletSetupFailedBody;

  /// No description provided for @walletSetupEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'Your email address is already linked to another wallet. Contact RAAD support.'**
  String get walletSetupEmailInUse;

  /// No description provided for @walletSendOffline.
  ///
  /// In en, this message translates to:
  /// **'Sending needs a connection.'**
  String get walletSendOffline;

  /// No description provided for @walletPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'A transfer may not have gone through'**
  String get walletPendingTitle;

  /// No description provided for @walletPendingBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} to {name}. Review it before you send again.'**
  String walletPendingBody(String amount, String name);

  /// No description provided for @walletPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get walletPendingReview;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get genericError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach RAAD right now. Check your connection and try again.'**
  String get networkError;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get tooManyAttempts;

  /// No description provided for @tooManyAttemptsSeconds.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} seconds.'**
  String tooManyAttemptsSeconds(int seconds);

  /// No description provided for @signInRefused.
  ///
  /// In en, this message translates to:
  /// **'The email address or password is not correct.'**
  String get signInRefused;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email address is already in use. Sign in instead?'**
  String get emailInUse;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with a lower-case letter, an upper-case letter and a digit.'**
  String get passwordRule;

  /// No description provided for @passwordRuleBroken.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 8 characters, a lower-case letter, an upper-case letter and a digit.'**
  String get passwordRuleBroken;

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code is not valid. Check it and try again.'**
  String get codeInvalid;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send money'**
  String get sendTitle;

  /// No description provided for @sendRecipientSection.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get sendRecipientSection;

  /// No description provided for @sendRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s email address'**
  String get sendRecipientLabel;

  /// No description provided for @sendAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Transfer amount'**
  String get sendAmountSection;

  /// No description provided for @sendAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (SAR)'**
  String get sendAmountLabel;

  /// No description provided for @sendAmountHint.
  ///
  /// In en, this message translates to:
  /// **'From 1.00 to 500.00 SAR'**
  String get sendAmountHint;

  /// No description provided for @sendAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount}'**
  String sendAvailable(String amount);

  /// No description provided for @sendQuickAmount.
  ///
  /// In en, this message translates to:
  /// **'Fill in {amount}'**
  String sendQuickAmount(String amount);

  /// No description provided for @sendMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get sendMax;

  /// No description provided for @sendMaxHint.
  ///
  /// In en, this message translates to:
  /// **'Fill in the most you can send: {amount}'**
  String sendMaxHint(String amount);

  /// No description provided for @sendDemoFill.
  ///
  /// In en, this message translates to:
  /// **'Demo: fill in {email}'**
  String sendDemoFill(String email);

  /// No description provided for @sendContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sendContinue;

  /// No description provided for @sendEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the recipient\'s email address.'**
  String get sendEmailRequired;

  /// No description provided for @sendEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete email address.'**
  String get sendEmailInvalid;

  /// No description provided for @sendAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get sendAmountRequired;

  /// No description provided for @sendAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount in SAR with up to two decimals.'**
  String get sendAmountInvalid;

  /// No description provided for @amountRange.
  ///
  /// In en, this message translates to:
  /// **'The amount must be between 1.00 and 500.00 SAR.'**
  String get amountRange;

  /// No description provided for @balanceLow.
  ///
  /// In en, this message translates to:
  /// **'Your balance is too low for this transfer.'**
  String get balanceLow;

  /// No description provided for @ownAddress.
  ///
  /// In en, this message translates to:
  /// **'You cannot send money to yourself.'**
  String get ownAddress;

  /// No description provided for @noSuchUser.
  ///
  /// In en, this message translates to:
  /// **'No RAAD user has this email address.'**
  String get noSuchUser;

  /// No description provided for @sendingNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Sending needs a connection.'**
  String get sendingNeedsConnection;

  /// No description provided for @checkHistoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Check your History first. Your earlier transfer may have gone through.'**
  String get checkHistoryFirst;

  /// No description provided for @requestBlocked.
  ///
  /// In en, this message translates to:
  /// **'This request was blocked. Try again later.'**
  String get requestBlocked;

  /// No description provided for @startNewTransfer.
  ///
  /// In en, this message translates to:
  /// **'This transfer could not be sent. Start a new transfer.'**
  String get startNewTransfer;

  /// No description provided for @checkDetails.
  ///
  /// In en, this message translates to:
  /// **'Check the email address and amount, then try again.'**
  String get checkDetails;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get reviewTitle;

  /// No description provided for @reviewTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reviewTo;

  /// No description provided for @reviewEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get reviewEmail;

  /// No description provided for @reviewAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reviewAmount;

  /// No description provided for @reviewBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance after'**
  String get reviewBalanceAfter;

  /// No description provided for @reviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and send'**
  String get reviewConfirm;

  /// No description provided for @reviewSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get reviewSending;

  /// No description provided for @reviewCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get reviewCancel;

  /// No description provided for @reviewWalletReady.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is ready now. Tap Confirm to send.'**
  String get reviewWalletReady;

  /// No description provided for @reviewNotSent.
  ///
  /// In en, this message translates to:
  /// **'The transfer was not sent. Check your connection and confirm again.'**
  String get reviewNotSent;

  /// No description provided for @reviewNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The transfer was not sent because it could not be saved safely on this phone. Try again.'**
  String get reviewNotSaved;

  /// No description provided for @transferUnconfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm the transfer'**
  String get transferUnconfirmedTitle;

  /// No description provided for @transferUnconfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'Your money may or may not have been sent. Check your History before you try again.'**
  String get transferUnconfirmedBody;

  /// No description provided for @uncertainCheck.
  ///
  /// In en, this message translates to:
  /// **'Check my balance and history'**
  String get uncertainCheck;

  /// No description provided for @uncertainTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again with the same details'**
  String get uncertainTryAgain;

  /// No description provided for @uncertainTryAgainNote.
  ///
  /// In en, this message translates to:
  /// **'Try again sends the same request. If the first one went through, the money moves only once.'**
  String get uncertainTryAgainNote;

  /// No description provided for @uncertainChangeDetails.
  ///
  /// In en, this message translates to:
  /// **'Change details'**
  String get uncertainChangeDetails;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer sent'**
  String get resultTitle;

  /// No description provided for @resultSummary.
  ///
  /// In en, this message translates to:
  /// **'You sent {amount} to {name}.'**
  String resultSummary(String amount, String name);

  /// No description provided for @resultReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get resultReference;

  /// No description provided for @resultNewBalance.
  ///
  /// In en, this message translates to:
  /// **'New balance'**
  String get resultNewBalance;

  /// No description provided for @resultDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get resultDone;

  /// No description provided for @historySentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String historySentTo(String name);

  /// No description provided for @historyReceivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String historyReceivedFrom(String name);

  /// No description provided for @historyReference.
  ///
  /// In en, this message translates to:
  /// **'Ref {reference}'**
  String historyReference(String reference);

  /// No description provided for @historyEntrySemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}, {email}, {amount}, {time}, reference {reference}'**
  String historyEntrySemantics(
    String title,
    String email,
    String amount,
    String time,
    String reference,
  );

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transfers yet.'**
  String get historyEmpty;

  /// No description provided for @historyError.
  ///
  /// In en, this message translates to:
  /// **'We could not load your history.'**
  String get historyError;

  /// No description provided for @historyLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get historyLoadMore;

  /// No description provided for @historyLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load more. Try again.'**
  String get historyLoadMoreFailed;

  /// No description provided for @historyRestarted.
  ///
  /// In en, this message translates to:
  /// **'Your history was reloaded from the newest transfer because the list had expired.'**
  String get historyRestarted;

  /// No description provided for @historySeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get historySeeAll;

  /// No description provided for @historyCheck.
  ///
  /// In en, this message translates to:
  /// **'Check my history'**
  String get historyCheck;

  /// No description provided for @historyEnd.
  ///
  /// In en, this message translates to:
  /// **'That is all your transfers.'**
  String get historyEnd;

  /// No description provided for @logoLabel.
  ///
  /// In en, this message translates to:
  /// **'RAAD'**
  String get logoLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInTagline.
  ///
  /// In en, this message translates to:
  /// **'Lightning-fast digital transfers'**
  String get signInTagline;

  /// No description provided for @signInSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInSubmit;

  /// No description provided for @signInBusy.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signInBusy;

  /// No description provided for @signInForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgot;

  /// No description provided for @signInNewToRaad.
  ///
  /// In en, this message translates to:
  /// **'New to RAAD?'**
  String get signInNewToRaad;

  /// No description provided for @signInCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signInCreateAccount;

  /// No description provided for @signInHaveCode.
  ///
  /// In en, this message translates to:
  /// **'Have a confirmation code?'**
  String get signInHaveCode;

  /// No description provided for @signInEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get signInEmailRequired;

  /// No description provided for @signInEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get signInEmailInvalid;

  /// No description provided for @signInPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get signInPasswordRequired;

  /// No description provided for @signInDemoFill.
  ///
  /// In en, this message translates to:
  /// **'Demo: fill in Sara'**
  String get signInDemoFill;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @signUpDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get signUpDisplayName;

  /// No description provided for @signUpDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name.'**
  String get signUpDisplayNameRequired;

  /// No description provided for @signUpSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpSubmit;

  /// No description provided for @signUpBusy.
  ///
  /// In en, this message translates to:
  /// **'Creating your account…'**
  String get signUpBusy;

  /// No description provided for @signUpSignInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in instead'**
  String get signUpSignInInstead;

  /// No description provided for @signUpPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We keep only your email address and display name. RAAD never asks for card or bank details.'**
  String get signUpPrivacy;

  /// No description provided for @confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmTitle;

  /// No description provided for @confirmIntro.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to your email address. Enter it below.'**
  String get confirmIntro;

  /// No description provided for @confirmCode.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code'**
  String get confirmCode;

  /// No description provided for @confirmCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the email.'**
  String get confirmCodeRequired;

  /// No description provided for @confirmSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmSubmit;

  /// No description provided for @confirmBusy.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get confirmBusy;

  /// No description provided for @confirmResend.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get confirmResend;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'We sent a new code.'**
  String get codeResent;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a code.'**
  String get forgotIntro;

  /// No description provided for @forgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotSubmit;

  /// No description provided for @forgotBusy.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get forgotBusy;

  /// No description provided for @resetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this address, we sent a code.'**
  String get resetCodeSent;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get resetCode;

  /// No description provided for @resetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewPassword;

  /// No description provided for @resetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get resetSubmit;

  /// No description provided for @resetBusy.
  ///
  /// In en, this message translates to:
  /// **'Changing your password…'**
  String get resetBusy;

  /// No description provided for @resetUncertain.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm whether your password changed. Try signing in with the new password. If that does not work, ask for a new code.'**
  String get resetUncertain;

  /// No description provided for @resetGoToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get resetGoToSignIn;

  /// No description provided for @resetNewCode.
  ///
  /// In en, this message translates to:
  /// **'Ask for a new code'**
  String get resetNewCode;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @cardsTitle.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get cardsTitle;

  /// No description provided for @cardsPreview.
  ///
  /// In en, this message translates to:
  /// **'Virtual card design'**
  String get cardsPreview;

  /// No description provided for @cardsDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo card'**
  String get cardsDemo;

  /// No description provided for @cardsVirtualCard.
  ///
  /// In en, this message translates to:
  /// **'Virtual card'**
  String get cardsVirtualCard;

  /// No description provided for @cardsSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get cardsSilver;

  /// No description provided for @cardsGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get cardsGold;

  /// No description provided for @cardsPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get cardsPlatinum;

  /// No description provided for @configErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'This build has no valid environment configuration.'**
  String get configErrorTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
