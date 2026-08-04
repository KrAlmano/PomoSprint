import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @navTimer.
  ///
  /// In tr, this message translates to:
  /// **'Süreç'**
  String get navTimer;

  /// No description provided for @navSocial.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal'**
  String get navSocial;

  /// No description provided for @navReports.
  ///
  /// In tr, this message translates to:
  /// **'Raporlar'**
  String get navReports;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @navHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get navHistory;

  /// No description provided for @navRanking.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama'**
  String get navRanking;

  /// No description provided for @navCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get navCategories;

  /// No description provided for @titleTimer.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint'**
  String get titleTimer;

  /// No description provided for @titleReports.
  ///
  /// In tr, this message translates to:
  /// **'Ders Raporları & Geçmiş'**
  String get titleReports;

  /// No description provided for @titleRanking.
  ///
  /// In tr, this message translates to:
  /// **'Liderlik Tablosu'**
  String get titleRanking;

  /// No description provided for @titleSocial.
  ///
  /// In tr, this message translates to:
  /// **'Sanal Kütüphane & Masalar'**
  String get titleSocial;

  /// No description provided for @titleCategories.
  ///
  /// In tr, this message translates to:
  /// **'Ders Kategorileri'**
  String get titleCategories;

  /// No description provided for @selectSubject.
  ///
  /// In tr, this message translates to:
  /// **'DERS SEÇ'**
  String get selectSubject;

  /// No description provided for @addSubject.
  ///
  /// In tr, this message translates to:
  /// **'Ders Ekle'**
  String get addSubject;

  /// No description provided for @btnStart.
  ///
  /// In tr, this message translates to:
  /// **'BAŞLAT'**
  String get btnStart;

  /// No description provided for @btnPause.
  ///
  /// In tr, this message translates to:
  /// **'DURDUR'**
  String get btnPause;

  /// No description provided for @btnReset.
  ///
  /// In tr, this message translates to:
  /// **'SIFIRLA'**
  String get btnReset;

  /// No description provided for @modePomodoro.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro'**
  String get modePomodoro;

  /// No description provided for @modeShortBreak.
  ///
  /// In tr, this message translates to:
  /// **'Kısa Mola'**
  String get modeShortBreak;

  /// No description provided for @modeLongBreak.
  ///
  /// In tr, this message translates to:
  /// **'Uzun Mola'**
  String get modeLongBreak;

  /// No description provided for @dailyStreak.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Seri'**
  String get dailyStreak;

  /// No description provided for @dailyGoal.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Hedef'**
  String get dailyGoal;

  /// No description provided for @sessionCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Tebrikler! Seans Tamamlandı 🎉'**
  String get sessionCompleted;

  /// No description provided for @durationPlanning.
  ///
  /// In tr, this message translates to:
  /// **'Süre Planlama'**
  String get durationPlanning;

  /// No description provided for @pauseCreditAvailable.
  ///
  /// In tr, this message translates to:
  /// **'1/1 Duraklatma Hakkı'**
  String get pauseCreditAvailable;

  /// No description provided for @pauseCreditUsed.
  ///
  /// In tr, this message translates to:
  /// **'0/1 Duraklatma Hakkı (Hakkın Bitti)'**
  String get pauseCreditUsed;

  /// No description provided for @focusTimeMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} DK FOCUS TIME'**
  String focusTimeMinutes(Object minutes);

  /// No description provided for @catMath.
  ///
  /// In tr, this message translates to:
  /// **'Matematik'**
  String get catMath;

  /// No description provided for @catPhysics.
  ///
  /// In tr, this message translates to:
  /// **'Fizik'**
  String get catPhysics;

  /// No description provided for @catHistory.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get catHistory;

  /// No description provided for @catChemistry.
  ///
  /// In tr, this message translates to:
  /// **'Kimya'**
  String get catChemistry;

  /// No description provided for @catBiology.
  ///
  /// In tr, this message translates to:
  /// **'Biyoloji'**
  String get catBiology;

  /// No description provided for @catLiterature.
  ///
  /// In tr, this message translates to:
  /// **'Edebiyat'**
  String get catLiterature;

  /// No description provided for @catEnglish.
  ///
  /// In tr, this message translates to:
  /// **'İngilizce'**
  String get catEnglish;

  /// No description provided for @avatarGamer.
  ///
  /// In tr, this message translates to:
  /// **'Gamer Çırak'**
  String get avatarGamer;

  /// No description provided for @avatarGamerDesc.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç karakterin. 1 seans tamamla.'**
  String get avatarGamerDesc;

  /// No description provided for @avatarGlasses.
  ///
  /// In tr, this message translates to:
  /// **'Gözlüklü Bilgin'**
  String get avatarGlasses;

  /// No description provided for @avatarGlassesDesc.
  ///
  /// In tr, this message translates to:
  /// **'5 seans tamamlayarak kilidini aç.'**
  String get avatarGlassesDesc;

  /// No description provided for @avatarGentleman.
  ///
  /// In tr, this message translates to:
  /// **'Centilmen'**
  String get avatarGentleman;

  /// No description provided for @avatarGentlemanDesc.
  ///
  /// In tr, this message translates to:
  /// **'10 seans tamamlayarak kilidini aç.'**
  String get avatarGentlemanDesc;

  /// No description provided for @avatarCyberpunk.
  ///
  /// In tr, this message translates to:
  /// **'Cyberpunk'**
  String get avatarCyberpunk;

  /// No description provided for @avatarCyberpunkDesc.
  ///
  /// In tr, this message translates to:
  /// **'15 seans tamamlayarak kilidini aç.'**
  String get avatarCyberpunkDesc;

  /// No description provided for @avatarCat.
  ///
  /// In tr, this message translates to:
  /// **'Kedi Sever'**
  String get avatarCat;

  /// No description provided for @avatarCatDesc.
  ///
  /// In tr, this message translates to:
  /// **'20 seans tamamlayarak kilidini aç.'**
  String get avatarCatDesc;

  /// No description provided for @avatarCoder.
  ///
  /// In tr, this message translates to:
  /// **'Kodlama Uzmanı'**
  String get avatarCoder;

  /// No description provided for @avatarCoderDesc.
  ///
  /// In tr, this message translates to:
  /// **'30 seans tamamlayarak kilidini aç.'**
  String get avatarCoderDesc;

  /// No description provided for @avatarNinja.
  ///
  /// In tr, this message translates to:
  /// **'Ninja'**
  String get avatarNinja;

  /// No description provided for @avatarNinjaDesc.
  ///
  /// In tr, this message translates to:
  /// **'50 seans tamamlayarak kilidini aç.'**
  String get avatarNinjaDesc;

  /// No description provided for @avatarAstronaut.
  ///
  /// In tr, this message translates to:
  /// **'Astronot'**
  String get avatarAstronaut;

  /// No description provided for @avatarAstronautDesc.
  ///
  /// In tr, this message translates to:
  /// **'75 seans tamamlayarak kilidini aç.'**
  String get avatarAstronautDesc;

  /// No description provided for @avatarViking.
  ///
  /// In tr, this message translates to:
  /// **'Viking'**
  String get avatarViking;

  /// No description provided for @avatarVikingDesc.
  ///
  /// In tr, this message translates to:
  /// **'100 seans tamamlayarak kilidini aç.'**
  String get avatarVikingDesc;

  /// No description provided for @selectCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Karakterini Seç'**
  String get selectCharacter;

  /// No description provided for @selectCharacterSub.
  ///
  /// In tr, this message translates to:
  /// **'Odaklanma seanslarında sana eşlik edecek karakterini seç.'**
  String get selectCharacterSub;

  /// No description provided for @confirmSelection.
  ///
  /// In tr, this message translates to:
  /// **'Seçimi Onayla'**
  String get confirmSelection;

  /// No description provided for @lockedCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Kilitli Karakter'**
  String get lockedCharacter;

  /// No description provided for @welcomeBackTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar hoş geldin. Odaklanmaya hazır mısın?'**
  String get welcomeBackTitle;

  /// No description provided for @emailOrUsername.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı Adı veya E-posta'**
  String get emailOrUsername;

  /// No description provided for @password.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get password;

  /// No description provided for @loginBtn.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get loginBtn;

  /// No description provided for @forgotPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifremi Unuttum'**
  String get forgotPassword;

  /// No description provided for @noAccountText.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın yok mu? '**
  String get noAccountText;

  /// No description provided for @signUpLink.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get signUpLink;

  /// No description provided for @googleLogin.
  ///
  /// In tr, this message translates to:
  /// **'Google ile Giriş'**
  String get googleLogin;

  /// No description provided for @resendVerificationLink.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama E-postasını Tekrar Gönder 📬'**
  String get resendVerificationLink;

  /// No description provided for @errFillFields.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen tüm alanları doldurun.'**
  String get errFillFields;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi veya şifre hatalı!'**
  String get errInvalidCredentials;

  /// No description provided for @verificationResentMsg.
  ///
  /// In tr, this message translates to:
  /// **'📬 Doğrulama bağlantısı tekrar gönderildi. Lütfen e-postanızı kontrol edin.'**
  String get verificationResentMsg;

  /// No description provided for @passwordResetMsg.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırlama bağlantısı gönderildi.'**
  String get passwordResetMsg;

  /// No description provided for @createAccountTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Hesap Oluştur'**
  String get createAccountTitle;

  /// No description provided for @createAccountSub.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint\'e katıl ve odaklanmaya başla.'**
  String get createAccountSub;

  /// No description provided for @orDivider.
  ///
  /// In tr, this message translates to:
  /// **'VEYA'**
  String get orDivider;

  /// No description provided for @fullName.
  ///
  /// In tr, this message translates to:
  /// **'İsim Soyisim'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn: Ayşe Yılmaz'**
  String get fullNameHint;

  /// No description provided for @termsAgree.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşullarını ve Gizlilik Politikasını okudum, onaylıyorum.'**
  String get termsAgree;

  /// No description provided for @updatesAgree.
  ///
  /// In tr, this message translates to:
  /// **'Yeni özelliklerden ve güncellemelerden haberdar olmak istiyorum.'**
  String get updatesAgree;

  /// No description provided for @registerBtn.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get registerBtn;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabın var mı? '**
  String get alreadyHaveAccount;

  /// No description provided for @verificationSentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama E-postası Gönderildi! 📬'**
  String get verificationSentTitle;

  /// No description provided for @verificationSentDesc.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine bir onay bağlantısı gönderdik.\n\nLütfen e-posta kutunuzu açıp doğrulama linkine tıkla. Onayladıktan sonra hemen giriş yapabilirsin!'**
  String verificationSentDesc(Object email);

  /// No description provided for @backToLoginBtn.
  ///
  /// In tr, this message translates to:
  /// **'Anladım, Giriş Yap\'a Dön'**
  String get backToLoginBtn;

  /// No description provided for @errFillEmailPassword.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen e-posta ve şifrenizi girin.'**
  String get errFillEmailPassword;

  /// No description provided for @errShortPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalıdır.'**
  String get errShortPassword;

  /// No description provided for @errAcceptTerms.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için kullanım koşullarını kabul edin.'**
  String get errAcceptTerms;

  /// No description provided for @errEmailExists.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kayıtlı! Lütfen \"Giriş Yap\" ekranından giriş yapın.'**
  String get errEmailExists;

  /// No description provided for @reportsTabSubject.
  ///
  /// In tr, this message translates to:
  /// **'Ders Raporları'**
  String get reportsTabSubject;

  /// No description provided for @reportsTabHistory.
  ///
  /// In tr, this message translates to:
  /// **'Çalışma Geçmişi'**
  String get reportsTabHistory;

  /// No description provided for @totalFocusTime.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Çalışma'**
  String get totalFocusTime;

  /// No description provided for @subjectBreakdown.
  ///
  /// In tr, this message translates to:
  /// **'Ders Odaklanma Dağılımı'**
  String get subjectBreakdown;

  /// No description provided for @noDataTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz detaylı raporun yok, çalışmaya başla! 🚀'**
  String get noDataTitle;

  /// No description provided for @noDataDesc.
  ///
  /// In tr, this message translates to:
  /// **'Zamanlayıcıyı başlatıp ilk Pomodoro seansını tamamladığında ders dağılımın ve raporların burada görünecek.'**
  String get noDataDesc;

  /// No description provided for @startStudyingBtn.
  ///
  /// In tr, this message translates to:
  /// **'Hemen Çalışmaya Başla'**
  String get startStudyingBtn;

  /// No description provided for @minutesUnit.
  ///
  /// In tr, this message translates to:
  /// **'dk'**
  String get minutesUnit;

  /// No description provided for @hoursUnit.
  ///
  /// In tr, this message translates to:
  /// **'s'**
  String get hoursUnit;

  /// No description provided for @completedSessions.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan Seanslar'**
  String get completedSessions;

  /// No description provided for @sessionsCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} Seans'**
  String sessionsCount(Object count);

  /// No description provided for @weekly.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık'**
  String get weekly;

  /// No description provided for @allTime.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Zamanlar'**
  String get allTime;

  /// No description provided for @noUsersInRanking.
  ///
  /// In tr, this message translates to:
  /// **'Henüz sıralamada kayıtlı kullanıcı bulunmuyor.'**
  String get noUsersInRanking;

  /// No description provided for @minutesStudy.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk çalışma'**
  String minutesStudy(Object minutes);

  /// No description provided for @userDefault.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get userDefault;

  /// No description provided for @youBadge.
  ///
  /// In tr, this message translates to:
  /// **'(Sen)'**
  String get youBadge;

  /// No description provided for @virtualLibrary.
  ///
  /// In tr, this message translates to:
  /// **'Sanal Kütüphane & Masalar'**
  String get virtualLibrary;

  /// No description provided for @studentsStudying.
  ///
  /// In tr, this message translates to:
  /// **'{count} Öğrenci Masalarda Çalışıyor'**
  String studentsStudying(Object count);

  /// No description provided for @emptyTables.
  ///
  /// In tr, this message translates to:
  /// **'Masalar Boş - İlk Oturan Sen Ol!'**
  String get emptyTables;

  /// No description provided for @leaveTable.
  ///
  /// In tr, this message translates to:
  /// **'Masadan Kalk'**
  String get leaveTable;

  /// No description provided for @joinTable.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get joinTable;

  /// No description provided for @tableFull.
  ///
  /// In tr, this message translates to:
  /// **'Masa Dolu'**
  String get tableFull;

  /// No description provided for @silentRoom.
  ///
  /// In tr, this message translates to:
  /// **'Sadece Sessiz'**
  String get silentRoom;

  /// No description provided for @chatPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Mesajınızı yazın...'**
  String get chatPlaceholder;

  /// No description provided for @addCategoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Kategori Ekle'**
  String get addCategoryTitle;

  /// No description provided for @addCategorySub.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmalarını düzenlemek için yeni bir ders veya konu oluştur.'**
  String get addCategorySub;

  /// No description provided for @categoryNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Kategori Adı (Örn: Tarih)'**
  String get categoryNameHint;

  /// No description provided for @chooseColor.
  ///
  /// In tr, this message translates to:
  /// **'Renk Seçimi'**
  String get chooseColor;

  /// No description provided for @addedToast.
  ///
  /// In tr, this message translates to:
  /// **'{name} eklendi!'**
  String addedToast(Object name);

  /// No description provided for @deleteBtn.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get deleteBtn;

  /// No description provided for @profileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil ve Ayarlar'**
  String get profileTitle;

  /// No description provided for @editProfile.
  ///
  /// In tr, this message translates to:
  /// **'PROFİL BİLGİLERİ'**
  String get editProfile;

  /// No description provided for @nameSurname.
  ///
  /// In tr, this message translates to:
  /// **'İsim Soyisim'**
  String get nameSurname;

  /// No description provided for @email.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Adresi'**
  String get email;

  /// No description provided for @emailReadonlyHint.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi güvenlik nedeniyle değiştirilemez.'**
  String get emailReadonlyHint;

  /// No description provided for @appLanguage.
  ///
  /// In tr, this message translates to:
  /// **'UYGULAMA DİLİ'**
  String get appLanguage;

  /// No description provided for @langTr.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe 🇹🇷'**
  String get langTr;

  /// No description provided for @langEn.
  ///
  /// In tr, this message translates to:
  /// **'English 🇬🇧'**
  String get langEn;

  /// No description provided for @changeAvatar.
  ///
  /// In tr, this message translates to:
  /// **'Avatarı Değiştir'**
  String get changeAvatar;

  /// No description provided for @totalPoints.
  ///
  /// In tr, this message translates to:
  /// **'Kazanılan Puan'**
  String get totalPoints;

  /// No description provided for @streakDays.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Seri'**
  String get streakDays;

  /// No description provided for @deleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı Sil'**
  String get deleteAccount;

  /// No description provided for @logout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get logout;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get cancel;

  /// No description provided for @notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notifications;

  /// No description provided for @darkMode.
  ///
  /// In tr, this message translates to:
  /// **'Karanlık Mod'**
  String get darkMode;

  /// No description provided for @preferences.
  ///
  /// In tr, this message translates to:
  /// **'TERCİHLER'**
  String get preferences;

  /// No description provided for @nameUpdatedSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Profil adınız başarıyla güncellendi!'**
  String get nameUpdatedSuccess;

  /// No description provided for @pointsCaption.
  ///
  /// In tr, this message translates to:
  /// **'PUAN'**
  String get pointsCaption;

  /// No description provided for @pauseUsedSnackbar.
  ///
  /// In tr, this message translates to:
  /// **'1/1 Duraklatma hakkını kullandın! Tekrar durduramazsın.'**
  String get pauseUsedSnackbar;

  /// No description provided for @pauseLimitTitle.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatma Hakkın Bitti!'**
  String get pauseLimitTitle;

  /// No description provided for @pauseLimitContent.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans boyunca 1 defalık duraklatma hakkını zaten kullandın.\n\nŞimdi durdurursan seans ilerlemen tamamen sıfırlanacak.'**
  String get pauseLimitContent;

  /// No description provided for @resetAndStop.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla & Durdur'**
  String get resetAndStop;

  /// No description provided for @continueBtn.
  ///
  /// In tr, this message translates to:
  /// **'Devam Et'**
  String get continueBtn;

  /// No description provided for @sessionReset.
  ///
  /// In tr, this message translates to:
  /// **'Seans ilerlemen sıfırlandı.'**
  String get sessionReset;

  /// No description provided for @dailyGoalLabel.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Hedef'**
  String get dailyGoalLabel;

  /// No description provided for @setDailyGoalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Hedef Belirle'**
  String get setDailyGoalTitle;

  /// No description provided for @setDailyGoalSub.
  ///
  /// In tr, this message translates to:
  /// **'Bugün kaç Pomodoro tamamlamak istiyorsun?'**
  String get setDailyGoalSub;

  /// No description provided for @saveGoalBtn.
  ///
  /// In tr, this message translates to:
  /// **'Hedefi Kaydet'**
  String get saveGoalBtn;

  /// No description provided for @efficiencyScoreCaption.
  ///
  /// In tr, this message translates to:
  /// **'VERİMLİLİK SKORU'**
  String get efficiencyScoreCaption;

  /// No description provided for @efficiencyMsgExceeded.
  ///
  /// In tr, this message translates to:
  /// **'Hedefini aştın, harikasın! 🔥'**
  String get efficiencyMsgExceeded;

  /// No description provided for @efficiencyMsgClose.
  ///
  /// In tr, this message translates to:
  /// **'Hedefe yaklaşıyorsun!'**
  String get efficiencyMsgClose;

  /// No description provided for @efficiencyMsgLow.
  ///
  /// In tr, this message translates to:
  /// **'Bugün biraz daha çalışabilirsin'**
  String get efficiencyMsgLow;

  /// No description provided for @todayStudiesHeader.
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü Çalışmalar'**
  String get todayStudiesHeader;

  /// No description provided for @detailsLink.
  ///
  /// In tr, this message translates to:
  /// **'Detaylar'**
  String get detailsLink;

  /// No description provided for @weeklyDistTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık Dağılım'**
  String get weeklyDistTitle;

  /// No description provided for @weeklyDistSub.
  ///
  /// In tr, this message translates to:
  /// **'Son 7 günün özeti'**
  String get weeklyDistSub;

  /// No description provided for @hourToggle.
  ///
  /// In tr, this message translates to:
  /// **'Saat'**
  String get hourToggle;

  /// No description provided for @totalLabel.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get totalLabel;

  /// No description provided for @efficiencyTipHeader.
  ///
  /// In tr, this message translates to:
  /// **'Verimlilik İpucu'**
  String get efficiencyTipHeader;

  /// No description provided for @hourAbbr.
  ///
  /// In tr, this message translates to:
  /// **'sa'**
  String get hourAbbr;

  /// No description provided for @minAbbr.
  ///
  /// In tr, this message translates to:
  /// **'dk'**
  String get minAbbr;

  /// No description provided for @tip1.
  ///
  /// In tr, this message translates to:
  /// **'Sabah saatlerinde matematik çalışmak odaklanma kapasiteni %15 artırıyor.'**
  String get tip1;

  /// No description provided for @tip2.
  ///
  /// In tr, this message translates to:
  /// **'Her 25 dakikalık odaklanma seansından sonra 5 dakika mola ver.'**
  String get tip2;

  /// No description provided for @tip3.
  ///
  /// In tr, this message translates to:
  /// **'Günde 4 pomodoro tamamlamak düzenli çalışma alışkanlığı oluşturur.'**
  String get tip3;

  /// No description provided for @tip4.
  ///
  /// In tr, this message translates to:
  /// **'Zorlu konuları sabah saatlerinde çalışmak verimliliği artırır.'**
  String get tip4;
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
