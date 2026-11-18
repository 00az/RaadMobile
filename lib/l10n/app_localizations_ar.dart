// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'رعد';

  @override
  String get signInNoticeSessionEnded => 'انتهت جلستك. سجّل الدخول مرة أخرى.';

  @override
  String get signInNoticeIdle => 'لحمايتك، يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get signInNoticeEmailConfirmed =>
      'تم تأكيد بريدك الإلكتروني. يرجى تسجيل الدخول.';

  @override
  String get signInNoticePasswordChanged =>
      'تم تغيير كلمة المرور. يرجى تسجيل الدخول.';

  @override
  String get currencySar => 'ر.س';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get refresh => 'تحديث';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get notAvailableYet => 'غير متاح بعد';

  @override
  String get offlineBanner => 'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى.';

  @override
  String get walletTitle => 'محفظة رعد';

  @override
  String get walletAccountType => 'حساب فردي';

  @override
  String get walletAvailableBalance => 'الرصيد المتاح';

  @override
  String get walletBalanceHidden => 'الرصيد مخفي';

  @override
  String get walletShowBalance => 'إظهار الرصيد';

  @override
  String get walletHideBalance => 'إخفاء الرصيد';

  @override
  String walletBalanceUpdated(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String walletBalanceStale(String time) {
    return 'غير محدّث. آخر تحديث $time.';
  }

  @override
  String get walletBalanceError => 'تعذر تحميل الرصيد.';

  @override
  String walletBalanceSemantics(String amount) {
    return 'الرصيد، $amount';
  }

  @override
  String get walletActionSend => 'إرسال';

  @override
  String get walletActionTransactions => 'المعاملات';

  @override
  String get walletActionAccount => 'الحساب';

  @override
  String get walletServices => 'الخدمات';

  @override
  String get walletViewAll => 'عرض الكل';

  @override
  String get walletServiceRaad => 'تحويل إلى محفظة رعد';

  @override
  String get walletServiceInternational => 'تحويل دولي';

  @override
  String get walletServiceBank => 'تحويل بنكي محلي';

  @override
  String get walletHistory => 'السجل';

  @override
  String get walletRecentActivity => 'آخر العمليات';

  @override
  String get walletSettingUp => 'جارٍ إعداد محفظتك…';

  @override
  String get walletSetupFailedTitle => 'تعذر إعداد محفظتك';

  @override
  String get walletSetupFailedBody => 'لم يُفقد شيء. يرجى المحاولة مرة أخرى.';

  @override
  String get walletSetupEmailInUse =>
      'بريدك الإلكتروني مرتبط بمحفظة أخرى. تواصل مع دعم رعد.';

  @override
  String get walletSendOffline => 'الإرسال يحتاج إلى اتصال بالإنترنت.';

  @override
  String get walletPendingTitle => 'قد لا يكون أحد التحويلات قد تم';

  @override
  String walletPendingBody(String amount, String name) {
    return '$amount إلى $name. راجعه قبل الإرسال مرة أخرى.';
  }

  @override
  String get walletPendingReview => 'مراجعة';

  @override
  String get genericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get networkError =>
      'تعذر الوصول إلى رعد الآن. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get tooManyAttempts =>
      'محاولات كثيرة. يرجى الانتظار بضع دقائق ثم المحاولة مرة أخرى.';

  @override
  String tooManyAttemptsSeconds(int seconds) {
    return 'محاولات كثيرة. حاول مرة أخرى بعد $seconds ثانية.';
  }

  @override
  String get signInRefused => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get emailInUse =>
      'هذا البريد الإلكتروني مستخدم بالفعل. هل تريد تسجيل الدخول؟';

  @override
  String get passwordRule =>
      '8 أحرف على الأقل، مع حرف لاتيني صغير وحرف لاتيني كبير ورقم.';

  @override
  String get passwordRuleBroken =>
      'تحتاج كلمة المرور إلى 8 أحرف على الأقل، وحرف لاتيني صغير، وحرف لاتيني كبير، ورقم.';

  @override
  String get codeInvalid => 'هذا الرمز غير صالح. تحقق منه وحاول مرة أخرى.';

  @override
  String get sendTitle => 'إرسال أموال';

  @override
  String get sendRecipientSection => 'المستلم';

  @override
  String get sendRecipientLabel => 'البريد الإلكتروني للمستلم';

  @override
  String get sendAmountSection => 'مبلغ التحويل';

  @override
  String get sendAmountLabel => 'المبلغ (ر.س)';

  @override
  String get sendAmountHint => 'من 1.00 إلى 500.00 ر.س';

  @override
  String sendAvailable(String amount) {
    return 'المتاح: $amount';
  }

  @override
  String sendQuickAmount(String amount) {
    return 'إدخال $amount';
  }

  @override
  String get sendMax => 'الحد الأقصى';

  @override
  String sendMaxHint(String amount) {
    return 'إدخال أكبر مبلغ يمكنك إرساله: $amount';
  }

  @override
  String sendDemoFill(String email) {
    return 'تجربة: إدخال $email';
  }

  @override
  String get sendContinue => 'متابعة';

  @override
  String get sendEmailRequired => 'أدخل البريد الإلكتروني للمستلم.';

  @override
  String get sendEmailInvalid => 'أدخل بريدًا إلكترونيًا كاملًا.';

  @override
  String get sendAmountRequired => 'أدخل مبلغًا.';

  @override
  String get sendAmountInvalid =>
      'أدخل مبلغًا بالريال بخانتين عشريتين على الأكثر.';

  @override
  String get amountRange => 'يجب أن يكون المبلغ بين 1.00 و500.00 ر.س.';

  @override
  String get balanceLow => 'رصيدك غير كافٍ لهذا التحويل.';

  @override
  String get ownAddress => 'لا يمكنك إرسال الأموال إلى نفسك.';

  @override
  String get noSuchUser => 'لا يوجد مستخدم في رعد بهذا البريد الإلكتروني.';

  @override
  String get sendingNeedsConnection => 'الإرسال يحتاج إلى اتصال بالإنترنت.';

  @override
  String get checkHistoryFirst =>
      'تحقق من السجل أولًا. قد يكون تحويلك السابق قد تم.';

  @override
  String get requestBlocked => 'تم حظر هذا الطلب. حاول مرة أخرى لاحقًا.';

  @override
  String get startNewTransfer => 'تعذر إرسال هذا التحويل. ابدأ تحويلًا جديدًا.';

  @override
  String get checkDetails =>
      'تحقق من البريد الإلكتروني والمبلغ ثم حاول مرة أخرى.';

  @override
  String get reviewTitle => 'مراجعة التحويل';

  @override
  String get reviewTo => 'إلى';

  @override
  String get reviewEmail => 'البريد الإلكتروني';

  @override
  String get reviewAmount => 'المبلغ';

  @override
  String get reviewBalanceAfter => 'الرصيد بعد التحويل';

  @override
  String get reviewConfirm => 'تأكيد وإرسال';

  @override
  String get reviewSending => 'جارٍ الإرسال…';

  @override
  String get reviewCancel => 'إلغاء';

  @override
  String get reviewWalletReady => 'محفظتك جاهزة الآن. اضغط تأكيد للإرسال.';

  @override
  String get reviewNotSent =>
      'لم يُرسل التحويل. تحقق من اتصالك ثم أكّد مرة أخرى.';

  @override
  String get reviewNotSaved =>
      'لم يُرسل التحويل لأنه تعذر حفظه بأمان على هذا الهاتف. حاول مرة أخرى.';

  @override
  String get transferUnconfirmedTitle => 'تعذر تأكيد التحويل';

  @override
  String get transferUnconfirmedBody =>
      'قد يكون المبلغ أُرسل أو لم يُرسل. تحقق من السجل قبل المحاولة مرة أخرى.';

  @override
  String get uncertainCheck => 'تحقق من رصيدي وسجلي';

  @override
  String get uncertainTryAgain => 'حاول مرة أخرى بالتفاصيل نفسها';

  @override
  String get uncertainTryAgainNote =>
      'إعادة المحاولة ترسل الطلب نفسه. إذا كان الطلب الأول قد تم، فلن ينتقل المبلغ إلا مرة واحدة.';

  @override
  String get uncertainChangeDetails => 'تغيير التفاصيل';

  @override
  String get resultTitle => 'تم إرسال التحويل';

  @override
  String resultSummary(String amount, String name) {
    return 'أرسلت $amount إلى $name.';
  }

  @override
  String get resultReference => 'المرجع';

  @override
  String get resultNewBalance => 'الرصيد الجديد';

  @override
  String get resultDone => 'تم';

  @override
  String historySentTo(String name) {
    return 'أُرسل إلى $name';
  }

  @override
  String historyReceivedFrom(String name) {
    return 'استُلم من $name';
  }

  @override
  String historyReference(String reference) {
    return 'المرجع $reference';
  }

  @override
  String historyEntrySemantics(
    String title,
    String email,
    String amount,
    String time,
    String reference,
  ) {
    return '$title، $email، $amount، $time، المرجع $reference';
  }

  @override
  String get historyEmpty => 'لا توجد تحويلات بعد.';

  @override
  String get historyError => 'تعذر تحميل السجل.';

  @override
  String get historyLoadMore => 'تحميل المزيد';

  @override
  String get historyLoadMoreFailed => 'تعذر تحميل المزيد. حاول مرة أخرى.';

  @override
  String get historyRestarted =>
      'أُعيد تحميل السجل من أحدث تحويل لأن القائمة انتهت صلاحيتها.';

  @override
  String get historySeeAll => 'عرض الكل';

  @override
  String get historyCheck => 'تحقق من السجل';

  @override
  String get historyEnd => 'هذه كل تحويلاتك.';

  @override
  String get logoLabel => 'رعد';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signInTagline => 'تحويلات رقمية بسرعة البرق';

  @override
  String get signInSubmit => 'تسجيل الدخول';

  @override
  String get signInBusy => 'جارٍ تسجيل الدخول…';

  @override
  String get signInForgot => 'نسيت كلمة المرور؟';

  @override
  String get signInNewToRaad => 'جديد في رعد؟';

  @override
  String get signInCreateAccount => 'إنشاء حساب';

  @override
  String get signInHaveCode => 'لديك رمز تأكيد؟';

  @override
  String get signInEmailRequired => 'أدخل بريدك الإلكتروني.';

  @override
  String get signInEmailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get signInPasswordRequired => 'أدخل كلمة المرور.';

  @override
  String get signInDemoFill => 'تجربة: إدخال سارة';

  @override
  String get signUpTitle => 'أنشئ حسابك';

  @override
  String get signUpDisplayName => 'الاسم المعروض';

  @override
  String get signUpDisplayNameRequired => 'أدخل اسمًا معروضًا.';

  @override
  String get signUpSubmit => 'إنشاء الحساب';

  @override
  String get signUpBusy => 'جارٍ إنشاء حسابك…';

  @override
  String get signUpSignInInstead => 'تسجيل الدخول بدلًا من ذلك';

  @override
  String get signUpPrivacy =>
      'نحتفظ فقط ببريدك الإلكتروني واسمك المعروض. لا تطلب رعد أبدًا بيانات بطاقة أو حساب بنكي.';

  @override
  String get confirmTitle => 'تأكيد بريدك الإلكتروني';

  @override
  String get confirmIntro => 'أرسلنا رمزًا إلى بريدك الإلكتروني. أدخله أدناه.';

  @override
  String get confirmCode => 'رمز التأكيد';

  @override
  String get confirmCodeRequired => 'أدخل الرمز الموجود في البريد.';

  @override
  String get confirmSubmit => 'تأكيد';

  @override
  String get confirmBusy => 'جارٍ التأكيد…';

  @override
  String get confirmResend => 'إرسال الرمز مرة أخرى';

  @override
  String get codeResent => 'أرسلنا رمزًا جديدًا.';

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotIntro => 'أدخل بريدك الإلكتروني وسنرسل لك رمزًا.';

  @override
  String get forgotSubmit => 'إرسال الرمز';

  @override
  String get forgotBusy => 'جارٍ الإرسال…';

  @override
  String get resetCodeSent =>
      'إذا كان هناك حساب بهذا البريد، فقد أرسلنا رمزًا.';

  @override
  String get resetTitle => 'اختر كلمة مرور جديدة';

  @override
  String get resetCode => 'الرمز';

  @override
  String get resetNewPassword => 'كلمة المرور الجديدة';

  @override
  String get resetSubmit => 'تغيير كلمة المرور';

  @override
  String get resetBusy => 'جارٍ تغيير كلمة المرور…';

  @override
  String get resetUncertain =>
      'تعذر التأكد من تغيير كلمة المرور. جرّب تسجيل الدخول بكلمة المرور الجديدة، وإن لم تنجح فاطلب رمزًا جديدًا.';

  @override
  String get resetGoToSignIn => 'الانتقال إلى تسجيل الدخول';

  @override
  String get resetNewCode => 'طلب رمز جديد';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get cardsTitle => 'بطاقاتي';

  @override
  String get cardsPreview => 'تصميم بطاقة افتراضية';

  @override
  String get cardsDemo => 'بطاقة تجريبية';

  @override
  String get cardsVirtualCard => 'بطاقة افتراضية';

  @override
  String get cardsSilver => 'فضية';

  @override
  String get cardsGold => 'ذهبية';

  @override
  String get cardsPlatinum => 'بلاتينية';

  @override
  String get configErrorTitle => 'لا يحتوي هذا الإصدار على إعدادات بيئة صالحة.';
}
