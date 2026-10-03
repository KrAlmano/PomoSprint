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

  /// No description provided for @authEmailHint.
  ///
  /// In tr, this message translates to:
  /// **'ornek@posta.com'**
  String get authEmailHint;

  /// No description provided for @authAppleSignInBtn.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile Giriş Yap'**
  String get authAppleSignInBtn;

  /// No description provided for @authSocialConsentPrefix.
  ///
  /// In tr, this message translates to:
  /// **'Devam ederek '**
  String get authSocialConsentPrefix;

  /// No description provided for @authSocialConsentSuffix.
  ///
  /// In tr, this message translates to:
  /// **' kabul etmiş olursun.'**
  String get authSocialConsentSuffix;

  /// No description provided for @authResendAvailableIn.
  ///
  /// In tr, this message translates to:
  /// **'{seconds} sn sonra tekrar gönderebilirsin'**
  String authResendAvailableIn(int seconds);

  /// No description provided for @onboardingSelectCategoryError.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için en az bir kategori seç.'**
  String get onboardingSelectCategoryError;

  /// No description provided for @onboardingUnder13Error.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint\'i kullanmak için en az 13 yaşında olmalısın.'**
  String get onboardingUnder13Error;

  /// No description provided for @onboardingSessionExpired.
  ///
  /// In tr, this message translates to:
  /// **'Oturumun sona erdi. Lütfen tekrar giriş yap.'**
  String get onboardingSessionExpired;

  /// No description provided for @onboardingSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Bilgilerin kaydedilemedi. Lütfen tekrar dene.'**
  String get onboardingSaveError;

  /// No description provided for @onboardingCategoryStepBodyLimit.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi çalışacağın dersleri/alanları seç; istediğin zaman değiştirebilirsin. En fazla {limit} tane seçebilirsin.'**
  String onboardingCategoryStepBodyLimit(int limit);

  /// No description provided for @categoryNameExistsMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu isimde bir kategori zaten var.'**
  String get categoryNameExistsMsg;

  /// No description provided for @categoriesLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.'**
  String get categoriesLoadError;

  /// No description provided for @categorySaveError.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklik kaydedilemedi. Lütfen tekrar dene.'**
  String get categorySaveError;

  /// No description provided for @categoriesRetryBtn.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get categoriesRetryBtn;

  /// No description provided for @rankingTabLeague.
  ///
  /// In tr, this message translates to:
  /// **'Lig'**
  String get rankingTabLeague;

  /// No description provided for @rankingTabMonthly.
  ///
  /// In tr, this message translates to:
  /// **'Aylık'**
  String get rankingTabMonthly;

  /// No description provided for @rankingTabFriends.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlar'**
  String get rankingTabFriends;

  /// No description provided for @rankingMonthlyResetIn.
  ///
  /// In tr, this message translates to:
  /// **'Aylık sıralamanın sıfırlanmasına kalan süre'**
  String get rankingMonthlyResetIn;

  /// No description provided for @rankingLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama yüklenemedi. Bağlantını kontrol edip tekrar dene.'**
  String get rankingLoadError;

  /// No description provided for @rankingMyStatus.
  ///
  /// In tr, this message translates to:
  /// **'Sıran: #{rank} · {points} puan'**
  String rankingMyStatus(int rank, int points);

  /// No description provided for @rankingPoints.
  ///
  /// In tr, this message translates to:
  /// **'{points} puan'**
  String rankingPoints(int points);

  /// No description provided for @rankingCountdownDays.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün {hours} saat {minutes} dk'**
  String rankingCountdownDays(int days, int hours, int minutes);

  /// No description provided for @rankingCountdownHours.
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat {minutes} dk {seconds} sn'**
  String rankingCountdownHours(int hours, int minutes, int seconds);

  /// No description provided for @rankingCountdownResetting.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırlanıyor...'**
  String get rankingCountdownResetting;

  /// No description provided for @socialRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get socialRetry;

  /// No description provided for @socialRefreshFailed.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenemedi, son yüklenen veriler gösteriliyor.'**
  String get socialRefreshFailed;

  /// No description provided for @socialErrNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.'**
  String get socialErrNetwork;

  /// No description provided for @socialErrSession.
  ///
  /// In tr, this message translates to:
  /// **'Oturumun sona ermiş. Lütfen yeniden giriş yap.'**
  String get socialErrSession;

  /// No description provided for @socialErrGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar dene.'**
  String get socialErrGeneric;

  /// No description provided for @socialErrInsufficientCoins.
  ///
  /// In tr, this message translates to:
  /// **'Yeterli kum tanen yok.'**
  String get socialErrInsufficientCoins;

  /// No description provided for @socialErrAvatarLocked.
  ///
  /// In tr, this message translates to:
  /// **'Bu avatarın henüz sahibi değilsin.'**
  String get socialErrAvatarLocked;

  /// No description provided for @socialYourFriends.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşların'**
  String get socialYourFriends;

  /// No description provided for @socialFocusingNow.
  ///
  /// In tr, this message translates to:
  /// **'Şu An Çalışanlar'**
  String get socialFocusingNow;

  /// No description provided for @socialFocusing.
  ///
  /// In tr, this message translates to:
  /// **'Odaklanıyor'**
  String get socialFocusing;

  /// No description provided for @socialFocusingOn.
  ///
  /// In tr, this message translates to:
  /// **'{category} çalışıyor'**
  String socialFocusingOn(String category);

  /// No description provided for @socialNoLiveFriends.
  ///
  /// In tr, this message translates to:
  /// **'Şu an çalışan arkadaşın yok. Biri odaklanmaya başladığında burada görünecek.'**
  String get socialNoLiveFriends;

  /// No description provided for @socialLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlarının durumu yüklenemedi. Bağlantını kontrol edip tekrar dene.'**
  String get socialLoadError;

  /// No description provided for @leagueTierBronze.
  ///
  /// In tr, this message translates to:
  /// **'Bronz Kum Saati'**
  String get leagueTierBronze;

  /// No description provided for @leagueTierSilver.
  ///
  /// In tr, this message translates to:
  /// **'Gümüş Kum Saati'**
  String get leagueTierSilver;

  /// No description provided for @leagueTierGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın Kum Saati'**
  String get leagueTierGold;

  /// No description provided for @leagueTierSapphire.
  ///
  /// In tr, this message translates to:
  /// **'Safir Kum Saati'**
  String get leagueTierSapphire;

  /// No description provided for @leagueTierDiamond.
  ///
  /// In tr, this message translates to:
  /// **'Elmas Kum Saati'**
  String get leagueTierDiamond;

  /// No description provided for @leagueTierLeagueName.
  ///
  /// In tr, this message translates to:
  /// **'{tier} Ligi'**
  String leagueTierLeagueName(String tier);

  /// No description provided for @leagueInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig Sistemi Nasıl Çalışır?'**
  String get leagueInfoTitle;

  /// No description provided for @leagueInfoWhatTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig Nedir?'**
  String get leagueInfoWhatTitle;

  /// No description provided for @leagueInfoWhatBody.
  ///
  /// In tr, this message translates to:
  /// **'Her lig döneminde seninle benzer seviyedeki en fazla 30 kişiyle aynı gruba düşersin. Dönem boyunca kim daha çok odaklanırsa üst sıraya çıkar.'**
  String get leagueInfoWhatBody;

  /// No description provided for @leagueInfoTiersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig Kademeleri'**
  String get leagueInfoTiersTitle;

  /// No description provided for @leagueInfoYouAreHere.
  ///
  /// In tr, this message translates to:
  /// **'Şu an buradasın'**
  String get leagueInfoYouAreHere;

  /// No description provided for @leagueInfoPointsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Puan Nasıl Kazanılır?'**
  String get leagueInfoPointsTitle;

  /// No description provided for @leagueInfoPoints25.
  ///
  /// In tr, this message translates to:
  /// **'25 dakikalık odak: {points} puan'**
  String leagueInfoPoints25(String points);

  /// No description provided for @leagueInfoPoints50.
  ///
  /// In tr, this message translates to:
  /// **'50 dakikalık odak: {points} puan'**
  String leagueInfoPoints50(String points);

  /// No description provided for @leagueInfoStreakBonus.
  ///
  /// In tr, this message translates to:
  /// **'Seri bonusu:'**
  String get leagueInfoStreakBonus;

  /// No description provided for @leagueInfoStreakRange.
  ///
  /// In tr, this message translates to:
  /// **'{from}-{to} gün: %{pct}'**
  String leagueInfoStreakRange(String from, String to, String pct);

  /// No description provided for @leagueInfoStreakRangeOpen.
  ///
  /// In tr, this message translates to:
  /// **'{from}+ gün: %{pct}'**
  String leagueInfoStreakRangeOpen(String from, String pct);

  /// No description provided for @leagueInfoStreakKeep.
  ///
  /// In tr, this message translates to:
  /// **'Her gün en az 1 pomodoro tamamlayarak serini canlı tut.'**
  String get leagueInfoStreakKeep;

  /// No description provided for @leagueInfoPausePenalty.
  ///
  /// In tr, this message translates to:
  /// **'Seansı duraklatırsan puan %{pct} azalır.'**
  String leagueInfoPausePenalty(String pct);

  /// No description provided for @leagueInfoCoins.
  ///
  /// In tr, this message translates to:
  /// **'🪙 Kum tanesi: Tamamladığın her seanstan (günde {limit} seansa kadar) {coins} kum tanesi kazanırsın. Karakter koleksiyonundan yeni kum saatleri açmak için kullanılır.'**
  String leagueInfoCoins(String coins, String limit);

  /// No description provided for @leagueInfoPromotionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yükselme ve Düşme'**
  String get leagueInfoPromotionTitle;

  /// No description provided for @leagueInfoPeriodEnds.
  ///
  /// In tr, this message translates to:
  /// **'Bu lig dönemi {date} tarihinde sona erer. Dönem sonunda sıralamana göre yükselir, kalır ya da düşersin.'**
  String leagueInfoPeriodEnds(String date);

  /// No description provided for @leagueInfoPeriodGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Lig dönemi sona erdiğinde sıralamana göre yükselir, kalır ya da düşersin.'**
  String get leagueInfoPeriodGeneric;

  /// No description provided for @leagueInfoTopTier.
  ///
  /// In tr, this message translates to:
  /// **'En üst ligdesin, yükselecek yer yok.'**
  String get leagueInfoTopTier;

  /// No description provided for @leagueInfoPromote.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem puan toplayan ilk {count} kişi bir üst lige yükselir.'**
  String leagueInfoPromote(int count);

  /// No description provided for @leagueInfoDemote.
  ///
  /// In tr, this message translates to:
  /// **'Son {count} kişi bir alt lige düşer.'**
  String leagueInfoDemote(int count);

  /// No description provided for @leagueInfoNoDemotionBronze.
  ///
  /// In tr, this message translates to:
  /// **'Bronz ligde düşme yoktur.'**
  String get leagueInfoNoDemotionBronze;

  /// No description provided for @leagueInfoNoDemotionThisPeriod.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem bu ligde düşme yok.'**
  String get leagueInfoNoDemotionThisPeriod;

  /// No description provided for @leagueAwaitingPlacementTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir lig odasında değilsin'**
  String get leagueAwaitingPlacementTitle;

  /// No description provided for @leagueAwaitingPlacementBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem ilk pomodoronu tamamladığında seninle benzer seviyedeki en fazla 30 kişilik bir odaya yerleşirsin. Sıralaman ve yükselme durumun burada görünür.'**
  String get leagueAwaitingPlacementBody;

  /// No description provided for @leagueInfoDailyLimitTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Sınır'**
  String get leagueInfoDailyLimitTitle;

  /// No description provided for @leagueInfoDailyLimitBody.
  ///
  /// In tr, this message translates to:
  /// **'Günde en fazla {limit} seans puan ve kum kazandırır (lig puanı, aylık sıralama, toplam puan). Sonraki seanslar yalnızca çalışma süresine ve serine eklenir.'**
  String leagueInfoDailyLimitBody(String limit);

  /// No description provided for @leagueInfoFaqTitle.
  ///
  /// In tr, this message translates to:
  /// **'Puanım Neden Artmadı?'**
  String get leagueInfoFaqTitle;

  /// No description provided for @leagueInfoFaqLimit.
  ///
  /// In tr, this message translates to:
  /// **'Günlük {limit} seans sınırına ulaşmış olabilirsin.'**
  String leagueInfoFaqLimit(String limit);

  /// No description provided for @leagueInfoFaqCancelled.
  ///
  /// In tr, this message translates to:
  /// **'Seansı çok erken iptal etmiş olabilirsin.'**
  String get leagueInfoFaqCancelled;

  /// No description provided for @leagueInfoFaqReset.
  ///
  /// In tr, this message translates to:
  /// **'Lig dönemi yeni sıfırlanmış olabilir.'**
  String get leagueInfoFaqReset;

  /// No description provided for @leagueInfoFaqPending.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışıyken tamamladığın seanslar bağlantı gelince gönderilir; puanın o zaman eklenir.'**
  String get leagueInfoFaqPending;

  /// No description provided for @friendsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlar'**
  String get friendsTitle;

  /// No description provided for @friendsMyCode.
  ///
  /// In tr, this message translates to:
  /// **'Senin Arkadaşlık Kodun'**
  String get friendsMyCode;

  /// No description provided for @friendsCopyCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu kopyala'**
  String get friendsCopyCode;

  /// No description provided for @friendsCodeCopied.
  ///
  /// In tr, this message translates to:
  /// **'Kod kopyalandı!'**
  String get friendsCodeCopied;

  /// No description provided for @friendsAddByCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod ile Arkadaş Ekle'**
  String get friendsAddByCode;

  /// No description provided for @friendsCodeHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn: A1B2C3'**
  String get friendsCodeHint;

  /// No description provided for @friendsAdded.
  ///
  /// In tr, this message translates to:
  /// **'✅ {name} arkadaş listene eklendi!'**
  String friendsAdded(String name);

  /// No description provided for @friendsRequestSent.
  ///
  /// In tr, this message translates to:
  /// **'📨 {name} kullanıcısına arkadaşlık isteği gönderildi. Onay bekleniyor.'**
  String friendsRequestSent(String name);

  /// No description provided for @friendsErrNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Bu koda sahip bir kullanıcı bulunamadı.'**
  String get friendsErrNotFound;

  /// No description provided for @friendsErrSelf.
  ///
  /// In tr, this message translates to:
  /// **'Kendi kodunu ekleyemezsin.'**
  String get friendsErrSelf;

  /// No description provided for @friendsErrAlreadyFriends.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcıyla zaten arkadaşsınız.'**
  String get friendsErrAlreadyFriends;

  /// No description provided for @friendsErrAlreadyPending.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcıyla bekleyen bir arkadaşlık isteğin zaten var.'**
  String get friendsErrAlreadyPending;

  /// No description provided for @friendsErrAddFailed.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaş eklenemedi. Kodu kontrol edip tekrar dene.'**
  String get friendsErrAddFailed;

  /// No description provided for @friendsIncoming.
  ///
  /// In tr, this message translates to:
  /// **'Gelen İstekler ({count})'**
  String friendsIncoming(int count);

  /// No description provided for @friendsAccept.
  ///
  /// In tr, this message translates to:
  /// **'Kabul et'**
  String get friendsAccept;

  /// No description provided for @friendsReject.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get friendsReject;

  /// No description provided for @friendsAccepted.
  ///
  /// In tr, this message translates to:
  /// **'✅ Arkadaşlık isteği kabul edildi!'**
  String get friendsAccepted;

  /// No description provided for @friendsRespondFailed.
  ///
  /// In tr, this message translates to:
  /// **'İstek yanıtlanamadı. Lütfen tekrar dene.'**
  String get friendsRespondFailed;

  /// No description provided for @friendsRequestGone.
  ///
  /// In tr, this message translates to:
  /// **'Bu istek artık geçerli değil.'**
  String get friendsRequestGone;

  /// No description provided for @friendsYourFriends.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşların ({count})'**
  String friendsYourFriends(int count);

  /// No description provided for @friendsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz arkadaşın yok. Kodunu paylaş veya yukarıdan bir kod gir!'**
  String get friendsEmpty;

  /// No description provided for @friendsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaş listen yüklenemedi. Bağlantını kontrol edip tekrar dene.'**
  String get friendsLoadError;

  /// No description provided for @profileNameTooShort.
  ///
  /// In tr, this message translates to:
  /// **'İsim en az 2 karakter olmalı.'**
  String get profileNameTooShort;

  /// No description provided for @profileNameTooLong.
  ///
  /// In tr, this message translates to:
  /// **'İsim en fazla 30 karakter olabilir.'**
  String get profileNameTooLong;

  /// No description provided for @profileDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını ve tüm verilerini kalıcı olarak silmek istediğinden emin misin?\n\nŞunların hepsi silinir ve geri alınamaz: çalışma geçmişin ve seansların, puanların ve serin, kum tanelerin ve avatarların, kategorilerin, arkadaşların ve lig kaydın.'**
  String get profileDeleteConfirm;

  /// No description provided for @profileDeleting.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın siliniyor...'**
  String get profileDeleting;

  /// No description provided for @profileDeleteError.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın silinemedi. Bağlantını kontrol edip tekrar dene.'**
  String get profileDeleteError;

  /// No description provided for @profileDeleteConfirmPending.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{Bu cihazda henüz gönderilmemiş 1 seansın da silinir.} other{Bu cihazda henüz gönderilmemiş {count} seansın da silinir.}}'**
  String profileDeleteConfirmPending(int count);

  /// No description provided for @profileDeleteConfirmApple.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile giriş yaptığın için silmeden önce Apple seni bir kez daha doğrulayacak; böylece PomoSprint\'in Apple ile Giriş bağlantısı da kaldırılır.'**
  String get profileDeleteConfirmApple;

  /// No description provided for @profileDeleteConfirmCopyHint.
  ///
  /// In tr, this message translates to:
  /// **'Verilerinin bir kopyasını istiyorsan önce \"Gizlilik ve yasal\" bölümündeki \"Verilerimin kopyasını iste\"yi kullan.'**
  String get profileDeleteConfirmCopyHint;

  /// No description provided for @accountDeletedNotice.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın ve tüm verilerin silindi.'**
  String get accountDeletedNotice;

  /// No description provided for @accountDeletedAppleNotice.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile Giriş bağlantısını da kaldırmak için iPhone\'da Ayarlar > Apple Hesabı (adın) > Apple ile Giriş > PomoSprint > Kullanmayı Durdur adımlarını izle.'**
  String get accountDeletedAppleNotice;

  /// No description provided for @sessionExpiredNotice.
  ///
  /// In tr, this message translates to:
  /// **'Oturumun sona erdi. Şifren değişmiş ya da hesabın başka bir cihazdan kapatılmış olabilir; lütfen yeniden giriş yap.'**
  String get sessionExpiredNotice;

  /// No description provided for @appleCredentialRevokedNotice.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda Apple ile Giriş izni kaldırıldığı için oturumun kapatıldı. Devam etmek için yeniden Apple ile giriş yap.'**
  String get appleCredentialRevokedNotice;

  /// No description provided for @noticeDismissTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get noticeDismissTooltip;

  /// No description provided for @profileNotificationsDenied.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni verilmedi. Bildirimleri telefonunun Ayarlar bölümünden PomoSprint için açabilirsin.'**
  String get profileNotificationsDenied;

  /// No description provided for @profileSettingSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Ayar kaydedilemedi. Lütfen tekrar dene.'**
  String get profileSettingSaveError;

  /// No description provided for @avatarBalance.
  ///
  /// In tr, this message translates to:
  /// **'Bakiyen: {coins} kum tanesi'**
  String avatarBalance(int coins);

  /// No description provided for @avatarPurchaseTitle.
  ///
  /// In tr, this message translates to:
  /// **'Satın Al'**
  String get avatarPurchaseTitle;

  /// No description provided for @avatarPurchaseBody.
  ///
  /// In tr, this message translates to:
  /// **'{name} avatarını {price} kum tanesine satın almak ister misin?'**
  String avatarPurchaseBody(String name, int price);

  /// No description provided for @avatarNotEnoughCoins.
  ///
  /// In tr, this message translates to:
  /// **'Yetersiz bakiye: {missing} kum tanesi daha gerekiyor.'**
  String avatarNotEnoughCoins(int missing);

  /// No description provided for @avatarPurchased.
  ///
  /// In tr, this message translates to:
  /// **'{name} artık senin!'**
  String avatarPurchased(String name);

  /// No description provided for @avatarPremiumTitle.
  ///
  /// In tr, this message translates to:
  /// **'Premium Avatar'**
  String get avatarPremiumTitle;

  /// No description provided for @avatarPremiumBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu avatar Premium üyelere özel.'**
  String get avatarPremiumBody;

  /// No description provided for @avatarPremiumUnlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Premium üyeliğinle {name} avatarını ücretsiz açabilirsin.'**
  String avatarPremiumUnlockBody(String name);

  /// No description provided for @avatarUnlockBtn.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get avatarUnlockBtn;

  /// No description provided for @coinsCaption.
  ///
  /// In tr, this message translates to:
  /// **'🪙 KUM'**
  String get coinsCaption;

  /// No description provided for @pendingSessionsBanner.
  ///
  /// In tr, this message translates to:
  /// **'{count} senkronize edilmemiş seansın var. Tekrar denemek için dokun.'**
  String pendingSessionsBanner(int count);

  /// No description provided for @sessionPointsBreakdown.
  ///
  /// In tr, this message translates to:
  /// **'🔥 {base} puan + {bonus} seri bonusu (%{pct}) = {total} puan!'**
  String sessionPointsBreakdown(int base, int bonus, int pct, int total);

  /// No description provided for @sessionDailyLimitReached.
  ///
  /// In tr, this message translates to:
  /// **'Bugünlük puan ve kum sınırına ulaştın ({limit} seans). Sonraki seanslar yalnızca çalışma süresine ve serine eklenir.'**
  String sessionDailyLimitReached(int limit);

  /// No description provided for @sessionResultSaving.
  ///
  /// In tr, this message translates to:
  /// **'Seans kaydediliyor…'**
  String get sessionResultSaving;

  /// No description provided for @sessionResultPoints.
  ///
  /// In tr, this message translates to:
  /// **'+{points} puan'**
  String sessionResultPoints(int points);

  /// No description provided for @sessionResultCoins.
  ///
  /// In tr, this message translates to:
  /// **'+{coins} kum'**
  String sessionResultCoins(int coins);

  /// No description provided for @sessionResultStreak.
  ///
  /// In tr, this message translates to:
  /// **'{days} günlük seri'**
  String sessionResultStreak(int days);

  /// No description provided for @sessionResultDuplicate.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans zaten kaydedilmişti; puanların daha önce eklendi.'**
  String get sessionResultDuplicate;

  /// No description provided for @sessionResultOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get sessionResultOk;

  /// No description provided for @sessionNotSavedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seans kaydedilemedi'**
  String get sessionNotSavedTitle;

  /// No description provided for @sessionQueuedOffline.
  ///
  /// In tr, this message translates to:
  /// **'Seans cihazına kaydedildi; bağlantı gelince otomatik gönderilecek. Puan ve kum için 24 saat içinde çevrimiçi olman gerekiyor.'**
  String get sessionQueuedOffline;

  /// No description provided for @sessionQueuedClockSkew.
  ///
  /// In tr, this message translates to:
  /// **'Seans bekletiliyor: cihazının saati sunucudan farklı görünüyor. Saat ayarını kontrol et; seans otomatik olarak yeniden denenecek.'**
  String get sessionQueuedClockSkew;

  /// No description provided for @sessionQueuedOverlap.
  ///
  /// In tr, this message translates to:
  /// **'Seans önceki bir kayıtla çakışıyor; bekletiliyor ve daha sonra yeniden denenecek.'**
  String get sessionQueuedOverlap;

  /// No description provided for @sessionRejectedTooOld.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans 24 saatten eski olduğu için kaydedilemedi.'**
  String get sessionRejectedTooOld;

  /// No description provided for @sessionRejectedClock.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilemedi: cihazının saati ileri görünüyor. Saat ayarını kontrol et.'**
  String get sessionRejectedClock;

  /// No description provided for @sessionRejectedOverlap.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilemedi: aynı zaman aralığında kayıtlı başka bir seans var.'**
  String get sessionRejectedOverlap;

  /// No description provided for @sessionRejectedGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilemedi: sunucu doğrulamasından geçmedi.'**
  String get sessionRejectedGeneric;

  /// No description provided for @rejectedSessionsNotice.
  ///
  /// In tr, this message translates to:
  /// **'⚠️ Bekleyen {count} seans sunucu tarafından reddedildi ve kaydedilemedi.'**
  String rejectedSessionsNotice(int count);

  /// No description provided for @rejectedSessionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemeyen seanslar'**
  String get rejectedSessionsTitle;

  /// No description provided for @rejectedSessionsInfo.
  ///
  /// In tr, this message translates to:
  /// **'Sunucunun kabul etmediği seanslar burada listelenir; puana, kuma ve seriye eklenmezler. Bu cihazda son 50 kayıt tutulur.'**
  String get rejectedSessionsInfo;

  /// No description provided for @rejectedSessionsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemeyen seans yok.'**
  String get rejectedSessionsEmpty;

  /// No description provided for @rejectedSessionsLink.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemeyen seanslar ({count})'**
  String rejectedSessionsLink(int count);

  /// No description provided for @rejectedSessionsView.
  ///
  /// In tr, this message translates to:
  /// **'Göster'**
  String get rejectedSessionsView;

  /// No description provided for @pausedSessionExpired.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatılmış seansın 24 saati aştığı için kaydedilemedi ve sıfırlandı.'**
  String get pausedSessionExpired;

  /// No description provided for @leaveWhileRunningTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seansın sürüyor'**
  String get leaveWhileRunningTitle;

  /// No description provided for @leaveWhileRunningBody.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamadan çıksan da sayaç çalışmaya devam eder; geri döndüğünde seansın kaldığı yerden sürer.'**
  String get leaveWhileRunningBody;

  /// No description provided for @leaveWhileRunningStay.
  ///
  /// In tr, this message translates to:
  /// **'Kal'**
  String get leaveWhileRunningStay;

  /// No description provided for @leaveWhileRunningLeave.
  ///
  /// In tr, this message translates to:
  /// **'Arka plana al'**
  String get leaveWhileRunningLeave;

  /// No description provided for @notifSessionDoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro tamamlandı! 🎉'**
  String get notifSessionDoneTitle;

  /// No description provided for @notifSessionDoneBody.
  ///
  /// In tr, this message translates to:
  /// **'{category} seansın bitti. Puan ve kum kazanman için 24 saat içinde uygulamayı aç.'**
  String notifSessionDoneBody(String category);

  /// No description provided for @notifChannelName.
  ///
  /// In tr, this message translates to:
  /// **'Seans bildirimleri'**
  String get notifChannelName;

  /// No description provided for @notifChannelDescription.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro seansın bittiğinde haber verir.'**
  String get notifChannelDescription;

  /// No description provided for @lockTimerChannelName.
  ///
  /// In tr, this message translates to:
  /// **'Süren seans'**
  String get lockTimerChannelName;

  /// No description provided for @lockTimerChannelDescription.
  ///
  /// In tr, this message translates to:
  /// **'Seans sürerken kalan süreyi kilit ekranında ve bildirim panelinde gösterir.'**
  String get lockTimerChannelDescription;

  /// No description provided for @lockTimerRunningBody.
  ///
  /// In tr, this message translates to:
  /// **'Odaklanıyorsun · bitiş {time}'**
  String lockTimerRunningBody(String time);

  /// No description provided for @lockTimerPausedBody.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatıldı · {remaining} kaldı'**
  String lockTimerPausedBody(String remaining);

  /// No description provided for @lockTimerStatusRunning.
  ///
  /// In tr, this message translates to:
  /// **'Odaklanıyorsun'**
  String get lockTimerStatusRunning;

  /// No description provided for @lockTimerStatusPaused.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatıldı'**
  String get lockTimerStatusPaused;

  /// No description provided for @lockTimerStatusDone.
  ///
  /// In tr, this message translates to:
  /// **'Seans tamamlandı'**
  String get lockTimerStatusDone;

  /// No description provided for @lockTimerDoneHint.
  ///
  /// In tr, this message translates to:
  /// **'Seansını kaydetmek için 24 saat içinde PomoSprint\'i aç.'**
  String get lockTimerDoneHint;

  /// No description provided for @statsLoadErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler yüklenemedi'**
  String get statsLoadErrorTitle;

  /// No description provided for @statsLoadErrorOffline.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.'**
  String get statsLoadErrorOffline;

  /// No description provided for @statsLoadErrorSignedOut.
  ///
  /// In tr, this message translates to:
  /// **'İstatistiklerini görmek için tekrar giriş yapman gerekiyor.'**
  String get statsLoadErrorSignedOut;

  /// No description provided for @statsLoadErrorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Veriler alınırken bir sorun oluştu. Lütfen tekrar dene.'**
  String get statsLoadErrorGeneric;

  /// No description provided for @statsRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get statsRetry;

  /// No description provided for @statsStaleNotice.
  ///
  /// In tr, this message translates to:
  /// **'Güncel veriler alınamadı; son yüklenen veriler gösteriliyor.'**
  String get statsStaleNotice;

  /// No description provided for @statsPendingSessions.
  ///
  /// In tr, this message translates to:
  /// **'{count} seans senkron bekliyor'**
  String statsPendingSessions(int count);

  /// No description provided for @statsNoStudyTodayTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugün henüz çalışmadın'**
  String get statsNoStudyTodayTitle;

  /// No description provided for @statsNoStudyTodayDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bir Pomodoro başlat; bugünün ders dağılımı burada görünecek.'**
  String get statsNoStudyTodayDesc;

  /// No description provided for @statsNoStudyThisWeekTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta henüz çalışmadın'**
  String get statsNoStudyThisWeekTitle;

  /// No description provided for @statsNoStudyThisWeekDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bir Pomodoro başlat; haftalık analizin burada oluşacak.'**
  String get statsNoStudyThisWeekDesc;

  /// No description provided for @statsGoalSheetSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Günde ne kadar odaklanmak istiyorsun?'**
  String get statsGoalSheetSubtitle;

  /// No description provided for @statsGoalPomodoroApprox.
  ///
  /// In tr, this message translates to:
  /// **'≈ {count} Pomodoro'**
  String statsGoalPomodoroApprox(int count);

  /// No description provided for @statsGoalSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Hedef kaydedilemedi. Bağlantını kontrol edip tekrar dene.'**
  String get statsGoalSaveFailed;

  /// No description provided for @statsTodayPomodoros.
  ///
  /// In tr, this message translates to:
  /// **'Bugün {count} Pomodoro tamamlandı'**
  String statsTodayPomodoros(int count);

  /// No description provided for @statsWeeklyGoalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık Hedef'**
  String get statsWeeklyGoalTitle;

  /// No description provided for @statsWeeklyGoalSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'{weekly} · günlük hedefin × 7'**
  String statsWeeklyGoalSubtitle(String weekly);

  /// No description provided for @statsWeekLabel.
  ///
  /// In tr, this message translates to:
  /// **'Hafta {index}'**
  String statsWeekLabel(int index);

  /// No description provided for @statsWeekStudyTotal.
  ///
  /// In tr, this message translates to:
  /// **'{duration} Çalışma'**
  String statsWeekStudyTotal(String duration);

  /// No description provided for @statsWeekChangeUp.
  ///
  /// In tr, this message translates to:
  /// **'Önceki haftanın aynı günlerine göre {percent} artış'**
  String statsWeekChangeUp(String percent);

  /// No description provided for @statsWeekChangeDown.
  ///
  /// In tr, this message translates to:
  /// **'Önceki haftanın aynı günlerine göre {percent} düşüş'**
  String statsWeekChangeDown(String percent);

  /// No description provided for @statsMonthMotivation.
  ///
  /// In tr, this message translates to:
  /// **'Geçen ayın aynı dönemine göre odağını {percent} artırdın, harika gidiyorsun!'**
  String statsMonthMotivation(String percent);

  /// No description provided for @statsMonthEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay henüz çalışma kaydın yok'**
  String get statsMonthEmptyTitle;

  /// No description provided for @statsMonthEmptyDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay ilk Pomodoro\'nu tamamladığında aylık takip burada görünecek.'**
  String get statsMonthEmptyDesc;

  /// No description provided for @statsOtherCategory.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get statsOtherCategory;

  /// No description provided for @statsShowAsDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre olarak göster'**
  String get statsShowAsDuration;

  /// No description provided for @statsShowAsPercent.
  ///
  /// In tr, this message translates to:
  /// **'Yüzde olarak göster'**
  String get statsShowAsPercent;

  /// No description provided for @statsOfflinePendingOnly.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya bağlanılamadı; yalnızca bu cihazda senkron bekleyen seanslar gösteriliyor.'**
  String get statsOfflinePendingOnly;

  /// No description provided for @statsOtherCategories.
  ///
  /// In tr, this message translates to:
  /// **'Diğer kategoriler'**
  String get statsOtherCategories;

  /// No description provided for @statsMoreCategories.
  ///
  /// In tr, this message translates to:
  /// **'+{count} kategori daha'**
  String statsMoreCategories(int count);

  /// No description provided for @statsGoalReached.
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü hedefine ulaştın, tebrikler!'**
  String get statsGoalReached;

  /// No description provided for @statsTipFocusBlock.
  ///
  /// In tr, this message translates to:
  /// **'Seansa başlamadan önce o seansta bitireceğin tek bir işi belirle.'**
  String get statsTipFocusBlock;

  /// No description provided for @statsWeekNotStarted.
  ///
  /// In tr, this message translates to:
  /// **'Henüz başlamadın'**
  String get statsWeekNotStarted;

  /// No description provided for @statsWeekChangeSame.
  ///
  /// In tr, this message translates to:
  /// **'Önceki haftanın aynı günleriyle aynı'**
  String get statsWeekChangeSame;

  /// No description provided for @statsGoalPomodorosNeeded.
  ///
  /// In tr, this message translates to:
  /// **'Hedef için {count} Pomodoro'**
  String statsGoalPomodorosNeeded(int count);

  /// No description provided for @authErrWeakPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifren çok zayıf. En az 1 küçük harf (a-z), 1 büyük harf (A-Z) ve 1 rakam (0-9) içermeli.'**
  String get authErrWeakPassword;

  /// No description provided for @authErrEmailExistsResent.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kayıtlı! Doğrulama bağlantısı e-postana tekrar gönderildi.'**
  String get authErrEmailExistsResent;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi veya şifre hatalı ya da hesabın henüz onaylanmamış olabilir. Şifreni kontrol et; sorun sürerse aşağıdan onay e-postasını tekrar gönderebilirsin.'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresin henüz doğrulanmamış. Lütfen gelen kutundaki onay bağlantısına tıkla.'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyip tekrar dene.'**
  String get authErrRateLimited;

  /// No description provided for @authErrNetwork.
  ///
  /// In tr, this message translates to:
  /// **'İnternet veya sunucu bağlantısı kurulamadı. Lütfen ağ bağlantını kontrol et.'**
  String get authErrNetwork;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen geçerli bir e-posta adresi gir.'**
  String get authErrInvalidEmail;

  /// No description provided for @authErrCloudUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya bağlanılamadı. Lütfen internet bağlantını kontrol et.'**
  String get authErrCloudUnavailable;

  /// No description provided for @authErrProfileLoad.
  ///
  /// In tr, this message translates to:
  /// **'Profilin yüklenemedi. Lütfen bağlantını kontrol edip tekrar giriş yap.'**
  String get authErrProfileLoad;

  /// No description provided for @authErrGoogleFailed.
  ///
  /// In tr, this message translates to:
  /// **'Google ile giriş yapılamadı. Lütfen tekrar dene.'**
  String get authErrGoogleFailed;

  /// No description provided for @authErrAppleFailed.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile giriş yapılamadı. Lütfen tekrar dene.'**
  String get authErrAppleFailed;

  /// No description provided for @authErrUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar dene.'**
  String get authErrUnknown;

  /// No description provided for @authErrSignUpTimeout.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt isteği yanıt vermedi. Kaydın yine de tamamlanmış olabilir: e-postanı kontrol et ya da giriş yapmayı dene.'**
  String get authErrSignUpTimeout;

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

  /// No description provided for @leagueAwardsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig Kazanımları'**
  String get leagueAwardsTitle;

  /// No description provided for @leagueAwardsSub.
  ///
  /// In tr, this message translates to:
  /// **'Bir lig dönemini puan toplayarak ilk 3\'te bitirince kazanılır: 1.\'ye Şampiyonluk, 2. ve 3.\'ye Podyum Ödülü.'**
  String get leagueAwardsSub;

  /// No description provided for @leagueAwardLockedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu Avatar Kilitli'**
  String get leagueAwardLockedTitle;

  /// No description provided for @leagueAwardLockedBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu avatarı kazanmak için bu kademede bir lig dönemini puan toplayarak ilk 3\'te bitirmen gerekiyor. Parayla satın alınamaz.'**
  String get leagueAwardLockedBody;

  /// No description provided for @leagueAwardLockedBodyChampion.
  ///
  /// In tr, this message translates to:
  /// **'Bu Şampiyonluk Ödülü\'nü kazanmak için bu kademede bir lig dönemini puan toplayarak 1. sırada bitirmen gerekiyor. Parayla satın alınamaz.'**
  String get leagueAwardLockedBodyChampion;

  /// No description provided for @leagueAwardLockedBodyPodium.
  ///
  /// In tr, this message translates to:
  /// **'Bu Podyum Ödülü\'nü kazanmak için bu kademede bir lig dönemini puan toplayarak 2. veya 3. sırada bitirmen gerekiyor (1. olan Şampiyonluk Ödülü\'nü alır). Parayla satın alınamaz.'**
  String get leagueAwardLockedBodyPodium;

  /// No description provided for @leagueAwardLockedOk.
  ///
  /// In tr, this message translates to:
  /// **'Anladım'**
  String get leagueAwardLockedOk;

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
  /// **'Google ile Giriş Yap'**
  String get googleLogin;

  /// No description provided for @appleOnAndroidLink.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile mi kaydoldun?'**
  String get appleOnAndroidLink;

  /// No description provided for @appleOnAndroidTitle.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile açılan hesaba Android\'den giriş'**
  String get appleOnAndroidTitle;

  /// No description provided for @appleOnAndroidBody.
  ///
  /// In tr, this message translates to:
  /// **'Android\'de Apple ile giriş yok; hesabına e-posta ve şifreyle girebilirsin:\n\n1. Hesabının e-posta adresini bul. Apple\'da \"E-postamı Gizle\"yi seçtiysen bu bir gizli röle adresidir (…@privaterelay.appleid.com); iPhone\'da Ayarlar > Apple Hesabı (adın) > Apple ile Giriş > PomoSprint altında görünür.\n2. Bu ekranda o adresi yazıp \"Şifremi Unuttum\"a dokun ve gelen bağlantıyla bir şifre belirle.\n3. Sonra aynı adres ve yeni şifrenle giriş yap.\n\nE-posta gelmezse destek@pomosprint.app adresine yaz.'**
  String get appleOnAndroidBody;

  /// No description provided for @resendVerificationLink.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama E-postasını Tekrar Gönder 📬'**
  String get resendVerificationLink;

  /// No description provided for @loginVerificationPendingInfo.
  ///
  /// In tr, this message translates to:
  /// **'Onay bağlantısını {email} adresine gönderdik. Bağlantıya dokunduktan sonra şifrenle buradan giriş yap.'**
  String loginVerificationPendingInfo(String email);

  /// No description provided for @loginResendPrompt.
  ///
  /// In tr, this message translates to:
  /// **'E-posta gelmedi mi? Yeniden gönder'**
  String get loginResendPrompt;

  /// No description provided for @errEnterEmailForResend.
  ///
  /// In tr, this message translates to:
  /// **'Onay e-postasını yeniden göndermek için önce e-posta adresini yaz.'**
  String get errEnterEmailForResend;

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
  /// **'E-posta adresine bir şifre sıfırlama bağlantısı gönderdik. Gelen kutunu (ve spam klasörünü) kontrol et.'**
  String get passwordResetMsg;

  /// No description provided for @errEnterEmailForReset.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni sıfırlamak için önce e-posta adresini gir.'**
  String get errEnterEmailForReset;

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

  /// No description provided for @termsAgreePrefix.
  ///
  /// In tr, this message translates to:
  /// **''**
  String get termsAgreePrefix;

  /// No description provided for @termsLinkTerms.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları\'nı'**
  String get termsLinkTerms;

  /// No description provided for @termsAgreeConnector.
  ///
  /// In tr, this message translates to:
  /// **' ve '**
  String get termsAgreeConnector;

  /// No description provided for @termsLinkPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası\'nı'**
  String get termsLinkPrivacy;

  /// No description provided for @termsAgreeSuffix.
  ///
  /// In tr, this message translates to:
  /// **' okudum, onaylıyorum.'**
  String get termsAgreeSuffix;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get privacyPolicyLink;

  /// No description provided for @termsOfServiceLink.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları'**
  String get termsOfServiceLink;

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
  /// **'Devam etmek için Kullanım Şartları\'nı kabul etmelisin.'**
  String get errAcceptTerms;

  /// No description provided for @errEmailExists.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kayıtlı. \"Giriş Yap\" ekranından giriş yap. Bu adresle Google ya da Apple ile kaydolduysan o butonu kullan ya da \"Şifremi Unuttum\" ile bir şifre belirle.'**
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

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yapılsın mı?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazdaki oturumun kapanacak. İstediğin zaman aynı hesapla yeniden giriş yapabilirsin.'**
  String get logoutConfirmBody;

  /// No description provided for @logoutPendingWarning.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{1 seansın henüz sunucuya gönderilmedi.} other{{count} seansın henüz sunucuya gönderilmedi.}} Seans başladıktan sonraki 24 saat içinde aynı hesapla bu cihazdan giriş yapmazsan puanı, kum taneleri ve seriye katkısı kaybolur.'**
  String logoutPendingWarning(int count);

  /// No description provided for @logoutRunningWarning.
  ///
  /// In tr, this message translates to:
  /// **'Süren bir seansın var. Seans bu cihazda saklanır ve aynı hesapla yeniden girince kaldığı yerden sürer; ama çıkış yaptıktan sonra bitiş bildirimi gelmez.'**
  String get logoutRunningWarning;

  /// No description provided for @logoutSendAndExit.
  ///
  /// In tr, this message translates to:
  /// **'Gönder ve çık'**
  String get logoutSendAndExit;

  /// No description provided for @logoutAnyway.
  ///
  /// In tr, this message translates to:
  /// **'Yine de çık'**
  String get logoutAnyway;

  /// No description provided for @logoutSendFailed.
  ///
  /// In tr, this message translates to:
  /// **'Seanslar şu an gönderilemedi. Bağlantını kontrol edip tekrar dene.'**
  String get logoutSendFailed;

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

  /// No description provided for @addBtn.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get addBtn;

  /// No description provided for @onboardingSelectOptionError.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir seçenek seçin.'**
  String get onboardingSelectOptionError;

  /// No description provided for @onboardingTimeoutError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı zaman aşımına uğradı. Lütfen internetini kontrol edip tekrar dene.'**
  String get onboardingTimeoutError;

  /// No description provided for @onboardingGenericError.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti, lütfen tekrar dene: {error}'**
  String onboardingGenericError(Object error);

  /// No description provided for @onboardingAddCategoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategori Ekle'**
  String get onboardingAddCategoryTitle;

  /// No description provided for @onboardingCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get onboardingCategoryHint;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldin! 👋'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In tr, this message translates to:
  /// **'Ben senin odaklanma arkadaşınım. Başlamadan önce doğum yılını seçer misin? Bunu yalnızca yaş sınırını kontrol etmek için soruyoruz.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingSegmentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Peki, hangi yolculuktasın?'**
  String get onboardingSegmentTitle;

  /// No description provided for @onboardingSegmentBody.
  ///
  /// In tr, this message translates to:
  /// **'Beraber neye çalışacağız? Sana uygun kategorileri önereyim. Uymuyorsa \"Diğer\"i seç.'**
  String get onboardingSegmentBody;

  /// No description provided for @onboardingSegmentLgs.
  ///
  /// In tr, this message translates to:
  /// **'🎓  LGS'**
  String get onboardingSegmentLgs;

  /// No description provided for @onboardingSegmentYks.
  ///
  /// In tr, this message translates to:
  /// **'📚  YKS'**
  String get onboardingSegmentYks;

  /// No description provided for @onboardingSegmentUniversity.
  ///
  /// In tr, this message translates to:
  /// **'🏛️  Üniversite'**
  String get onboardingSegmentUniversity;

  /// No description provided for @onboardingSegmentWork.
  ///
  /// In tr, this message translates to:
  /// **'💼  İş & Kişisel Gelişim'**
  String get onboardingSegmentWork;

  /// No description provided for @onboardingCategoryStepTitle.
  ///
  /// In tr, this message translates to:
  /// **'Harika seçim! 🎉'**
  String get onboardingCategoryStepTitle;

  /// No description provided for @onboardingCreateOwnCategory.
  ///
  /// In tr, this message translates to:
  /// **'+ Kendi kategorimi oluştur'**
  String get onboardingCreateOwnCategory;

  /// No description provided for @onboardingGoalStepTitle.
  ///
  /// In tr, this message translates to:
  /// **'Son bir adım kaldı! 🚀'**
  String get onboardingGoalStepTitle;

  /// No description provided for @onboardingGoalStepBody.
  ///
  /// In tr, this message translates to:
  /// **'Günde ne kadar birlikte odaklanmak istersin?'**
  String get onboardingGoalStepBody;

  /// No description provided for @onboardingGoal1h.
  ///
  /// In tr, this message translates to:
  /// **'1 Saat'**
  String get onboardingGoal1h;

  /// No description provided for @onboardingGoal2h.
  ///
  /// In tr, this message translates to:
  /// **'2 Saat'**
  String get onboardingGoal2h;

  /// No description provided for @onboardingGoal3h.
  ///
  /// In tr, this message translates to:
  /// **'3 Saat'**
  String get onboardingGoal3h;

  /// No description provided for @onboardingGoal4hPlus.
  ///
  /// In tr, this message translates to:
  /// **'4 Saat+'**
  String get onboardingGoal4hPlus;

  /// No description provided for @onboardingFinishBtn.
  ///
  /// In tr, this message translates to:
  /// **'Bitir'**
  String get onboardingFinishBtn;

  /// No description provided for @categoriesManagementTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategorilerim'**
  String get categoriesManagementTitle;

  /// No description provided for @categoryLimitReachedMsg.
  ///
  /// In tr, this message translates to:
  /// **'Limitinize ulaştınız. En fazla {limit} kategori ekleyebilirsiniz.'**
  String categoryLimitReachedMsg(int limit);

  /// No description provided for @newCategoryDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Kategori'**
  String get newCategoryDialogTitle;

  /// No description provided for @editCategoryDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategori Düzenle'**
  String get editCategoryDialogTitle;

  /// No description provided for @activeCategoryCountLabel.
  ///
  /// In tr, this message translates to:
  /// **'Aktif Kategori Sayısı'**
  String get activeCategoryCountLabel;

  /// No description provided for @archiveCategoryTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Arşivle (Silmek yerine geçmiş raporlar için saklanır)'**
  String get archiveCategoryTooltip;

  /// No description provided for @archivedCategoriesHeader.
  ///
  /// In tr, this message translates to:
  /// **'Arşivlenmiş Kategoriler'**
  String get archivedCategoriesHeader;

  /// No description provided for @archivedCategoriesDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategoriler ders seçicide görünmez ama geçmiş raporlarda yer alır.'**
  String get archivedCategoriesDesc;

  /// No description provided for @unarchiveTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Arşivi Aç'**
  String get unarchiveTooltip;

  /// No description provided for @categoryLastActiveRequired.
  ///
  /// In tr, this message translates to:
  /// **'En az bir aktif kategorin olmalı. Önce yeni bir kategori ekle ya da arşivden birini çıkar.'**
  String get categoryLastActiveRequired;

  /// No description provided for @timerResetBtn.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get timerResetBtn;

  /// No description provided for @timerResetConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seans sıfırlansın mı?'**
  String get timerResetConfirmTitle;

  /// No description provided for @timerResetConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilmeden silinecek; puan ve kum kazanmayacaksın. Bu işlem geri alınamaz.'**
  String get timerResetConfirmBody;

  /// No description provided for @timerResetConfirmAction.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get timerResetConfirmAction;

  /// No description provided for @timerDurationLocked.
  ///
  /// In tr, this message translates to:
  /// **'Süreyi değiştirmek için önce seansı sıfırla.'**
  String get timerDurationLocked;

  /// No description provided for @rankingZonePromotionChip.
  ///
  /// In tr, this message translates to:
  /// **'↑ Terfi'**
  String get rankingZonePromotionChip;

  /// No description provided for @rankingZoneDemotionChip.
  ///
  /// In tr, this message translates to:
  /// **'↓ Düşme'**
  String get rankingZoneDemotionChip;

  /// No description provided for @rankingZonePromotionMe.
  ///
  /// In tr, this message translates to:
  /// **'Terfi bölgesindesin: dönem böyle biterse bir üst lige çıkarsın.'**
  String get rankingZonePromotionMe;

  /// No description provided for @rankingZoneNeedsPointsMe.
  ///
  /// In tr, this message translates to:
  /// **'Terfi bölgesindesin ama 0 puanla terfi edilmez. Bir seans tamamla.'**
  String get rankingZoneNeedsPointsMe;

  /// No description provided for @rankingZoneDemotionMe.
  ///
  /// In tr, this message translates to:
  /// **'Düşme bölgesindesin: dönem böyle biterse bir alt lige inersin.'**
  String get rankingZoneDemotionMe;

  /// No description provided for @authSocialNoticePrefix.
  ///
  /// In tr, this message translates to:
  /// **'Devam ederek '**
  String get authSocialNoticePrefix;

  /// No description provided for @authSocialNoticeTermsLink.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları\'nı'**
  String get authSocialNoticeTermsLink;

  /// No description provided for @authSocialNoticeMiddle.
  ///
  /// In tr, this message translates to:
  /// **' kabul etmiş ve '**
  String get authSocialNoticeMiddle;

  /// No description provided for @authSocialNoticeKvkkLink.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni\'ni'**
  String get authSocialNoticeKvkkLink;

  /// No description provided for @authSocialNoticeSuffix.
  ///
  /// In tr, this message translates to:
  /// **' okumuş olursun.'**
  String get authSocialNoticeSuffix;

  /// No description provided for @legalOpenFailed.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa açılamadı. Tarayıcında şu adresi açabilirsin: {url}'**
  String legalOpenFailed(String url);

  /// No description provided for @registerNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Görünen ad'**
  String get registerNameLabel;

  /// No description provided for @registerNameHelper.
  ///
  /// In tr, this message translates to:
  /// **'Sıralamada ve arkadaş listelerinde bu ad görünür.'**
  String get registerNameHelper;

  /// No description provided for @registerErrNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Görünen adını gir.'**
  String get registerErrNameRequired;

  /// No description provided for @registerErrNameTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Ad en fazla 50 karakter olabilir.'**
  String get registerErrNameTooLong;

  /// No description provided for @nameNotAllowed.
  ///
  /// In tr, this message translates to:
  /// **'Bu ad uygun değil. Lütfen başka bir ad seç.'**
  String get nameNotAllowed;

  /// No description provided for @registerErrEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresini gir.'**
  String get registerErrEmailRequired;

  /// No description provided for @registerErrPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bir şifre belirle.'**
  String get registerErrPasswordRequired;

  /// No description provided for @registerPasswordHelper.
  ///
  /// In tr, this message translates to:
  /// **'En az 6 karakter; büyük harf, küçük harf ve rakam içermeli.'**
  String get registerPasswordHelper;

  /// No description provided for @passwordRuleLength.
  ///
  /// In tr, this message translates to:
  /// **'En az 6 karakter'**
  String get passwordRuleLength;

  /// No description provided for @passwordRuleCase.
  ///
  /// In tr, this message translates to:
  /// **'Büyük ve küçük harf (A-Z, a-z)'**
  String get passwordRuleCase;

  /// No description provided for @passwordRuleDigit.
  ///
  /// In tr, this message translates to:
  /// **'En az bir rakam (0-9)'**
  String get passwordRuleDigit;

  /// No description provided for @changePasswordTile.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi değiştir'**
  String get changePasswordTile;

  /// No description provided for @changePasswordTileSub.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifrenle doğrulayıp yeni bir şifre belirle.'**
  String get changePasswordTileSub;

  /// No description provided for @changePasswordCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifre'**
  String get changePasswordCurrent;

  /// No description provided for @changePasswordNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre'**
  String get changePasswordNew;

  /// No description provided for @changePasswordRepeat.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre (tekrar)'**
  String get changePasswordRepeat;

  /// No description provided for @changePasswordMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifreler aynı değil.'**
  String get changePasswordMismatch;

  /// No description provided for @changePasswordSame.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre mevcut şifrenle aynı olamaz.'**
  String get changePasswordSame;

  /// No description provided for @changePasswordWrongCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifre hatalı.'**
  String get changePasswordWrongCurrent;

  /// No description provided for @changePasswordSave.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi güncelle'**
  String get changePasswordSave;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Şifren güncellendi. Diğer cihazlardaki oturumların kapanmış olabilir.'**
  String get changePasswordSuccess;

  /// No description provided for @registerShowPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi göster'**
  String get registerShowPassword;

  /// No description provided for @registerHidePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi gizle'**
  String get registerHidePassword;

  /// No description provided for @registerConsentsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Onaylar'**
  String get registerConsentsTitle;

  /// No description provided for @registerConsentRequiredTag.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu'**
  String get registerConsentRequiredTag;

  /// No description provided for @registerConsentOptionalTag.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı'**
  String get registerConsentOptionalTag;

  /// No description provided for @registerConsentTermsPrefix.
  ///
  /// In tr, this message translates to:
  /// **''**
  String get registerConsentTermsPrefix;

  /// No description provided for @registerConsentTermsLink.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları\'nı'**
  String get registerConsentTermsLink;

  /// No description provided for @registerConsentTermsSuffix.
  ///
  /// In tr, this message translates to:
  /// **' okudum ve kabul ediyorum.'**
  String get registerConsentTermsSuffix;

  /// No description provided for @registerConsentPrivacyPrefix.
  ///
  /// In tr, this message translates to:
  /// **''**
  String get registerConsentPrivacyPrefix;

  /// No description provided for @registerConsentKvkkLink.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni\'ni'**
  String get registerConsentKvkkLink;

  /// No description provided for @registerConsentPrivacyConnector.
  ///
  /// In tr, this message translates to:
  /// **' ve '**
  String get registerConsentPrivacyConnector;

  /// No description provided for @registerConsentPrivacyLink.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası\'nı'**
  String get registerConsentPrivacyLink;

  /// No description provided for @registerConsentPrivacySuffix.
  ///
  /// In tr, this message translates to:
  /// **' okudum.'**
  String get registerConsentPrivacySuffix;

  /// No description provided for @registerConsentMarketing.
  ///
  /// In tr, this message translates to:
  /// **'Yeni özellikler ve güncellemeler hakkında bana e-posta gönderilmesini kabul ediyorum (ticari elektronik ileti onayı).'**
  String get registerConsentMarketing;

  /// No description provided for @registerConsentMarketingHint.
  ///
  /// In tr, this message translates to:
  /// **'İstediğin zaman e-postalardaki bağlantıyla abonelikten çıkabilirsin.'**
  String get registerConsentMarketingHint;

  /// No description provided for @errAcknowledgePrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için KVKK Aydınlatma Metni\'ni ve Gizlilik Politikası\'nı okuduğunu onaylamalısın.'**
  String get errAcknowledgePrivacy;

  /// No description provided for @profileLegalSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve yasal'**
  String get profileLegalSectionTitle;

  /// No description provided for @kvkkNoticeLink.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni'**
  String get kvkkNoticeLink;

  /// No description provided for @accountDeletionInfoLink.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme hakkında'**
  String get accountDeletionInfoLink;

  /// No description provided for @accountDeletionInfoSub.
  ///
  /// In tr, this message translates to:
  /// **'Hangi verilerin silindiği ve web üzerinden silme talebi'**
  String get accountDeletionInfoSub;

  /// No description provided for @dataCopyRequestTile.
  ///
  /// In tr, this message translates to:
  /// **'Verilerimin kopyasını iste'**
  String get dataCopyRequestTile;

  /// No description provided for @dataCopyRequestSub.
  ///
  /// In tr, this message translates to:
  /// **'KVKK m.11 kapsamında. E-posta uygulaman açılır; hesabındaki e-posta adresinden gönder.'**
  String get dataCopyRequestSub;

  /// No description provided for @dataCopyEmailSubject.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint kişisel veri kopyası talebi (KVKK m.11)'**
  String get dataCopyEmailSubject;

  /// No description provided for @dataCopyEmailBody.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba,\n\nKVKK m.11 kapsamında PomoSprint hesabıma ait kişisel verilerin bir kopyasını talep ediyorum. Bu e-postayı hesabımda kayıtlı e-posta adresinden gönderiyorum.\n\nTercih ettiğim biçim (ör. JSON, PDF):\n'**
  String get dataCopyEmailBody;

  /// No description provided for @dataCopyMailFailed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta uygulaması açılamadı. Talebini hesabındaki e-posta adresinden {email} adresine gönderebilirsin.'**
  String dataCopyMailFailed(String email);

  /// No description provided for @deleteAccountSub.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını ve tüm verilerini kalıcı olarak siler.'**
  String get deleteAccountSub;

  /// No description provided for @hiddenUsersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gizlenen kullanıcıları göster'**
  String get hiddenUsersTitle;

  /// No description provided for @hiddenUsersCount.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Gizlenen kullanıcı yok} other{{count} kullanıcı gizli · dokununca liste sıfırlanır}}'**
  String hiddenUsersCount(int count);

  /// No description provided for @hiddenUsersCleared.
  ///
  /// In tr, this message translates to:
  /// **'Gizlenen kullanıcılar yeniden görünecek.'**
  String get hiddenUsersCleared;

  /// No description provided for @userActionsTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı seçenekleri'**
  String get userActionsTooltip;

  /// No description provided for @reportUserAction.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcıyı bildir'**
  String get reportUserAction;

  /// No description provided for @reportUserActionSub.
  ///
  /// In tr, this message translates to:
  /// **'Uygunsuz bir adı ya da davranışı destek ekibine e-postayla bildir.'**
  String get reportUserActionSub;

  /// No description provided for @hideUserAction.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcıyı gizle'**
  String get hideUserAction;

  /// No description provided for @hideUserActionSub.
  ///
  /// In tr, this message translates to:
  /// **'Sıralamada adı gizlenir, canlı akışta görünmez. Profil\'den geri alabilirsin.'**
  String get hideUserActionSub;

  /// No description provided for @userHiddenMsg.
  ///
  /// In tr, this message translates to:
  /// **'{name} gizlendi.'**
  String userHiddenMsg(String name);

  /// No description provided for @undoAction.
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get undoAction;

  /// No description provided for @hiddenUserLabel.
  ///
  /// In tr, this message translates to:
  /// **'Gizlenen kullanıcı'**
  String get hiddenUserLabel;

  /// No description provided for @reportEmailSubject.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint kullanıcı bildirimi: {name}'**
  String reportEmailSubject(String name);

  /// No description provided for @reportEmailBody.
  ///
  /// In tr, this message translates to:
  /// **'Bildirilen görünen ad: {name}\nKullanıcı kimliği: {userId}\nGörüldüğü yer: {place}\n\nNeyi bildiriyorsun? Lütfen kısaca açıkla:\n'**
  String reportEmailBody(String name, String userId, String place);

  /// No description provided for @reportUserIdUnknown.
  ///
  /// In tr, this message translates to:
  /// **'bilinmiyor (sıralamada kimlik gösterilmez)'**
  String get reportUserIdUnknown;

  /// No description provided for @reportPlaceLeague.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama · Lig'**
  String get reportPlaceLeague;

  /// No description provided for @reportPlaceMonthly.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama · Aylık'**
  String get reportPlaceMonthly;

  /// No description provided for @reportPlaceFriendsRanking.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama · Arkadaşlar'**
  String get reportPlaceFriendsRanking;

  /// No description provided for @reportPlaceLiveFeed.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal · Şu an odaklananlar'**
  String get reportPlaceLiveFeed;

  /// No description provided for @reportPlaceFriendsList.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaş listesi'**
  String get reportPlaceFriendsList;

  /// No description provided for @reportPlaceFriendRequest.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlık isteği'**
  String get reportPlaceFriendRequest;

  /// No description provided for @reportMailFailed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta uygulaması açılamadı. Bildirimini {email} adresine gönderebilirsin.'**
  String reportMailFailed(String email);

  /// No description provided for @reportCopyAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adresi kopyala'**
  String get reportCopyAddress;

  /// No description provided for @onboardingBirthYearRequired.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için doğum yılını seç.'**
  String get onboardingBirthYearRequired;

  /// No description provided for @onboardingBirthYearPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Doğum yılını seç'**
  String get onboardingBirthYearPlaceholder;

  /// No description provided for @profileNotificationsLabelSub.
  ///
  /// In tr, this message translates to:
  /// **'Seans bitiş bildirimi ve kilit ekranı sayacı'**
  String get profileNotificationsLabelSub;

  /// No description provided for @profileNotificationsBlockedSub.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni kapalı. Seans bitiş bildirimi ve kilit ekranı sayacı için telefonunun ayarlarından izin ver.'**
  String get profileNotificationsBlockedSub;

  /// No description provided for @profileOpenSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarları aç'**
  String get profileOpenSettings;

  /// No description provided for @profileSocialVisibilityTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sıralamalarda ve canlı listede görün'**
  String get profileSocialVisibilityTitle;

  /// No description provided for @profileSocialVisibilitySub.
  ///
  /// In tr, this message translates to:
  /// **'Açıkken adın ve avatarın aylık sıralamada, pomosprint.app\'teki herkese açık listede (kısaltılmış adla) ve çalışırken arkadaşlarının canlı listesinde görünür. Lig grubun ve arkadaşların seni her durumda görür.'**
  String get profileSocialVisibilitySub;

  /// No description provided for @gameRulesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Nasıl çalışır?'**
  String get gameRulesTitle;

  /// No description provided for @gameRulesProfileSub.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatma, günlük sınır, puan ve kum'**
  String get gameRulesProfileSub;

  /// No description provided for @gameRulesSessions.
  ///
  /// In tr, this message translates to:
  /// **'Seanslar 25 ya da 50 dakika sürer. Her seansta tek duraklatma hakkın var; duraklatırsan puanın %{pct} azalır. İkinci kez durdurursan seans sıfırlanır.'**
  String gameRulesSessions(String pct);

  /// No description provided for @gameRulesPoints.
  ///
  /// In tr, this message translates to:
  /// **'Tamamladığın her seans puan (25 dk: {points25}, 50 dk: {points50}) ve {coins} kum tanesi kazandırır. Günde en fazla {limit} seans sayılır; sonrakiler yalnızca çalışma süresine ve serine eklenir.'**
  String gameRulesPoints(
    String points25,
    String points50,
    String coins,
    String limit,
  );

  /// No description provided for @gameRulesLeague.
  ///
  /// In tr, this message translates to:
  /// **'Puanınla ligde yükselirsin, her gün çalışarak seri bonusu kazanırsın. Kum taneleriyle koleksiyondan yeni kum saatleri açarsın.'**
  String get gameRulesLeague;

  /// No description provided for @profileHelpSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yardım'**
  String get profileHelpSectionTitle;

  /// No description provided for @profileSupportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Destek ve geri bildirim'**
  String get profileSupportTitle;

  /// No description provided for @profileSupportSub.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorunu ya da önerini e-postayla bize yaz'**
  String get profileSupportSub;

  /// No description provided for @profileAppVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String profileAppVersion(String version);

  /// No description provided for @supportEmailSubject.
  ///
  /// In tr, this message translates to:
  /// **'PomoSprint destek ve geri bildirim'**
  String get supportEmailSubject;

  /// No description provided for @supportEmailBody.
  ///
  /// In tr, this message translates to:
  /// **'Mesajın:\n\n\n---\nUygulama sürümü: {version}\nCihaz: {device}'**
  String supportEmailBody(String version, String device);

  /// No description provided for @supportMailFailed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta uygulaması açılamadı. Bize {email} adresinden yazabilirsin.'**
  String supportMailFailed(String email);

  /// No description provided for @selectCategory.
  ///
  /// In tr, this message translates to:
  /// **'KATEGORİ SEÇ'**
  String get selectCategory;

  /// No description provided for @sessionCompletedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tebrikler! 🎉'**
  String get sessionCompletedTitle;

  /// No description provided for @sessionCompletedBody.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakikalık odaklanma seansını\nbaşarıyla tamamladın! ⏳'**
  String sessionCompletedBody(int minutes);

  /// No description provided for @sessionCompletedOk.
  ///
  /// In tr, this message translates to:
  /// **'Harika!'**
  String get sessionCompletedOk;

  /// No description provided for @timerGetReady.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlan! Odaklanıyorsun...'**
  String get timerGetReady;

  /// No description provided for @languagePickerLabel.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama dili'**
  String get languagePickerLabel;

  /// No description provided for @onboardingSegmentOther.
  ///
  /// In tr, this message translates to:
  /// **'✨  Diğer / belirtmek istemiyorum'**
  String get onboardingSegmentOther;

  /// No description provided for @onboardingVisibilityTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sıralamalarda görünmek ister misin?'**
  String get onboardingVisibilityTitle;

  /// No description provided for @onboardingVisibilityBody.
  ///
  /// In tr, this message translates to:
  /// **'Açarsan adın ve avatarın aylık sıralamada, pomosprint.app\'teki herkese açık listede (adın kısaltılarak) ve çalışırken arkadaşlarının canlı listesinde görünür. Kapalıyken bu yerlerde görünmezsin. Lig grubundakiler ve arkadaşların seni her durumda görür. Bu tercihi istediğin zaman Profil\'den değiştirebilirsin.'**
  String get onboardingVisibilityBody;

  /// No description provided for @onboardingVisibilityYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet, sıralamalarda görüneyim'**
  String get onboardingVisibilityYes;

  /// No description provided for @onboardingVisibilityNo.
  ///
  /// In tr, this message translates to:
  /// **'Hayır, görünmeyeyim'**
  String get onboardingVisibilityNo;

  /// No description provided for @onboardingRulesBody.
  ///
  /// In tr, this message translates to:
  /// **'Başlamadan önce bilmen gereken birkaç kural:'**
  String get onboardingRulesBody;

  /// No description provided for @timerDurationOption.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakikalık seans'**
  String timerDurationOption(int minutes);

  /// No description provided for @timerEditCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kategorileri düzenle'**
  String get timerEditCategories;

  /// No description provided for @timerRemainingSemantics.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika {seconds} saniye kaldı'**
  String timerRemainingSemantics(int minutes, int seconds);

  /// No description provided for @timerNotificationsDenied.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni yok: seans bitince haber veremeyiz ve kilit ekranında sayaç görünmez.'**
  String get timerNotificationsDenied;
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
