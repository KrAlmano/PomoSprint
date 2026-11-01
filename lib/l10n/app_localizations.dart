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

  /// No description provided for @onboardingCategoryStepPreparedBody.
  ///
  /// In tr, this message translates to:
  /// **'Derslerin/alanların seçili geldi; istersen değiştir. Dokunarak çıkarabilir ya da yenisini ekleyebilirsin. En fazla {limit} tane seçebilirsin.'**
  String onboardingCategoryStepPreparedBody(int limit);

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
  /// **'Şu an odaklanan veya molada olan arkadaşın yok. Çalışmaya başladıklarında burada görünecekler.'**
  String get socialNoLiveFriends;

  /// No description provided for @socialLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlarının durumu yüklenemedi. Bağlantını kontrol edip tekrar dene.'**
  String get socialLoadError;

  /// No description provided for @leagueTierBronze.
  ///
  /// In tr, this message translates to:
  /// **'Bronz Lig'**
  String get leagueTierBronze;

  /// No description provided for @leagueTierSilver.
  ///
  /// In tr, this message translates to:
  /// **'Gümüş Lig'**
  String get leagueTierSilver;

  /// No description provided for @leagueTierGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın Lig'**
  String get leagueTierGold;

  /// No description provided for @leagueTierSapphire.
  ///
  /// In tr, this message translates to:
  /// **'Safir Lig'**
  String get leagueTierSapphire;

  /// No description provided for @leagueTierDiamond.
  ///
  /// In tr, this message translates to:
  /// **'Elmas Lig'**
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
  /// **'İlk puanlı seansından sonra benzer seviyedeki kullanıcılarla bir lig odasına yerleşirsin. Oda kapasitesi ve dönem kuralları sunucudan okunur; puan topladıkça sıralamada ilerlersin.'**
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
  /// **'İlk puanlı pomodoronu tamamladığında seninle aynı kademedeki uygun bir lig odasına yerleşirsin. Sıralaman ve güncel dönem kuralları burada görünür.'**
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
  /// **'Verilerinin bir kopyasını istiyorsan silmeden önce hesabındaki e-posta adresinden {email} adresine yaz.'**
  String profileDeleteConfirmCopyHint(String email);

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

  /// No description provided for @specialAvatarsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Özel Avatarlar'**
  String get specialAvatarsTitle;

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
  /// **'Bu seans daha önce kaydedilmişti.'**
  String get sessionResultDuplicate;

  /// No description provided for @sessionStartUnverified.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu başlangıcı doğrulayamadı. Seansın kaydedilir; puan ve kum kazanımı sunucu kurallarına bağlıdır.'**
  String get sessionStartUnverified;

  /// No description provided for @sessionUnverifiedNoRewards.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu başlangıcı doğrulayamadığı için seansın kaydedildi; bu seanstan puan ve kum kazanılmadı.'**
  String get sessionUnverifiedNoRewards;

  /// No description provided for @sessionResultTestNotSaved.
  ///
  /// In tr, this message translates to:
  /// **'Test seansı — kaydedilmez'**
  String get sessionResultTestNotSaved;

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

  /// No description provided for @sessionQueuedTimingUnverified.
  ///
  /// In tr, this message translates to:
  /// **'Seans bekletiliyor: seans süresi sunucuyla henüz doğrulanamadı. Otomatik olarak yeniden denenecek.'**
  String get sessionQueuedTimingUnverified;

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

  /// No description provided for @sessionRejectedNotElapsed.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilemedi: sunucuya göre seans süresi henüz dolmamıştı.'**
  String get sessionRejectedNotElapsed;

  /// No description provided for @sessionRejectedFutureStart.
  ///
  /// In tr, this message translates to:
  /// **'Bu seans kaydedilemedi: başlangıç zamanı sunucu saatiyle doğrulanamadı.'**
  String get sessionRejectedFutureStart;

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
  /// **'Bugünkü 25 dakikalık odak eşdeğeri: {count}'**
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
  /// **'Bu ay bir Pomodoro veya deneme tamamladığında aylık takip burada görünecek.'**
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
  /// **'Şifre en az 8 karakter olmalıdır.'**
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
  /// **'Bir Pomodoro veya deneme tamamladığında raporların burada görünecek.'**
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
  /// **'PomoSprint’e hoş geldin'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In tr, this message translates to:
  /// **'Odaklan, çalışmalarını takip et ve hedefindeki arkadaşlarınla birlikte ilerle. Önce uygulamayı sana göre hazırlayalım.'**
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

  /// No description provided for @onboardingSegmentKpss.
  ///
  /// In tr, this message translates to:
  /// **'📝  KPSS'**
  String get onboardingSegmentKpss;

  /// No description provided for @onboardingSegmentLanguage.
  ///
  /// In tr, this message translates to:
  /// **'🌍  Dil sınavı (YDS, YÖKDİL, IELTS, TOEFL)'**
  String get onboardingSegmentLanguage;

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

  /// No description provided for @onboardingCategoryStepPreparedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hedefine göre hazırladık 🎯'**
  String get onboardingCategoryStepPreparedTitle;

  /// No description provided for @onboardingCreateOwnCategory.
  ///
  /// In tr, this message translates to:
  /// **'+ Kendi kategorimi oluştur'**
  String get onboardingCreateOwnCategory;

  /// No description provided for @onboardingGoalStepTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük hedefini seç'**
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

  /// No description provided for @timerQuickTestBadge.
  ///
  /// In tr, this message translates to:
  /// **'TEST'**
  String get timerQuickTestBadge;

  /// No description provided for @timerQuickTestSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı test sayacı: seanslar kaydedilmez'**
  String get timerQuickTestSemantics;

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
  /// **'En az 8 karakter; büyük harf, küçük harf ve rakam içermeli.'**
  String get registerPasswordHelper;

  /// No description provided for @passwordRuleLength.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter'**
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
  /// **'Uygunsuz bir adı, içeriği ya da davranışı uygulama içinden bildir.'**
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

  /// No description provided for @onboardingCategoriesSkippedLimit.
  ///
  /// In tr, this message translates to:
  /// **'Kategori sınırına ({limit}) ulaşıldığı için seçtiğin {count} kategori eklenmedi. Kategorilerim\'den düzenleyebilirsin.'**
  String onboardingCategoriesSkippedLimit(int count, int limit);

  /// No description provided for @categoryColorInvalidMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu renk kullanılamıyor. Listeden bir renk seç.'**
  String get categoryColorInvalidMsg;

  /// No description provided for @categoryIconInvalidMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategori simgesi kullanılamıyor. Lütfen tekrar dene.'**
  String get categoryIconInvalidMsg;

  /// No description provided for @leagueInfoPromoteMinPoints.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem en az {points} puan toplayan ilk {count} kişi bir üst lige yükselir.'**
  String leagueInfoPromoteMinPoints(int count, int points);

  /// No description provided for @leagueAloneInRoomTitle.
  ///
  /// In tr, this message translates to:
  /// **'Odanda şimdilik yalnızsın'**
  String get leagueAloneInRoomTitle;

  /// No description provided for @leagueAloneInRoomBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu lig odasında şu an yalnızca sen varsın. Odaya katılanlar burada görünür; pomodoro tamamladıkça puan toplarsın.'**
  String get leagueAloneInRoomBody;

  /// No description provided for @friendsErrInvalidCode.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaş kodu 6–8 harf ve rakamdan oluşur. Kodu kontrol et.'**
  String get friendsErrInvalidCode;

  /// No description provided for @friendsErrRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme yaptın. Lütfen bir süre sonra tekrar dene.'**
  String get friendsErrRateLimited;

  /// No description provided for @friendsErrCooldown.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı isteğini yakın zamanda reddetti. Bir süre sonra tekrar deneyebilirsin.'**
  String get friendsErrCooldown;

  /// No description provided for @friendsErrBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcıyı engellediğin için arkadaş olarak ekleyemezsin.'**
  String get friendsErrBlocked;

  /// No description provided for @leagueAwardsSubMinPoints.
  ///
  /// In tr, this message translates to:
  /// **'Bir lig dönemini en az {points} puanla ilk 3\'te bitirince kazanılır: 1.\'ye Şampiyonluk, 2. ve 3.\'ye Podyum Ödülü.'**
  String leagueAwardsSubMinPoints(int points);

  /// No description provided for @leagueAwardMinMembersNote.
  ///
  /// In tr, this message translates to:
  /// **'Ödül yalnızca dönem sonunda en az {members} kişi olan odalarda verilir.'**
  String leagueAwardMinMembersNote(int members);

  /// No description provided for @leagueAwardLockedBodyMinPoints.
  ///
  /// In tr, this message translates to:
  /// **'Bu avatarı kazanmak için bu kademede bir lig dönemini en az {points} puanla ilk 3\'te bitirmen gerekiyor. Parayla satın alınamaz.'**
  String leagueAwardLockedBodyMinPoints(int points);

  /// No description provided for @leagueAwardLockedBodyChampionMinPoints.
  ///
  /// In tr, this message translates to:
  /// **'Bu Şampiyonluk Ödülü\'nü kazanmak için bu kademede bir lig dönemini en az {points} puanla 1. sırada bitirmen gerekiyor. Parayla satın alınamaz.'**
  String leagueAwardLockedBodyChampionMinPoints(int points);

  /// No description provided for @leagueAwardLockedBodyPodiumMinPoints.
  ///
  /// In tr, this message translates to:
  /// **'Bu Podyum Ödülü\'nü kazanmak için bu kademede bir lig dönemini en az {points} puanla 2. veya 3. sırada bitirmen gerekiyor (1. olan Şampiyonluk Ödülü\'nü alır). Parayla satın alınamaz.'**
  String leagueAwardLockedBodyPodiumMinPoints(int points);

  /// No description provided for @rankingZoneNeedsMinPointsMe.
  ///
  /// In tr, this message translates to:
  /// **'Terfi bölgesindesin ama terfi için en az {points} puan gerekiyor. Seans tamamlamaya devam et.'**
  String rankingZoneNeedsMinPointsMe(int points);

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresini gir. Şifreni yenilemen için bir doğrulama bağlantısı göndereceğiz.'**
  String get forgotPasswordDescription;

  /// No description provided for @sendPasswordResetEmail.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama maili gönder'**
  String get sendPasswordResetEmail;

  /// No description provided for @passwordResetSentTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-postanı kontrol et'**
  String get passwordResetSentTitle;

  /// No description provided for @passwordResetSentDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu adresle kayıtlı bir hesap varsa şifre sıfırlama bağlantısını gönderdik. Gelen kutunu ve spam klasörünü kontrol et; e-postadaki bağlantıdan yeni şifreni belirleyebilirsin.'**
  String get passwordResetSentDescription;

  /// No description provided for @passwordResetLocalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yerel e-posta'**
  String get passwordResetLocalTitle;

  /// No description provided for @passwordResetLocalDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu sürüm yerel ortama bağlı. E-postalar gerçek gelen kutuna gönderilmez; yerel Mailpit kutusunda tutulur. Buradaki hesaplar ve şifreler normal hesabından ayrıdır. Normal hesabını sıfırlamak için PomoSprint normal çalıştırma seçeneğini kullan.'**
  String get passwordResetLocalDescription;

  /// No description provided for @timerQuickRecordedSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Yerel hızlı test sayacı: seanslar 25 veya 50 dakika olarak kaydedilir'**
  String get timerQuickRecordedSemantics;

  /// No description provided for @friendsOutgoingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilen istekler'**
  String get friendsOutgoingTitle;

  /// No description provided for @friendsCancelRequest.
  ///
  /// In tr, this message translates to:
  /// **'İsteği iptal et'**
  String get friendsCancelRequest;

  /// No description provided for @friendsRemoveAction.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlıktan çıkar'**
  String get friendsRemoveAction;

  /// No description provided for @friendsRemoveConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlıktan çıkarmak istiyor musun? Yeniden arkadaş olmak için istek göndermen gerekir.'**
  String get friendsRemoveConfirm;

  /// No description provided for @friendsCancelConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Bu arkadaşlık isteğini iptal etmek istiyor musun?'**
  String get friendsCancelConfirm;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Engellenen kullanıcılar'**
  String get blockedUsersTitle;

  /// No description provided for @blockUserAction.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcıyı engelle'**
  String get blockUserAction;

  /// No description provided for @blockUserConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlık ve aranızdaki istekler kaldırılır. Birbirinizi canlı akışta göremez, arkadaşlık isteği gönderemezsiniz.'**
  String get blockUserConfirm;

  /// No description provided for @unblockUserAction.
  ///
  /// In tr, this message translates to:
  /// **'Engeli kaldır'**
  String get unblockUserAction;

  /// No description provided for @unblockUserConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Engel kaldırılacak. Önceki arkadaşlığınız otomatik olarak geri gelmez.'**
  String get unblockUserConfirm;

  /// No description provided for @friendActionCompleted.
  ///
  /// In tr, this message translates to:
  /// **'İşlem tamamlandı.'**
  String get friendActionCompleted;

  /// No description provided for @friendActionFailed.
  ///
  /// In tr, this message translates to:
  /// **'İşlem tamamlanamadı. Listeyi yenileyip tekrar dene.'**
  String get friendActionFailed;

  /// No description provided for @friendActionConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get friendActionConfirm;

  /// No description provided for @friendActionCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get friendActionCancel;

  /// No description provided for @reportReasonLabel.
  ///
  /// In tr, this message translates to:
  /// **'Bildirme nedeni'**
  String get reportReasonLabel;

  /// No description provided for @reportChooseReason.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir bildirme nedeni seç.'**
  String get reportChooseReason;

  /// No description provided for @reportReasonOffensiveName.
  ///
  /// In tr, this message translates to:
  /// **'Uygunsuz ad'**
  String get reportReasonOffensiveName;

  /// No description provided for @reportReasonOffensiveContent.
  ///
  /// In tr, this message translates to:
  /// **'Uygunsuz içerik'**
  String get reportReasonOffensiveContent;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In tr, this message translates to:
  /// **'Taciz veya zorbalık'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonSpam.
  ///
  /// In tr, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonImpersonation.
  ///
  /// In tr, this message translates to:
  /// **'Başkasını taklit etme'**
  String get reportReasonImpersonation;

  /// No description provided for @reportReasonOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (isteğe bağlı)'**
  String get reportDetailsLabel;

  /// No description provided for @reportSendButton.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimi gönder'**
  String get reportSendButton;

  /// No description provided for @reportSent.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimin alındı. Destek ekibi inceleyecek.'**
  String get reportSent;

  /// No description provided for @reportAlreadyReceived.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı hakkında bildirimin zaten alındı.'**
  String get reportAlreadyReceived;

  /// No description provided for @reportRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü bildirim sınırına ulaştın. Daha sonra tekrar dene.'**
  String get reportRateLimited;

  /// No description provided for @reportUserUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı artık bildirilemiyor. Listeyi yenile.'**
  String get reportUserUnavailable;

  /// No description provided for @reportSendFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim gönderilemedi. Tekrar dene.'**
  String get reportSendFailed;

  /// No description provided for @marathonTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maraton'**
  String get marathonTitle;

  /// No description provided for @marathonSingle.
  ///
  /// In tr, this message translates to:
  /// **'Tek seans'**
  String get marathonSingle;

  /// No description provided for @marathonChooseCount.
  ///
  /// In tr, this message translates to:
  /// **'Kaç seans yapmak istiyorsunuz?'**
  String get marathonChooseCount;

  /// No description provided for @marathonCountOption.
  ///
  /// In tr, this message translates to:
  /// **'{count} Pomodoro'**
  String marathonCountOption(int count);

  /// No description provided for @marathonProgress.
  ///
  /// In tr, this message translates to:
  /// **'{current}/{total} Pomodoro'**
  String marathonProgress(int current, int total);

  /// No description provided for @marathonBreakTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mola'**
  String get marathonBreakTitle;

  /// No description provided for @marathonBreakHint.
  ///
  /// In tr, this message translates to:
  /// **'Mola bitince 1 dakika içinde “Buradayım” diyerek devam et.'**
  String get marathonBreakHint;

  /// No description provided for @marathonAutomaticHint.
  ///
  /// In tr, this message translates to:
  /// **'Maraton, art arda 2, 3 veya 4 Pomodoro yapmanı sağlayan bir çalışma planıdır. Planın için 25 ya da 50 dakika seçersin; maratondaki tüm Pomodorolar bu sürede olur.\n\nSeansların arasında 5 dakika mola verirsin. Mola bitince 1 dakika içinde “Buradayım”a dokunarak sıradaki seansı başlatırsın. Devam onayı için internet bağlantısı gerekir.\n\nOnay vermezsen veya maratonu erken bitirirsen kalan plan durur. Tamamladığın seanslar ve normal puanların korunur; tamamlama bonusu kazanılmaz. Mola ve onay bekleme süresi çalışma sürene eklenmez.'**
  String get marathonAutomaticHint;

  /// No description provided for @marathonBreakRemainingSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Mola: {minutes} dakika {seconds} saniye kaldı'**
  String marathonBreakRemainingSemantics(int minutes, int seconds);

  /// No description provided for @marathonStart.
  ///
  /// In tr, this message translates to:
  /// **'MARATONU BAŞLAT'**
  String get marathonStart;

  /// No description provided for @marathonStop.
  ///
  /// In tr, this message translates to:
  /// **'Maratonu bitir'**
  String get marathonStop;

  /// No description provided for @marathonStopped.
  ///
  /// In tr, this message translates to:
  /// **'Maraton bitirildi. Tamamladığın Pomodorolar ve normal puanların korundu.'**
  String get marathonStopped;

  /// No description provided for @marathonStopConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maratonu bitirelim mi?'**
  String get marathonStopConfirmTitle;

  /// No description provided for @marathonStopConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'{completed}/{total} Pomodoro tamamladın. Tamamladıkların korunur; devam eden Pomodoro kaydedilmez.'**
  String marathonStopConfirmBody(int completed, int total);

  /// No description provided for @marathonStopConfirmAction.
  ///
  /// In tr, this message translates to:
  /// **'Maratonu bitir'**
  String get marathonStopConfirmAction;

  /// No description provided for @marathonCompletedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maraton tamamlandı!'**
  String get marathonCompletedTitle;

  /// No description provided for @marathonCompletedBody.
  ///
  /// In tr, this message translates to:
  /// **'{count} Pomodoro ile {minutes} dakika odaklandın.'**
  String marathonCompletedBody(int count, int minutes);

  /// No description provided for @marathonSaving.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro kaydediliyor…'**
  String get marathonSaving;

  /// No description provided for @marathonRetrySave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydı tekrar dene'**
  String get marathonRetrySave;

  /// No description provided for @marathonSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan Pomodoro cihazında saklanıyor. Kaydı yeniden göndermek için tekrar dene. Devam süresi dolarsa maraton durur; tamamladığın kayıt korunur.'**
  String get marathonSaveFailed;

  /// No description provided for @marathonStoppedRejected.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro kaydı kabul edilmedi. Maraton durduruldu; önceki kayıtların korundu.'**
  String get marathonStoppedRejected;

  /// No description provided for @marathonMinutesSummary.
  ///
  /// In tr, this message translates to:
  /// **'{focusMinutes} dk çalışma · molalarla yaklaşık {elapsedMinutes} dk'**
  String marathonMinutesSummary(int focusMinutes, int elapsedMinutes);

  /// No description provided for @marathonResumePlan.
  ///
  /// In tr, this message translates to:
  /// **'Maratona devam et'**
  String get marathonResumePlan;

  /// No description provided for @notifMarathonBreakDoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mola bitti'**
  String get notifMarathonBreakDoneTitle;

  /// No description provided for @notifMarathonBreakDoneBody.
  ///
  /// In tr, this message translates to:
  /// **'Maraton: {nextSession}/{totalSessions} Pomodoro. 1 dakika içinde uygulamayı açıp “Buradayım” diyerek devam et.'**
  String notifMarathonBreakDoneBody(int nextSession, int totalSessions);

  /// No description provided for @socialOnBreak.
  ///
  /// In tr, this message translates to:
  /// **'Molada'**
  String get socialOnBreak;

  /// No description provided for @socialNoBreakFriends.
  ///
  /// In tr, this message translates to:
  /// **'Şu an molada olan arkadaşın yok.'**
  String get socialNoBreakFriends;

  /// No description provided for @marathonBonusPoints.
  ///
  /// In tr, this message translates to:
  /// **'+{points} Maraton bonusu'**
  String marathonBonusPoints(int points);

  /// No description provided for @marathonBonusHint.
  ///
  /// In tr, this message translates to:
  /// **'Maratonu tamamlayınca +{points} ek puan'**
  String marathonBonusHint(int points);

  /// No description provided for @marathonBonusPending.
  ///
  /// In tr, this message translates to:
  /// **'Maraton bonusu, bekleyen Pomodorolar kaydedildiğinde ve tamamlama koşulları sağlandığında hesaplanacak.'**
  String get marathonBonusPending;

  /// No description provided for @marathonUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Maraton şu an kullanılamıyor.'**
  String get marathonUnavailable;

  /// No description provided for @marathonStartFailed.
  ///
  /// In tr, this message translates to:
  /// **'Maraton başlatılamadı. Lütfen tekrar dene.'**
  String get marathonStartFailed;

  /// No description provided for @marathonPresenceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Burada mısın?'**
  String get marathonPresenceTitle;

  /// No description provided for @marathonPresenceHint.
  ///
  /// In tr, this message translates to:
  /// **'Molan bitti. Sıradaki seansı başlatmak için 1 dakika içinde “Buradayım”a dokun.'**
  String get marathonPresenceHint;

  /// No description provided for @marathonPresenceConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Buradayım'**
  String get marathonPresenceConfirm;

  /// No description provided for @marathonPresenceChecking.
  ///
  /// In tr, this message translates to:
  /// **'Onaylanıyor…'**
  String get marathonPresenceChecking;

  /// No description provided for @marathonPresenceConnectionNeeded.
  ///
  /// In tr, this message translates to:
  /// **'Onay alınamadı. İnternet bağlantını kontrol edip süre dolmadan tekrar dene.'**
  String get marathonPresenceConnectionNeeded;

  /// No description provided for @marathonPresenceExpired.
  ///
  /// In tr, this message translates to:
  /// **'Devam onayı gelmediği için maraton durdu. Tamamladığın seanslar korundu.'**
  String get marathonPresenceExpired;

  /// No description provided for @marathonPresenceRemainingSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Devam onayı için {minutes} dakika {seconds} saniye kaldı'**
  String marathonPresenceRemainingSemantics(int minutes, int seconds);

  /// No description provided for @marathonStepStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get marathonStepStart;

  /// No description provided for @marathonStepGoal.
  ///
  /// In tr, this message translates to:
  /// **'Hedef'**
  String get marathonStepGoal;

  /// No description provided for @marathonSessionCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} seans'**
  String marathonSessionCount(int count);

  /// No description provided for @marathonStepCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get marathonStepCompleted;

  /// No description provided for @marathonStepCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Şimdiki seans'**
  String get marathonStepCurrent;

  /// No description provided for @marathonStepUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki seans'**
  String get marathonStepUpcoming;

  /// No description provided for @marathonStoppedInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Maraton doğrulanamadığı için durduruldu. Tamamlanan seansların ve bu seanslardan kazanılan normal puan ile kum korunur. Bu plan için ek Maraton puanı verilmez.'**
  String get marathonStoppedInvalid;

  /// No description provided for @marathonPlanTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maratonunu planla'**
  String get marathonPlanTitle;

  /// No description provided for @marathonDurationLabel.
  ///
  /// In tr, this message translates to:
  /// **'Pomodoro süresi'**
  String get marathonDurationLabel;

  /// No description provided for @marathonStartingWelcome.
  ///
  /// In tr, this message translates to:
  /// **'Maraton başlıyor. İyi çalışmalar!'**
  String get marathonStartingWelcome;

  /// No description provided for @marathonViewProgress.
  ///
  /// In tr, this message translates to:
  /// **'Maraton ilerlemesi'**
  String get marathonViewProgress;

  /// No description provided for @marathonInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maraton nedir?'**
  String get marathonInfoTitle;

  /// No description provided for @marathonInfoBonusMatrix.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlama bonusu\n25 dk: 2 seans +{shortTwo}, 3 seans +{shortThree}, 4 seans +{shortFour} puan.\n50 dk: 2 seans +{longTwo}, 3 seans +{longThree}, 4 seans +{longFour} puan.\n\nBu ek puan, tüm seanslar kaydedilip normal puan kazandığında ve her devam onayı zamanında verildiğinde bir kez kazanılır. Her seansın normal puanına eklenir; ek kum kazandırmaz.'**
  String marathonInfoBonusMatrix(
    int shortTwo,
    int shortThree,
    int shortFour,
    int longTwo,
    int longThree,
    int longFour,
  );

  /// No description provided for @onboardingGuideTitle.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı tanı'**
  String get onboardingGuideTitle;

  /// No description provided for @onboardingGuideBody.
  ///
  /// In tr, this message translates to:
  /// **'Başlamadan önce ekranların nasıl çalıştığına göz at.'**
  String get onboardingGuideBody;

  /// No description provided for @onboardingGuidePomoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Pomo'**
  String get onboardingGuidePomoTitle;

  /// No description provided for @onboardingGuidePomoBody.
  ///
  /// In tr, this message translates to:
  /// **'Kategorini ve 25 ya da 50 dakikalık seansını seçip Başlat’a dokun. Her seansta bir duraklatma hakkın var; duraklatılan seansın puanı azalır. Tamamlanan seanslar kaydedilir.'**
  String get onboardingGuidePomoBody;

  /// No description provided for @onboardingGuideMarathonTitle.
  ///
  /// In tr, this message translates to:
  /// **'Maraton'**
  String get onboardingGuideMarathonTitle;

  /// No description provided for @onboardingGuideMarathonBody.
  ///
  /// In tr, this message translates to:
  /// **'Maraton’u başlat düğmesinden 2, 3 veya 4 seans planla. Seanslar arasında 5 dakika mola verilir. Mola bitince 1 dakika içinde Buradayım’a dokunarak devam et; onay vermezsen Maraton biter. Bitirdiğin seansların normal puanları korunur. Planın tamamını bitirince 25 dakikalık seanslarda sırasıyla +2/+3/+5, 50 dakikalıklarda +4/+6/+10 ek puan kazanırsın.'**
  String get onboardingGuideMarathonBody;

  /// No description provided for @onboardingGuideReportsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Raporlar'**
  String get onboardingGuideReportsTitle;

  /// No description provided for @onboardingGuideReportsBody.
  ///
  /// In tr, this message translates to:
  /// **'Günlük, haftalık ve aylık raporlar Pomodoro, Maraton odakları ve tamamlanmış denemelerin toplam çalışma süresini gösterir. Molalar ve vazgeçilen denemeler dahil değildir. Çalışma günü 04:00’da değişir; deneme süresi ayrı bir Deneme satırında görünür.'**
  String get onboardingGuideReportsBody;

  /// No description provided for @onboardingGuideRankingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama'**
  String get onboardingGuideRankingTitle;

  /// No description provided for @onboardingGuideRankingBody.
  ///
  /// In tr, this message translates to:
  /// **'Normal ve deneme ligleri ayrıdır; kendi hedefindeki kişilerle yarışırsın. Global sıralama tüm hedefleri kapsar. Dönem İstanbul saatine göre ayın 1’inde 00:00’da yenilenir. Az katılımcılı gruplar hazırlıkta kalabilir; terfi ve ödül koşulları Sıralama’daki ? rehberindedir.'**
  String get onboardingGuideRankingBody;

  /// No description provided for @onboardingGuideSocialTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal'**
  String get onboardingGuideSocialTitle;

  /// No description provided for @onboardingGuideSocialBody.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaş koduyla ekle ve isteklerini yönet. Görünür arkadaşların Odaklanıyor, yalnız Maraton molasında Molada, deneme sırasında Denemede olarak görünür. Liste açıkken düzenli yenilenir. Görünürlüğünü Ayarlar’dan değiştirebilir, kullanıcı gizleyebilir veya engelleyebilirsin.'**
  String get onboardingGuideSocialBody;

  /// No description provided for @onboardingGuideProfileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get onboardingGuideProfileTitle;

  /// No description provided for @onboardingGuideProfileBody.
  ///
  /// In tr, this message translates to:
  /// **'Üstteki avatarına dokunarak Profil’i aç. Kategorilerini düzenle, kazandığın kumla avatar koleksiyonunu genişlet ve avatarını seç. Dil, tema, bildirim ve görünürlük ayarlarını; yardım, gizlilik ve hesap işlemlerini burada bulursun.'**
  String get onboardingGuideProfileBody;

  /// No description provided for @leagueInfoWhatBodyWithCapacity.
  ///
  /// In tr, this message translates to:
  /// **'İlk puanlı seansını tamamladığında aynı kademede ve aynı dönemdeki uygun mevcut odaya yerleşirsin. Her odada en fazla {capacity} kişi bulunur; oda doluysa yeni oda açılır. Dönem sırası sunucunun kabul ettiği seans puanlarına göre belirlenir.'**
  String leagueInfoWhatBodyWithCapacity(int capacity);

  /// No description provided for @leagueLaunchPreparingBody.
  ///
  /// In tr, this message translates to:
  /// **'Ligler hazırlık döneminde. Son 14 günde seans tamamlayan {users} farklı kullanıcıya ulaşınca ilk resmi yarışma sonraki tam 14 günlük dönemde başlar. Seansların, puanın ve raporların kaydolur; hazırlıkta terfi, düşme ve lig avatar ödülü yoktur. Hazırlık puanları resmi yarışmaya taşınmaz.'**
  String leagueLaunchPreparingBody(int users);

  /// No description provided for @leagueLaunchScheduledBody.
  ///
  /// In tr, this message translates to:
  /// **'İlk resmi lig dönemi {date} başlayacak. O zamana kadar seansların ve raporların kaydolur; terfi, düşme ve lig avatar ödülü verilmez. Hazırlık puanları yarışmaya taşınmaz.'**
  String leagueLaunchScheduledBody(String date);

  /// No description provided for @leagueLaunchScheduledShort.
  ///
  /// In tr, this message translates to:
  /// **'Resmi lig dönemi başlıyor'**
  String get leagueLaunchScheduledShort;

  /// No description provided for @leaguePromotionPolicyBody.
  ///
  /// In tr, this message translates to:
  /// **'Terfi için odada bu dönem seans tamamlayan en az {active} aktif kişi olmalı. Terfi kotası aktif kişi sayısının üçte biridir, aşağı yuvarlanır (3 aktif kişi: 1; 25 aktif kişi: 8). Bu dönem en az {days} farklı çalışma gününde toplam {minutes} dakika odaklanıp en az {points} puan kazanmalı ve kotanın içinde bitirmelisin. Elmas Lig’de terfi yoktur.'**
  String leaguePromotionPolicyBody(
    int active,
    int days,
    int minutes,
    int points,
  );

  /// No description provided for @leaguePromotionCurrentQuota.
  ///
  /// In tr, this message translates to:
  /// **'Bu odada mevcut terfi kotası: ilk {count} sıra. Gün, dakika ve puan şartları ayrıca sağlanmalıdır.'**
  String leaguePromotionCurrentQuota(int count);

  /// No description provided for @leagueNoPromotionCurrentPeriod.
  ///
  /// In tr, this message translates to:
  /// **'Bu odada şu an terfi için yeterli aktif katılımcı yok. Tamamladığın seanslar kaydolmaya devam eder.'**
  String get leagueNoPromotionCurrentPeriod;

  /// No description provided for @leagueDemotionPolicyBody.
  ///
  /// In tr, this message translates to:
  /// **'Düşme yalnızca en az 10 aktif kişinin bulunduğu odalarda uygulanır: sıralamanın sonundan aktif kişi sayısının üçte biri, aşağı yuvarlanarak bir alt lige düşer. Son 3 günde katılanlar ve Bronz Lig’dekiler düşmez.'**
  String get leagueDemotionPolicyBody;

  /// No description provided for @leagueAwardActiveRequirements.
  ///
  /// In tr, this message translates to:
  /// **'Resmi lig döneminde odada en az {members} aktif kişi olmalı. En az {days} farklı çalışma gününde toplam {minutes} dakika odaklanıp {points} puana ulaşman gerekir. Hazırlık döneminde ödül verilmez.'**
  String leagueAwardActiveRequirements(
    int members,
    int days,
    int minutes,
    int points,
  );

  /// No description provided for @leaguePreparationNoChanges.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlık sırasında herkes mevcut liginde kalır; terfi, düşme ve lig avatar ödülü verilmez.'**
  String get leaguePreparationNoChanges;

  /// No description provided for @leagueLaunchPreparingShort.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlık dönemi · Terfi, düşme ve lig ödülleri henüz başlamadı.'**
  String get leagueLaunchPreparingShort;

  /// No description provided for @examTab.
  ///
  /// In tr, this message translates to:
  /// **'Deneme'**
  String get examTab;

  /// No description provided for @examTitle.
  ///
  /// In tr, this message translates to:
  /// **'Denemeler'**
  String get examTitle;

  /// No description provided for @examNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni deneme'**
  String get examNew;

  /// No description provided for @examHistory.
  ///
  /// In tr, this message translates to:
  /// **'Denemelerim'**
  String get examHistory;

  /// No description provided for @examLeague.
  ///
  /// In tr, this message translates to:
  /// **'Deneme ligi'**
  String get examLeague;

  /// No description provided for @examIntro.
  ///
  /// In tr, this message translates to:
  /// **'Sınavını seç, gerçek süresinde çöz. Netlerini sonradan ekleyebilirsin.'**
  String get examIntro;

  /// No description provided for @examUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Deneme modu yakında'**
  String get examUnavailable;

  /// No description provided for @examUnavailableBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu sunucuda deneme modu henüz etkin değil. Sınavları inceleyebilirsin; normal çalışma ve Maraton devam eder.'**
  String get examUnavailableBody;

  /// No description provided for @examCatalogFallback.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı sınav bilgileri gösteriliyor. Başlatmak için sunucu bağlantısı gerekir.'**
  String get examCatalogFallback;

  /// No description provided for @examStart.
  ///
  /// In tr, this message translates to:
  /// **'Denemeyi başlat'**
  String get examStart;

  /// No description provided for @examRulesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlamadan önce'**
  String get examRulesTitle;

  /// No description provided for @examRulesBody.
  ///
  /// In tr, this message translates to:
  /// **'Denemede mola ve duraklatma yoktur. Sayaç uygulama kapalıyken de ilerler. Tam süre dolmadan vazgeçersen puan ve deneme kumu kazanmazsın; denemen geçmişinde kalır. Netlerin puanını veya ligini etkilemez.'**
  String get examRulesBody;

  /// No description provided for @examReady.
  ///
  /// In tr, this message translates to:
  /// **'Hazır olduğunda başla'**
  String get examReady;

  /// No description provided for @examNoPause.
  ///
  /// In tr, this message translates to:
  /// **'Duraklatma ve mola yok'**
  String get examNoPause;

  /// No description provided for @examRunning.
  ///
  /// In tr, this message translates to:
  /// **'Deneme sürüyor'**
  String get examRunning;

  /// No description provided for @examTimeRemaining.
  ///
  /// In tr, this message translates to:
  /// **'Kalan süre'**
  String get examTimeRemaining;

  /// No description provided for @examAbandon.
  ///
  /// In tr, this message translates to:
  /// **'Denemeden vazgeç'**
  String get examAbandon;

  /// No description provided for @examAbandonTitle.
  ///
  /// In tr, this message translates to:
  /// **'Denemeden vazgeçmek istiyor musun?'**
  String get examAbandonTitle;

  /// No description provided for @examAbandonBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu deneme vazgeçildi olarak saklanacak. Puan, deneme kumu ve çalışma süresi kazanılmayacak.'**
  String get examAbandonBody;

  /// No description provided for @examCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Deneme tamamlandı'**
  String get examCompleted;

  /// No description provided for @examAbandoned.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeçildi'**
  String get examAbandoned;

  /// No description provided for @examPending.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu onayı bekleniyor'**
  String get examPending;

  /// No description provided for @examPendingBody.
  ///
  /// In tr, this message translates to:
  /// **'Denemen bu cihazda saklandı. Bağlantı geldiğinde aynı kayıt tekrar gönderilecek.'**
  String get examPendingBody;

  /// No description provided for @examStartPending.
  ///
  /// In tr, this message translates to:
  /// **'Başlatma sonucu bekleniyor'**
  String get examStartPending;

  /// No description provided for @examStartPendingBody.
  ///
  /// In tr, this message translates to:
  /// **'Başlatma isteğinin sonucu henüz bilinmiyor. Tekrar denemek yeni bir deneme oluşturmaz.'**
  String get examStartPendingBody;

  /// No description provided for @examError.
  ///
  /// In tr, this message translates to:
  /// **'Deneme bilgileri alınamadı. Bağlantını kontrol edip tekrar dene.'**
  String get examError;

  /// No description provided for @examStartRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Son 24 saatte çok fazla deneme başlattın. Bir süre sonra tekrar deneyebilirsin.'**
  String get examStartRateLimited;

  /// No description provided for @examConflict.
  ///
  /// In tr, this message translates to:
  /// **'Önce devam eden çalışma veya denemeni tamamla.'**
  String get examConflict;

  /// No description provided for @examRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get examRetry;

  /// No description provided for @examEnterResults.
  ///
  /// In tr, this message translates to:
  /// **'Netlerini gir'**
  String get examEnterResults;

  /// No description provided for @examEditResults.
  ///
  /// In tr, this message translates to:
  /// **'Netlerini düzenle'**
  String get examEditResults;

  /// No description provided for @examResultsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Derslere göre sonuçlar'**
  String get examResultsTitle;

  /// No description provided for @examResultsInfo.
  ///
  /// In tr, this message translates to:
  /// **'Netler kişisel rapor ve içgörü içindir; puan ve kuma etkisi yoktur.'**
  String get examResultsInfo;

  /// No description provided for @examCorrect.
  ///
  /// In tr, this message translates to:
  /// **'Doğru'**
  String get examCorrect;

  /// No description provided for @examWrong.
  ///
  /// In tr, this message translates to:
  /// **'Yanlış'**
  String get examWrong;

  /// No description provided for @examBlank.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get examBlank;

  /// No description provided for @examNet.
  ///
  /// In tr, this message translates to:
  /// **'Net'**
  String get examNet;

  /// No description provided for @examSaveResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçları kaydet'**
  String get examSaveResults;

  /// No description provided for @examResultsInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Her ders için doğru, yanlış ve boş toplamı soru sayısına eşit olmalı. Yalnızca negatif olmayan tam sayılar gir.'**
  String get examResultsInvalid;

  /// No description provided for @examResultsSaved.
  ///
  /// In tr, this message translates to:
  /// **'Netlerin kaydedildi.'**
  String get examResultsSaved;

  /// No description provided for @examResultsSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar kaydedilemedi. Girdilerin korundu; tekrar deneyebilirsin.'**
  String get examResultsSaveError;

  /// No description provided for @examNoHistory.
  ///
  /// In tr, this message translates to:
  /// **'Henüz denemen yok'**
  String get examNoHistory;

  /// No description provided for @examNoHistoryBody.
  ///
  /// In tr, this message translates to:
  /// **'Başlattığın ve vazgeçtiğin denemeler burada görünür.'**
  String get examNoHistoryBody;

  /// No description provided for @examPracticeSand.
  ///
  /// In tr, this message translates to:
  /// **'Deneme kumu'**
  String get examPracticeSand;

  /// No description provided for @examInsights.
  ///
  /// In tr, this message translates to:
  /// **'Süre ve netlerin'**
  String get examInsights;

  /// No description provided for @examInsightsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gösterilecek bir süre–net içgörüsü yok. Aynı dersten en az iki sonuç kaydettiğinde burada karşılaştırabilirsin.'**
  String get examInsightsEmpty;

  /// No description provided for @examInsightsDisclaimer.
  ///
  /// In tr, this message translates to:
  /// **'Bu karşılaştırma bir ilişki gösterir; net değişiminin tek nedeninin çalışma süresi olduğunu söylemez.'**
  String get examInsightsDisclaimer;

  /// No description provided for @examLeagueEmpty.
  ///
  /// In tr, this message translates to:
  /// **'İlk puan kazandığın denemeden sonra ligde yerini alırsın.'**
  String get examLeagueEmpty;

  /// No description provided for @examLeaguePreparing.
  ///
  /// In tr, this message translates to:
  /// **'Bu grupta yarışma için yeterli aktif kullanıcı bekleniyor.'**
  String get examLeaguePreparing;

  /// No description provided for @examGlobal.
  ///
  /// In tr, this message translates to:
  /// **'Global'**
  String get examGlobal;

  /// No description provided for @examTargetGroup.
  ///
  /// In tr, this message translates to:
  /// **'Hedef grubum'**
  String get examTargetGroup;

  /// No description provided for @examRewardAvatars.
  ///
  /// In tr, this message translates to:
  /// **'Deneme ligi avatarları'**
  String get examRewardAvatars;

  /// No description provided for @examRewardAvatarsPending.
  ///
  /// In tr, this message translates to:
  /// **'Özel görseller hazırlanıyor. Görsel hazır olmadan sahip olmadığın bir ödül gösterilmez.'**
  String get examRewardAvatarsPending;

  /// No description provided for @examFinishedNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Netler henüz girilmedi'**
  String get examFinishedNoResults;

  /// No description provided for @examStartTime.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get examStartTime;

  /// No description provided for @examEndTime.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get examEndTime;

  /// No description provided for @examDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get examDismiss;

  /// No description provided for @examLgsBreakInfo.
  ///
  /// In tr, this message translates to:
  /// **'LGS iki ayrı oturumdur. Gerçek sınavda sözel ve sayısal oturum arasında 45 dakika ara bulunur.'**
  String get examLgsBreakInfo;

  /// No description provided for @examLoadMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla göster'**
  String get examLoadMore;

  /// No description provided for @examNoAward.
  ///
  /// In tr, this message translates to:
  /// **'Ödül yok'**
  String get examNoAward;

  /// No description provided for @examNetUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'—'**
  String get examNetUnavailable;

  /// No description provided for @examQueuedResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçların bu cihazda saklandı. Bağlantı geldiğinde gönderilecek.'**
  String get examQueuedResults;

  /// No description provided for @examTotalStudy.
  ///
  /// In tr, this message translates to:
  /// **'Toplam çalışma'**
  String get examTotalStudy;

  /// No description provided for @examNoVerifiedDuration.
  ///
  /// In tr, this message translates to:
  /// **'Çalışma süresi yalnızca sunucunun onayladığı tamamlanmış denemelere eklenir.'**
  String get examNoVerifiedDuration;

  /// No description provided for @examStarting.
  ///
  /// In tr, this message translates to:
  /// **'Başlatılıyor…'**
  String get examStarting;

  /// No description provided for @examSaving.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor…'**
  String get examSaving;

  /// No description provided for @examAllGroups.
  ///
  /// In tr, this message translates to:
  /// **'Tüm sınavlar'**
  String get examAllGroups;

  /// No description provided for @examQuestionsMinutes.
  ///
  /// In tr, this message translates to:
  /// **'Soru: {questions} · Süre: {minutes} dk'**
  String examQuestionsMinutes(int questions, int minutes);

  /// No description provided for @examSubjectQuestions.
  ///
  /// In tr, this message translates to:
  /// **'{questions} soru'**
  String examSubjectQuestions(int questions);

  /// No description provided for @examNetRule.
  ///
  /// In tr, this message translates to:
  /// **'Net = Doğru − Yanlış / {divisor}'**
  String examNetRule(int divisor);

  /// No description provided for @examRewardSummary.
  ///
  /// In tr, this message translates to:
  /// **'{points} puan · {sand} deneme kumu'**
  String examRewardSummary(int points, int sand);

  /// No description provided for @examInsightsChange.
  ///
  /// In tr, this message translates to:
  /// **'İlişkili çalışma kategorilerinde {minutes} dk; {subject} neti: {before} → {after}.'**
  String examInsightsChange(
    String subject,
    int minutes,
    String before,
    String after,
  );

  /// No description provided for @examResultsQuestionTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam {actual} / {expected}'**
  String examResultsQuestionTotal(int actual, int expected);

  /// No description provided for @examMonthlyReset.
  ///
  /// In tr, this message translates to:
  /// **'Dönem bitişi: {date}'**
  String examMonthlyReset(String date);

  /// No description provided for @onboardingSegmentTus.
  ///
  /// In tr, this message translates to:
  /// **'TUS (Tıpta Uzmanlık)'**
  String get onboardingSegmentTus;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hangi dili kullanmak istersin?'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageBody.
  ///
  /// In tr, this message translates to:
  /// **'Dilini daha sonra Ayarlar’dan değiştirebilirsin.'**
  String get onboardingLanguageBody;

  /// No description provided for @onboardingGuideExamTitle.
  ///
  /// In tr, this message translates to:
  /// **'Deneme: sınav süresini deneyimle'**
  String get onboardingGuideExamTitle;

  /// No description provided for @onboardingGuideExamBody.
  ///
  /// In tr, this message translates to:
  /// **'Sınavını seç; soru sayısı ve süresi otomatik gelir. Denemede mola ve duraklatma yoktur. Tam süreyi tamamladığında ayrı deneme puanı ve kumu kazanırsın. Vazgeçersen kaydın geçmişte kalır, ödül ve çalışma süresi kazanmazsın.'**
  String get onboardingGuideExamBody;

  /// No description provided for @onboardingGuideInsightsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Netler ve süre–net içgörüleri'**
  String get onboardingGuideInsightsTitle;

  /// No description provided for @onboardingGuideInsightsBody.
  ///
  /// In tr, this message translates to:
  /// **'Denemelerim’den ders ders doğru, yanlış ve boşlarını girip sonra düzenleyebilirsin. Netlerin yalnız kişisel raporlarındadır; puanını veya ligini değiştirmez. Yeterli veri oluştuğunda ders çalışma süreni netlerindeki değişimle birlikte görürsün.'**
  String get onboardingGuideInsightsBody;

  /// No description provided for @languageNativeTr.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageNativeTr;

  /// No description provided for @languageNativeEn.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get languageNativeEn;

  /// No description provided for @languageSettingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama Dili'**
  String get languageSettingsTitle;

  /// No description provided for @categoriesSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'KATEGORİLERİM'**
  String get categoriesSectionTitle;

  /// No description provided for @editProfileAction.
  ///
  /// In tr, this message translates to:
  /// **'Profili Düzenle'**
  String get editProfileAction;

  /// No description provided for @effHigh.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek'**
  String get effHigh;

  /// No description provided for @effNormal.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get effNormal;

  /// No description provided for @effVeryHigh.
  ///
  /// In tr, this message translates to:
  /// **'Çok Yüksek'**
  String get effVeryHigh;

  /// No description provided for @legacyEmailReadonlyHint.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi güvenlik nedeniyle değiştirilemez.'**
  String get legacyEmailReadonlyHint;

  /// No description provided for @heatmapLess.
  ///
  /// In tr, this message translates to:
  /// **'Az'**
  String get heatmapLess;

  /// No description provided for @heatmapMore.
  ///
  /// In tr, this message translates to:
  /// **'Çok'**
  String get heatmapMore;

  /// No description provided for @manageCategoriesTileSub.
  ///
  /// In tr, this message translates to:
  /// **'Kategori ekle, düzenle, sırala ve arşivle'**
  String get manageCategoriesTileSub;

  /// No description provided for @manageCategoriesTileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategorileri Yönet'**
  String get manageCategoriesTileTitle;

  /// No description provided for @monthIntensitySuffix.
  ///
  /// In tr, this message translates to:
  /// **'Yoğunluğu'**
  String get monthIntensitySuffix;

  /// No description provided for @mostEfficientDayLabel.
  ///
  /// In tr, this message translates to:
  /// **'En Verimli Gün'**
  String get mostEfficientDayLabel;

  /// No description provided for @profileFullNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get profileFullNameLabel;

  /// No description provided for @newWeekLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get newWeekLabel;

  /// No description provided for @noReportsDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bir Pomodoro veya deneme tamamladığında ders dağılımın ve raporların burada görünecek.'**
  String get noReportsDesc;

  /// No description provided for @noStudyThisDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün çalışma yok'**
  String get noStudyThisDay;

  /// No description provided for @notificationsAndLockScreen.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler ve kilit ekranı sayacı'**
  String get notificationsAndLockScreen;

  /// No description provided for @preferencesSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tercihler'**
  String get preferencesSectionTitle;

  /// No description provided for @reportsWeeklyTab.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık Çalışma'**
  String get reportsWeeklyTab;

  /// No description provided for @reportsMonthlyTab.
  ///
  /// In tr, this message translates to:
  /// **'Aylık Takip'**
  String get reportsMonthlyTab;

  /// No description provided for @reportsDailyTab.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Çalışma'**
  String get reportsDailyTab;

  /// No description provided for @reportsTabDailyShort.
  ///
  /// In tr, this message translates to:
  /// **'Günlük'**
  String get reportsTabDailyShort;

  /// No description provided for @reportsTabWeeklyShort.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık'**
  String get reportsTabWeeklyShort;

  /// No description provided for @reportsTabMonthlyShort.
  ///
  /// In tr, this message translates to:
  /// **'Aylık'**
  String get reportsTabMonthlyShort;

  /// No description provided for @reportsTabExamsShort.
  ///
  /// In tr, this message translates to:
  /// **'Deneme'**
  String get reportsTabExamsShort;

  /// No description provided for @topSubjectsLabel.
  ///
  /// In tr, this message translates to:
  /// **'En Çok Çalışılan Dersler'**
  String get topSubjectsLabel;

  /// No description provided for @topicComparisonTitle.
  ///
  /// In tr, this message translates to:
  /// **'Konu Karşılaştırması'**
  String get topicComparisonTitle;

  /// No description provided for @totalFocusLabel.
  ///
  /// In tr, this message translates to:
  /// **'Toplam\nOdaklanma'**
  String get totalFocusLabel;

  /// No description provided for @weekDayBreakdownTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gün Gün Döküm'**
  String get weekDayBreakdownTitle;

  /// No description provided for @weeklyAnalysisCaption.
  ///
  /// In tr, this message translates to:
  /// **'HAFTALIK ANALİZ'**
  String get weeklyAnalysisCaption;

  /// No description provided for @legacyWeeklyDistSub.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün özeti'**
  String get legacyWeeklyDistSub;

  /// No description provided for @legacyWeeklyDistTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün Dağılımı'**
  String get legacyWeeklyDistTitle;

  /// No description provided for @weeklyEfficiencyCaption.
  ///
  /// In tr, this message translates to:
  /// **'HAFTALIK VERİMLİLİK'**
  String get weeklyEfficiencyCaption;

  /// No description provided for @weeklySummaryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık Özet'**
  String get weeklySummaryTitle;

  /// No description provided for @weeklyTrendCaption.
  ///
  /// In tr, this message translates to:
  /// **'HAFTALIK TREND'**
  String get weeklyTrendCaption;

  /// No description provided for @statsSessionTypesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oturum türleri'**
  String get statsSessionTypesTitle;

  /// No description provided for @statsNormalSessions.
  ///
  /// In tr, this message translates to:
  /// **'Normal seans'**
  String get statsNormalSessions;

  /// No description provided for @statsCompletedMarathons.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan maraton'**
  String get statsCompletedMarathons;

  /// No description provided for @statsCompletedExams.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan deneme'**
  String get statsCompletedExams;

  /// No description provided for @statsExamCategory.
  ///
  /// In tr, this message translates to:
  /// **'Deneme'**
  String get statsExamCategory;

  /// No description provided for @statsOpenExamDetails.
  ///
  /// In tr, this message translates to:
  /// **'Denemelerim, netler ve içgörüler'**
  String get statsOpenExamDetails;

  /// No description provided for @statsUnknownSessionTypes.
  ///
  /// In tr, this message translates to:
  /// **'Eski sunucu bu kayıtların normal seans ve Maraton ayrımını henüz iletmiyor. Süre toplamları korunur.'**
  String get statsUnknownSessionTypes;

  /// No description provided for @statsExamTotalsInfo.
  ///
  /// In tr, this message translates to:
  /// **'Toplam süre, Pomodoro ve Maraton odakları ile tamamlanmış denemeleri içerir. Deneme süresi derslere paylaştırılmaz.'**
  String get statsExamTotalsInfo;

  /// No description provided for @statsMarathonFocusCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} Maraton odağı'**
  String statsMarathonFocusCount(int count);

  /// No description provided for @statsFocusEquivalent.
  ///
  /// In tr, this message translates to:
  /// **'{count} × 25 dk odak eşdeğeri'**
  String statsFocusEquivalent(int count);

  /// No description provided for @statsCountsPending.
  ///
  /// In tr, this message translates to:
  /// **'{count} seans sunucu onayı bekliyor'**
  String statsCountsPending(int count);

  /// No description provided for @socialTakingExam.
  ///
  /// In tr, this message translates to:
  /// **'Denemede'**
  String get socialTakingExam;

  /// No description provided for @rankingTabGlobal.
  ///
  /// In tr, this message translates to:
  /// **'Global'**
  String get rankingTabGlobal;

  /// No description provided for @rankingGlobalResetIn.
  ///
  /// In tr, this message translates to:
  /// **'Global sıralamanın sıfırlanmasına kalan süre'**
  String get rankingGlobalResetIn;

  /// No description provided for @leagueCalendarMonthBody.
  ///
  /// In tr, this message translates to:
  /// **'Normal lig ve deneme ligi ayrı puanlarla yarışır. Her ikisi de İstanbul saatiyle ayın 1’inde 00:00’da yenilenir. Günlük çalışma ve seri takibi 04:00 kuralıyla devam eder.'**
  String get leagueCalendarMonthBody;

  /// No description provided for @leagueCalendarPreparingBody.
  ///
  /// In tr, this message translates to:
  /// **'Aylık yarışma için hazırlık sürüyor. Resmî başlangıç: {date} (İstanbul). Odada yeterli aktif katılımcı olduğunda terfi ve ödül şartları uygulanır. Tamamladığın seanslar ve kazandığın toplam puan korunur.'**
  String leagueCalendarPreparingBody(String date);

  /// No description provided for @leagueCalendarPreparingGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Aylık yarışma için hazırlık sürüyor. Yeterli aktif katılımcı olmadan terfi, düşme veya lig ödülü verilmez; seansların kaydolmaya devam eder.'**
  String get leagueCalendarPreparingGeneric;

  /// No description provided for @leagueTargetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig hedefin'**
  String get leagueTargetTitle;

  /// No description provided for @leagueTargetCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay: {target}'**
  String leagueTargetCurrent(String target);

  /// No description provided for @leagueTargetPending.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki hedef: {target} · {date} (İstanbul)'**
  String leagueTargetPending(String target, String date);

  /// No description provided for @leagueTargetChange.
  ///
  /// In tr, this message translates to:
  /// **'Hedefi değiştir'**
  String get leagueTargetChange;

  /// No description provided for @leagueTargetDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lig hedefini seç'**
  String get leagueTargetDialogTitle;

  /// No description provided for @leagueTargetPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Normal ligde ve deneme liginde aynı hedefteki kullanıcılarla eşleşirsin. İlk seansından önce hedef hemen değişir. Ay içinde değiştirdiğinde yeni hedef sonraki ayın 1’inde, İstanbul saatiyle 00:00’da uygulanır; bu ayki puanın ve odan korunur. Global görünüm hedefini değiştirmez ve ek ödül kazandırmaz.'**
  String get leagueTargetPolicy;

  /// No description provided for @leagueTargetSave.
  ///
  /// In tr, this message translates to:
  /// **'Hedefi kaydet'**
  String get leagueTargetSave;

  /// No description provided for @leagueTargetSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Hedef kaydedilemedi. Bağlantını kontrol edip tekrar dene.'**
  String get leagueTargetSaveError;

  /// No description provided for @leagueTargetOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get leagueTargetOther;

  /// No description provided for @leagueGlobalScopeBody.
  ///
  /// In tr, this message translates to:
  /// **'Tüm hedeflerdeki kullanıcıların bu ay kazandığı normal odak puanları. Deneme puanları ayrı ligdedir; global görünüm ek ödül vermez.'**
  String get leagueGlobalScopeBody;

  /// No description provided for @examFinishEarly.
  ///
  /// In tr, this message translates to:
  /// **'AYT\'yi bitir'**
  String get examFinishEarly;

  /// No description provided for @examFinishEarlyTitle.
  ///
  /// In tr, this message translates to:
  /// **'AYT\'yi erken bitirmek istiyor musun?'**
  String get examFinishEarlyTitle;

  /// No description provided for @examFinishEarlyBody.
  ///
  /// In tr, this message translates to:
  /// **'Bitirme isteğin sunucu tarafından kabul edildiğinde süre ve ödül kesinleşir. Ardından çözdüğün testleri seçip netlerini, başlığını ve notunu kaydedebilirsin.'**
  String get examFinishEarlyBody;

  /// No description provided for @examEarlyPendingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Erken bitirme onayı bekleniyor'**
  String get examEarlyPendingTitle;

  /// No description provided for @examEarlyPendingBody.
  ///
  /// In tr, this message translates to:
  /// **'İsteğin bu cihazda saklandı. Süre ve ödül sunucu kabul ettiğinde kesinleşir; bağlantı geldiğinde tekrar gönderilir. O zamana kadar planlanan süre dolarsa tam süre kuralları uygulanır.'**
  String get examEarlyPendingBody;

  /// No description provided for @examEarlyUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu sunucuda erken bitirme şu anda kullanılamıyor. Kaydın silinmedi; yeniden deneyebilir veya bağlantı durumunu kontrol edebilirsin.'**
  String get examEarlyUnavailable;

  /// No description provided for @examEarlyTooSoon.
  ///
  /// In tr, this message translates to:
  /// **'Bitirmeden önce en az bir saniye geçmeli. Yeniden deneyebilirsin.'**
  String get examEarlyTooSoon;

  /// No description provided for @examCompletedEarly.
  ///
  /// In tr, this message translates to:
  /// **'Erken tamamlandı'**
  String get examCompletedEarly;

  /// No description provided for @examActualPlanned.
  ///
  /// In tr, this message translates to:
  /// **'Gerçek süre: {actual} · Planlanan: {planned}'**
  String examActualPlanned(String actual, String planned);

  /// No description provided for @examCreditedMinutes.
  ///
  /// In tr, this message translates to:
  /// **'Rapora eklenen: {minutes} dk'**
  String examCreditedMinutes(int minutes);

  /// No description provided for @examSeconds.
  ///
  /// In tr, this message translates to:
  /// **'{seconds} sn'**
  String examSeconds(int seconds);

  /// No description provided for @examDetailsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Deneme ayrıntıları ve netler'**
  String get examDetailsTitle;

  /// No description provided for @examTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Deneme başlığı'**
  String get examTitleLabel;

  /// No description provided for @examNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get examNoteLabel;

  /// No description provided for @examSelectModules.
  ///
  /// In tr, this message translates to:
  /// **'Çözdüğün AYT testlerini seç'**
  String get examSelectModules;

  /// No description provided for @examModuleHint.
  ///
  /// In tr, this message translates to:
  /// **'Net girmek için en az bir test seç. Başlık ve notunu net girmeden de kaydedebilirsin.'**
  String get examModuleHint;

  /// No description provided for @examModuleUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Bu kayıtta AYT test seçimi henüz yok.'**
  String get examModuleUnknown;

  /// No description provided for @examScopeUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen kapsam hesaplanamadı.'**
  String get examScopeUnavailable;

  /// No description provided for @examSelectedQuestions.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen kapsam: {selected} / {total} soru'**
  String examSelectedQuestions(int selected, int total);

  /// No description provided for @examReligionAlternativeInfo.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal Bilimler-2\'de Din Kültürü / ek felsefe alanı toplam 6 sorudur; aynı alan iki kez sayılmaz.'**
  String get examReligionAlternativeInfo;

  /// No description provided for @examDetailsEdit.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıntıları ve netleri düzenle'**
  String get examDetailsEdit;

  /// No description provided for @examDetailsSaved.
  ///
  /// In tr, this message translates to:
  /// **'Deneme ayrıntıların ve netlerin kaydedildi.'**
  String get examDetailsSaved;

  /// No description provided for @examDetailsQueued.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıntıların ve netlerin bu cihazda saklandı; bağlantı geldiğinde aynı istek gönderilecek.'**
  String get examDetailsQueued;

  /// No description provided for @examDetailsConflict.
  ///
  /// In tr, this message translates to:
  /// **'Bu deneme başka bir yerde düzenlenmiş. Güncel kaydı yükle, değişikliklerini kontrol et ve tekrar kaydet.'**
  String get examDetailsConflict;

  /// No description provided for @examScopeConflict.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçları kaydedilmiş bir testi seçimin dışına çıkaramazsın. Test seçimini ve girdiğin dersleri kontrol et.'**
  String get examScopeConflict;

  /// No description provided for @examDetailsInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Başlık en fazla 120, not en fazla 2000 karakter olabilir. Başlık tek satır olmalı; test seçimini ve sonuçlarını da kontrol et.'**
  String get examDetailsInvalid;

  /// No description provided for @examDetailsReload.
  ///
  /// In tr, this message translates to:
  /// **'Güncel kaydı yükle'**
  String get examDetailsReload;

  /// No description provided for @examDetailsPending.
  ///
  /// In tr, this message translates to:
  /// **'Önceki kayıt isteğinin sonucu bekleniyor. Yeniden gönderebilir, sonucu aldıktan sonra düzenlemeye devam edebilirsin.'**
  String get examDetailsPending;

  /// No description provided for @examDefinitionUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu AYT kaydının test yapısı tanınmıyor. Kaydın korundu; güncel sınav bilgisi için bağlantını kontrol et.'**
  String get examDefinitionUnsupported;

  /// No description provided for @examDetailsUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu sunucuda başlık, not ve test seçimi düzenleme henüz kullanılamıyor.'**
  String get examDetailsUnavailable;

  /// No description provided for @examIntroEarly.
  ///
  /// In tr, this message translates to:
  /// **'Sınavını seç ve çalışmaya başla. AYT\'yi erken bitirebilir, ardından çözdüğün testleri ve netlerini kaydedebilirsin.'**
  String get examIntroEarly;

  /// No description provided for @examCharacterCount.
  ///
  /// In tr, this message translates to:
  /// **'{current} / {maximum} karakter'**
  String examCharacterCount(int current, int maximum);

  /// No description provided for @onboardingSegmentDus.
  ///
  /// In tr, this message translates to:
  /// **'DUS (Diş Hekimliğinde Uzmanlık)'**
  String get onboardingSegmentDus;

  /// No description provided for @examTabNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get examTabNew;

  /// No description provided for @examTabHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get examTabHistory;

  /// No description provided for @examTabLeague.
  ///
  /// In tr, this message translates to:
  /// **'Lig'**
  String get examTabLeague;

  /// No description provided for @examFilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get examFilterAll;

  /// No description provided for @examMyGoal.
  ///
  /// In tr, this message translates to:
  /// **'{goal} sınavlarım'**
  String examMyGoal(String goal);

  /// No description provided for @examExtraExams.
  ///
  /// In tr, this message translates to:
  /// **'Ek sınavlar'**
  String get examExtraExams;

  /// No description provided for @examEmptyFilter.
  ///
  /// In tr, this message translates to:
  /// **'Bu seçim için henüz deneme bulunmuyor.'**
  String get examEmptyFilter;

  /// No description provided for @examHistoryDetails.
  ///
  /// In tr, this message translates to:
  /// **'Deneme ayrıntıları'**
  String get examHistoryDetails;

  /// No description provided for @examNetInfo.
  ///
  /// In tr, this message translates to:
  /// **'YKS, TUS, DUS ve KPSS: 4 yanlış 1 doğruyu; LGS: 3 yanlış 1 doğruyu götürür. Netlerin bu kurala göre hesaplanır.'**
  String get examNetInfo;

  /// No description provided for @examAytTestCount.
  ///
  /// In tr, this message translates to:
  /// **'4 test'**
  String get examAytTestCount;

  /// No description provided for @examKpssChooseTrack.
  ///
  /// In tr, this message translates to:
  /// **'KPSS türünü seç'**
  String get examKpssChooseTrack;

  /// No description provided for @examKpssBachelor.
  ///
  /// In tr, this message translates to:
  /// **'Lisans'**
  String get examKpssBachelor;

  /// No description provided for @examKpssAssociate.
  ///
  /// In tr, this message translates to:
  /// **'Ön Lisans'**
  String get examKpssAssociate;

  /// No description provided for @examKpssSecondary.
  ///
  /// In tr, this message translates to:
  /// **'Ortaöğretim'**
  String get examKpssSecondary;

  /// No description provided for @examKpssField.
  ///
  /// In tr, this message translates to:
  /// **'Alan Bilgisi'**
  String get examKpssField;
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
