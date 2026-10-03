// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get authEmailHint => 'ornek@posta.com';

  @override
  String get authAppleSignInBtn => 'Apple ile Giriş Yap';

  @override
  String get authSocialConsentPrefix => 'Devam ederek ';

  @override
  String get authSocialConsentSuffix => ' kabul etmiş olursun.';

  @override
  String authResendAvailableIn(int seconds) {
    return '$seconds sn sonra tekrar gönderebilirsin';
  }

  @override
  String get onboardingSelectCategoryError =>
      'Devam etmek için en az bir kategori seç.';

  @override
  String get onboardingUnder13Error =>
      'PomoSprint\'i kullanmak için en az 13 yaşında olmalısın.';

  @override
  String get onboardingSessionExpired =>
      'Oturumun sona erdi. Lütfen tekrar giriş yap.';

  @override
  String get onboardingSaveError =>
      'Bilgilerin kaydedilemedi. Lütfen tekrar dene.';

  @override
  String onboardingCategoryStepBodyLimit(int limit) {
    return 'Şimdi çalışacağın dersleri/alanları seç; istediğin zaman değiştirebilirsin. En fazla $limit tane seçebilirsin.';
  }

  @override
  String get categoryNameExistsMsg => 'Bu isimde bir kategori zaten var.';

  @override
  String get categoriesLoadError =>
      'Kategoriler yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get categorySaveError =>
      'Değişiklik kaydedilemedi. Lütfen tekrar dene.';

  @override
  String get categoriesRetryBtn => 'Tekrar Dene';

  @override
  String get rankingTabLeague => 'Lig';

  @override
  String get rankingTabMonthly => 'Aylık';

  @override
  String get rankingTabFriends => 'Arkadaşlar';

  @override
  String get rankingMonthlyResetIn =>
      'Aylık sıralamanın sıfırlanmasına kalan süre';

  @override
  String get rankingLoadError =>
      'Sıralama yüklenemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String rankingMyStatus(int rank, int points) {
    return 'Sıran: #$rank · $points puan';
  }

  @override
  String rankingPoints(int points) {
    return '$points puan';
  }

  @override
  String rankingCountdownDays(int days, int hours, int minutes) {
    return '$days gün $hours saat $minutes dk';
  }

  @override
  String rankingCountdownHours(int hours, int minutes, int seconds) {
    return '$hours saat $minutes dk $seconds sn';
  }

  @override
  String get rankingCountdownResetting => 'Sıfırlanıyor...';

  @override
  String get socialRetry => 'Tekrar Dene';

  @override
  String get socialRefreshFailed =>
      'Güncellenemedi, son yüklenen veriler gösteriliyor.';

  @override
  String get socialErrNetwork =>
      'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';

  @override
  String get socialErrSession =>
      'Oturumun sona ermiş. Lütfen yeniden giriş yap.';

  @override
  String get socialErrGeneric => 'Bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get socialErrInsufficientCoins => 'Yeterli kum tanen yok.';

  @override
  String get socialErrAvatarLocked => 'Bu avatarın henüz sahibi değilsin.';

  @override
  String get socialYourFriends => 'Arkadaşların';

  @override
  String get socialFocusingNow => 'Şu An Çalışanlar';

  @override
  String get socialFocusing => 'Odaklanıyor';

  @override
  String socialFocusingOn(String category) {
    return '$category çalışıyor';
  }

  @override
  String get socialNoLiveFriends =>
      'Şu an çalışan arkadaşın yok. Biri odaklanmaya başladığında burada görünecek.';

  @override
  String get socialLoadError =>
      'Arkadaşlarının durumu yüklenemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get leagueTierBronze => 'Bronz Kum Saati';

  @override
  String get leagueTierSilver => 'Gümüş Kum Saati';

  @override
  String get leagueTierGold => 'Altın Kum Saati';

  @override
  String get leagueTierSapphire => 'Safir Kum Saati';

  @override
  String get leagueTierDiamond => 'Elmas Kum Saati';

  @override
  String leagueTierLeagueName(String tier) {
    return '$tier Ligi';
  }

  @override
  String get leagueInfoTitle => 'Lig Sistemi Nasıl Çalışır?';

  @override
  String get leagueInfoWhatTitle => 'Lig Nedir?';

  @override
  String get leagueInfoWhatBody =>
      'Her lig döneminde seninle benzer seviyedeki en fazla 30 kişiyle aynı gruba düşersin. Dönem boyunca kim daha çok odaklanırsa üst sıraya çıkar.';

  @override
  String get leagueInfoTiersTitle => 'Lig Kademeleri';

  @override
  String get leagueInfoYouAreHere => 'Şu an buradasın';

  @override
  String get leagueInfoPointsTitle => 'Puan Nasıl Kazanılır?';

  @override
  String leagueInfoPoints25(String points) {
    return '25 dakikalık odak: $points puan';
  }

  @override
  String leagueInfoPoints50(String points) {
    return '50 dakikalık odak: $points puan';
  }

  @override
  String get leagueInfoStreakBonus => 'Seri bonusu:';

  @override
  String leagueInfoStreakRange(String from, String to, String pct) {
    return '$from-$to gün: %$pct';
  }

  @override
  String leagueInfoStreakRangeOpen(String from, String pct) {
    return '$from+ gün: %$pct';
  }

  @override
  String get leagueInfoStreakKeep =>
      'Her gün en az 1 pomodoro tamamlayarak serini canlı tut.';

  @override
  String leagueInfoPausePenalty(String pct) {
    return 'Seansı duraklatırsan puan %$pct azalır.';
  }

  @override
  String leagueInfoCoins(String coins, String limit) {
    return '🪙 Kum tanesi: Tamamladığın her seanstan (günde $limit seansa kadar) $coins kum tanesi kazanırsın. Karakter koleksiyonundan yeni kum saatleri açmak için kullanılır.';
  }

  @override
  String get leagueInfoPromotionTitle => 'Yükselme ve Düşme';

  @override
  String leagueInfoPeriodEnds(String date) {
    return 'Bu lig dönemi $date tarihinde sona erer. Dönem sonunda sıralamana göre yükselir, kalır ya da düşersin.';
  }

  @override
  String get leagueInfoPeriodGeneric =>
      'Lig dönemi sona erdiğinde sıralamana göre yükselir, kalır ya da düşersin.';

  @override
  String get leagueInfoTopTier => 'En üst ligdesin, yükselecek yer yok.';

  @override
  String leagueInfoPromote(int count) {
    return 'Bu dönem puan toplayan ilk $count kişi bir üst lige yükselir.';
  }

  @override
  String leagueInfoDemote(int count) {
    return 'Son $count kişi bir alt lige düşer.';
  }

  @override
  String get leagueInfoNoDemotionBronze => 'Bronz ligde düşme yoktur.';

  @override
  String get leagueInfoNoDemotionThisPeriod => 'Bu dönem bu ligde düşme yok.';

  @override
  String get leagueAwaitingPlacementTitle => 'Henüz bir lig odasında değilsin';

  @override
  String get leagueAwaitingPlacementBody =>
      'Bu dönem ilk pomodoronu tamamladığında seninle benzer seviyedeki en fazla 30 kişilik bir odaya yerleşirsin. Sıralaman ve yükselme durumun burada görünür.';

  @override
  String get leagueInfoDailyLimitTitle => 'Günlük Sınır';

  @override
  String leagueInfoDailyLimitBody(String limit) {
    return 'Günde en fazla $limit seans puan ve kum kazandırır (lig puanı, aylık sıralama, toplam puan). Sonraki seanslar yalnızca çalışma süresine ve serine eklenir.';
  }

  @override
  String get leagueInfoFaqTitle => 'Puanım Neden Artmadı?';

  @override
  String leagueInfoFaqLimit(String limit) {
    return 'Günlük $limit seans sınırına ulaşmış olabilirsin.';
  }

  @override
  String get leagueInfoFaqCancelled =>
      'Seansı çok erken iptal etmiş olabilirsin.';

  @override
  String get leagueInfoFaqReset => 'Lig dönemi yeni sıfırlanmış olabilir.';

  @override
  String get leagueInfoFaqPending =>
      'Çevrimdışıyken tamamladığın seanslar bağlantı gelince gönderilir; puanın o zaman eklenir.';

  @override
  String get friendsTitle => 'Arkadaşlar';

  @override
  String get friendsMyCode => 'Senin Arkadaşlık Kodun';

  @override
  String get friendsCopyCode => 'Kodu kopyala';

  @override
  String get friendsCodeCopied => 'Kod kopyalandı!';

  @override
  String get friendsAddByCode => 'Kod ile Arkadaş Ekle';

  @override
  String get friendsCodeHint => 'Örn: A1B2C3';

  @override
  String friendsAdded(String name) {
    return '✅ $name arkadaş listene eklendi!';
  }

  @override
  String friendsRequestSent(String name) {
    return '📨 $name kullanıcısına arkadaşlık isteği gönderildi. Onay bekleniyor.';
  }

  @override
  String get friendsErrNotFound => 'Bu koda sahip bir kullanıcı bulunamadı.';

  @override
  String get friendsErrSelf => 'Kendi kodunu ekleyemezsin.';

  @override
  String get friendsErrAlreadyFriends => 'Bu kullanıcıyla zaten arkadaşsınız.';

  @override
  String get friendsErrAlreadyPending =>
      'Bu kullanıcıyla bekleyen bir arkadaşlık isteğin zaten var.';

  @override
  String get friendsErrAddFailed =>
      'Arkadaş eklenemedi. Kodu kontrol edip tekrar dene.';

  @override
  String friendsIncoming(int count) {
    return 'Gelen İstekler ($count)';
  }

  @override
  String get friendsAccept => 'Kabul et';

  @override
  String get friendsReject => 'Reddet';

  @override
  String get friendsAccepted => '✅ Arkadaşlık isteği kabul edildi!';

  @override
  String get friendsRespondFailed => 'İstek yanıtlanamadı. Lütfen tekrar dene.';

  @override
  String get friendsRequestGone => 'Bu istek artık geçerli değil.';

  @override
  String friendsYourFriends(int count) {
    return 'Arkadaşların ($count)';
  }

  @override
  String get friendsEmpty =>
      'Henüz arkadaşın yok. Kodunu paylaş veya yukarıdan bir kod gir!';

  @override
  String get friendsLoadError =>
      'Arkadaş listen yüklenemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get profileNameTooShort => 'İsim en az 2 karakter olmalı.';

  @override
  String get profileNameTooLong => 'İsim en fazla 30 karakter olabilir.';

  @override
  String get profileDeleteConfirm =>
      'Hesabını ve tüm verilerini kalıcı olarak silmek istediğinden emin misin?\n\nŞunların hepsi silinir ve geri alınamaz: çalışma geçmişin ve seansların, puanların ve serin, kum tanelerin ve avatarların, kategorilerin, arkadaşların ve lig kaydın.';

  @override
  String get profileDeleting => 'Hesabın siliniyor...';

  @override
  String get profileDeleteError =>
      'Hesabın silinemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String profileDeleteConfirmPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu cihazda henüz gönderilmemiş $count seansın da silinir.',
      one: 'Bu cihazda henüz gönderilmemiş 1 seansın da silinir.',
    );
    return '$_temp0';
  }

  @override
  String get profileDeleteConfirmApple =>
      'Apple ile giriş yaptığın için silmeden önce Apple seni bir kez daha doğrulayacak; böylece PomoSprint\'in Apple ile Giriş bağlantısı da kaldırılır.';

  @override
  String get profileDeleteConfirmCopyHint =>
      'Verilerinin bir kopyasını istiyorsan önce \"Gizlilik ve yasal\" bölümündeki \"Verilerimin kopyasını iste\"yi kullan.';

  @override
  String get accountDeletedNotice => 'Hesabın ve tüm verilerin silindi.';

  @override
  String get accountDeletedAppleNotice =>
      'Apple ile Giriş bağlantısını da kaldırmak için iPhone\'da Ayarlar > Apple Hesabı (adın) > Apple ile Giriş > PomoSprint > Kullanmayı Durdur adımlarını izle.';

  @override
  String get sessionExpiredNotice =>
      'Oturumun sona erdi. Şifren değişmiş ya da hesabın başka bir cihazdan kapatılmış olabilir; lütfen yeniden giriş yap.';

  @override
  String get appleCredentialRevokedNotice =>
      'Bu cihazda Apple ile Giriş izni kaldırıldığı için oturumun kapatıldı. Devam etmek için yeniden Apple ile giriş yap.';

  @override
  String get noticeDismissTooltip => 'Kapat';

  @override
  String get profileNotificationsDenied =>
      'Bildirim izni verilmedi. Bildirimleri telefonunun Ayarlar bölümünden PomoSprint için açabilirsin.';

  @override
  String get profileSettingSaveError =>
      'Ayar kaydedilemedi. Lütfen tekrar dene.';

  @override
  String avatarBalance(int coins) {
    return 'Bakiyen: $coins kum tanesi';
  }

  @override
  String get avatarPurchaseTitle => 'Satın Al';

  @override
  String avatarPurchaseBody(String name, int price) {
    return '$name avatarını $price kum tanesine satın almak ister misin?';
  }

  @override
  String avatarNotEnoughCoins(int missing) {
    return 'Yetersiz bakiye: $missing kum tanesi daha gerekiyor.';
  }

  @override
  String avatarPurchased(String name) {
    return '$name artık senin!';
  }

  @override
  String get avatarPremiumTitle => 'Premium Avatar';

  @override
  String get avatarPremiumBody => 'Bu avatar Premium üyelere özel.';

  @override
  String avatarPremiumUnlockBody(String name) {
    return 'Premium üyeliğinle $name avatarını ücretsiz açabilirsin.';
  }

  @override
  String get avatarUnlockBtn => 'Aç';

  @override
  String get coinsCaption => '🪙 KUM';

  @override
  String pendingSessionsBanner(int count) {
    return '$count senkronize edilmemiş seansın var. Tekrar denemek için dokun.';
  }

  @override
  String sessionPointsBreakdown(int base, int bonus, int pct, int total) {
    return '🔥 $base puan + $bonus seri bonusu (%$pct) = $total puan!';
  }

  @override
  String sessionDailyLimitReached(int limit) {
    return 'Bugünlük puan ve kum sınırına ulaştın ($limit seans). Sonraki seanslar yalnızca çalışma süresine ve serine eklenir.';
  }

  @override
  String get sessionQueuedOffline =>
      '⚠️ Seans şu an buluta kaydedilemedi, bağlantı gelince otomatik gönderilecek.';

  @override
  String get sessionQueuedClockSkew =>
      '⚠️ Seans bekletiliyor: cihazının saati sunucudan farklı görünüyor. Saat ayarını kontrol et; seans otomatik olarak yeniden denenecek.';

  @override
  String get sessionQueuedOverlap =>
      '⚠️ Seans önceki bir kayıtla çakışıyor; bekletiliyor ve daha sonra yeniden denenecek.';

  @override
  String get sessionRejectedTooOld =>
      '⚠️ Bu seans 24 saatten eski olduğu için kaydedilemedi.';

  @override
  String get sessionRejectedClock =>
      '⚠️ Bu seans kaydedilemedi: cihazının saati ileri görünüyor. Saat ayarını kontrol et.';

  @override
  String get sessionRejectedOverlap =>
      '⚠️ Bu seans kaydedilemedi: aynı zaman aralığında kayıtlı başka bir seans var.';

  @override
  String get sessionRejectedGeneric =>
      '⚠️ Bu seans kaydedilemedi: sunucu doğrulamasından geçmedi.';

  @override
  String rejectedSessionsNotice(int count) {
    return '⚠️ Bekleyen $count seans sunucu tarafından reddedildi ve kaydedilemedi.';
  }

  @override
  String get pausedSessionExpired =>
      'Duraklatılmış seansın 24 saati aştığı için kaydedilemedi ve sıfırlandı.';

  @override
  String get leaveWhileRunningTitle => 'Seansın sürüyor';

  @override
  String get leaveWhileRunningBody =>
      'Uygulamadan çıksan da sayaç çalışmaya devam eder; geri döndüğünde seansın kaldığı yerden sürer.';

  @override
  String get leaveWhileRunningStay => 'Kal';

  @override
  String get leaveWhileRunningLeave => 'Arka plana al';

  @override
  String get notifSessionDoneTitle => 'Pomodoro tamamlandı! 🎉';

  @override
  String notifSessionDoneBody(String category) {
    return '$category seansın bitti. Puanlarını görmek için uygulamaya dön.';
  }

  @override
  String get notifChannelName => 'Seans bildirimleri';

  @override
  String get notifChannelDescription =>
      'Pomodoro seansın bittiğinde haber verir.';

  @override
  String get lockTimerChannelName => 'Süren seans';

  @override
  String get lockTimerChannelDescription =>
      'Seans sürerken kalan süreyi kilit ekranında ve bildirim panelinde gösterir.';

  @override
  String lockTimerRunningBody(String time) {
    return 'Odaklanıyorsun · bitiş $time';
  }

  @override
  String lockTimerPausedBody(String remaining) {
    return 'Duraklatıldı · $remaining kaldı';
  }

  @override
  String get lockTimerStatusRunning => 'Odaklanıyorsun';

  @override
  String get lockTimerStatusPaused => 'Duraklatıldı';

  @override
  String get lockTimerStatusDone => 'Seans tamamlandı';

  @override
  String get lockTimerDoneHint => 'Seansını kaydetmek için PomoSprint\'i aç.';

  @override
  String get statsLoadErrorTitle => 'İstatistikler yüklenemedi';

  @override
  String get statsLoadErrorOffline =>
      'Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get statsLoadErrorSignedOut =>
      'İstatistiklerini görmek için tekrar giriş yapman gerekiyor.';

  @override
  String get statsLoadErrorGeneric =>
      'Veriler alınırken bir sorun oluştu. Lütfen tekrar dene.';

  @override
  String get statsRetry => 'Tekrar Dene';

  @override
  String get statsStaleNotice =>
      'Güncel veriler alınamadı; son yüklenen veriler gösteriliyor.';

  @override
  String statsPendingSessions(int count) {
    return '$count seans senkron bekliyor';
  }

  @override
  String get statsNoStudyTodayTitle => 'Bugün henüz çalışmadın';

  @override
  String get statsNoStudyTodayDesc =>
      'Bir Pomodoro başlat; bugünün ders dağılımı burada görünecek.';

  @override
  String get statsNoStudyThisWeekTitle => 'Bu hafta henüz çalışmadın';

  @override
  String get statsNoStudyThisWeekDesc =>
      'Bir Pomodoro başlat; haftalık analizin burada oluşacak.';

  @override
  String get statsGoalSheetSubtitle => 'Günde ne kadar odaklanmak istiyorsun?';

  @override
  String statsGoalPomodoroApprox(int count) {
    return '≈ $count Pomodoro';
  }

  @override
  String get statsGoalSaveFailed =>
      'Hedef kaydedilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String statsTodayPomodoros(int count) {
    return 'Bugün $count Pomodoro tamamlandı';
  }

  @override
  String get statsWeeklyGoalTitle => 'Haftalık Hedef';

  @override
  String statsWeeklyGoalSubtitle(String weekly) {
    return '$weekly · günlük hedefin × 7';
  }

  @override
  String statsWeekLabel(int index) {
    return 'Hafta $index';
  }

  @override
  String statsWeekStudyTotal(String duration) {
    return '$duration Çalışma';
  }

  @override
  String statsWeekChangeUp(String percent) {
    return 'Önceki haftanın aynı günlerine göre $percent artış';
  }

  @override
  String statsWeekChangeDown(String percent) {
    return 'Önceki haftanın aynı günlerine göre $percent düşüş';
  }

  @override
  String statsMonthMotivation(String percent) {
    return 'Geçen ayın aynı dönemine göre odağını $percent artırdın, harika gidiyorsun!';
  }

  @override
  String get statsMonthEmptyTitle => 'Bu ay henüz çalışma kaydın yok';

  @override
  String get statsMonthEmptyDesc =>
      'Bu ay ilk Pomodoro\'nu tamamladığında aylık takip burada görünecek.';

  @override
  String get statsOtherCategory => 'Diğer';

  @override
  String get statsShowAsDuration => 'Süre olarak göster';

  @override
  String get statsShowAsPercent => 'Yüzde olarak göster';

  @override
  String get statsOfflinePendingOnly =>
      'Sunucuya bağlanılamadı; yalnızca bu cihazda senkron bekleyen seanslar gösteriliyor.';

  @override
  String get statsOtherCategories => 'Diğer kategoriler';

  @override
  String statsMoreCategories(int count) {
    return '+$count kategori daha';
  }

  @override
  String get statsGoalReached => 'Bugünkü hedefine ulaştın, tebrikler!';

  @override
  String get statsTipFocusBlock =>
      'Seansa başlamadan önce o seansta bitireceğin tek bir işi belirle.';

  @override
  String get statsWeekNotStarted => 'Henüz başlamadın';

  @override
  String get statsWeekChangeSame => 'Önceki haftanın aynı günleriyle aynı';

  @override
  String statsGoalPomodorosNeeded(int count) {
    return 'Hedef için $count Pomodoro';
  }

  @override
  String get authErrWeakPassword =>
      'Şifren çok zayıf. En az 1 küçük harf (a-z), 1 büyük harf (A-Z) ve 1 rakam (0-9) içermeli.';

  @override
  String get authErrEmailExistsResent =>
      'Bu e-posta adresi zaten kayıtlı! Doğrulama bağlantısı e-postana tekrar gönderildi.';

  @override
  String get authErrInvalidCredentials =>
      'E-posta adresi veya şifre hatalı ya da hesabın henüz onaylanmamış olabilir. Şifreni kontrol et; sorun sürerse aşağıdan onay e-postasını tekrar gönderebilirsin.';

  @override
  String get authErrEmailNotConfirmed =>
      'E-posta adresin henüz doğrulanmamış. Lütfen gelen kutundaki onay bağlantısına tıkla.';

  @override
  String get authErrRateLimited =>
      'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyip tekrar dene.';

  @override
  String get authErrNetwork =>
      'İnternet veya sunucu bağlantısı kurulamadı. Lütfen ağ bağlantını kontrol et.';

  @override
  String get authErrInvalidEmail => 'Lütfen geçerli bir e-posta adresi gir.';

  @override
  String get authErrCloudUnavailable =>
      'Sunucuya bağlanılamadı. Lütfen internet bağlantını kontrol et.';

  @override
  String get authErrProfileLoad =>
      'Profilin yüklenemedi. Lütfen bağlantını kontrol edip tekrar giriş yap.';

  @override
  String get authErrGoogleFailed =>
      'Google ile giriş yapılamadı. Lütfen tekrar dene.';

  @override
  String get authErrAppleFailed =>
      'Apple ile giriş yapılamadı. Lütfen tekrar dene.';

  @override
  String get authErrUnknown => 'Bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get authErrSignUpTimeout =>
      'Kayıt isteği yanıt vermedi. Kaydın yine de tamamlanmış olabilir: e-postanı kontrol et ya da giriş yapmayı dene.';

  @override
  String get navTimer => 'Süreç';

  @override
  String get navSocial => 'Sosyal';

  @override
  String get navReports => 'Raporlar';

  @override
  String get navProfile => 'Profil';

  @override
  String get navHistory => 'Geçmiş';

  @override
  String get navRanking => 'Sıralama';

  @override
  String get navCategories => 'Kategoriler';

  @override
  String get titleTimer => 'PomoSprint';

  @override
  String get titleReports => 'Ders Raporları & Geçmiş';

  @override
  String get titleRanking => 'Liderlik Tablosu';

  @override
  String get titleSocial => 'Sanal Kütüphane & Masalar';

  @override
  String get titleCategories => 'Ders Kategorileri';

  @override
  String get selectSubject => 'DERS SEÇ';

  @override
  String get addSubject => 'Ders Ekle';

  @override
  String get btnStart => 'BAŞLAT';

  @override
  String get btnPause => 'DURDUR';

  @override
  String get btnReset => 'SIFIRLA';

  @override
  String get modePomodoro => 'Pomodoro';

  @override
  String get modeShortBreak => 'Kısa Mola';

  @override
  String get modeLongBreak => 'Uzun Mola';

  @override
  String get dailyStreak => 'Günlük Seri';

  @override
  String get dailyGoal => 'Günlük Hedef';

  @override
  String get sessionCompleted => 'Tebrikler! Seans Tamamlandı 🎉';

  @override
  String get durationPlanning => 'Süre Planlama';

  @override
  String get pauseCreditAvailable => '1/1 Duraklatma Hakkı';

  @override
  String get pauseCreditUsed => '0/1 Duraklatma Hakkı (Hakkın Bitti)';

  @override
  String focusTimeMinutes(Object minutes) {
    return '$minutes DK FOCUS TIME';
  }

  @override
  String get catMath => 'Matematik';

  @override
  String get catPhysics => 'Fizik';

  @override
  String get catHistory => 'Tarih';

  @override
  String get catChemistry => 'Kimya';

  @override
  String get catBiology => 'Biyoloji';

  @override
  String get catLiterature => 'Edebiyat';

  @override
  String get catEnglish => 'İngilizce';

  @override
  String get avatarGamer => 'Gamer Çırak';

  @override
  String get avatarGamerDesc => 'Başlangıç karakterin. 1 seans tamamla.';

  @override
  String get avatarGlasses => 'Gözlüklü Bilgin';

  @override
  String get avatarGlassesDesc => '5 seans tamamlayarak kilidini aç.';

  @override
  String get avatarGentleman => 'Centilmen';

  @override
  String get avatarGentlemanDesc => '10 seans tamamlayarak kilidini aç.';

  @override
  String get avatarCyberpunk => 'Cyberpunk';

  @override
  String get avatarCyberpunkDesc => '15 seans tamamlayarak kilidini aç.';

  @override
  String get avatarCat => 'Kedi Sever';

  @override
  String get avatarCatDesc => '20 seans tamamlayarak kilidini aç.';

  @override
  String get avatarCoder => 'Kodlama Uzmanı';

  @override
  String get avatarCoderDesc => '30 seans tamamlayarak kilidini aç.';

  @override
  String get avatarNinja => 'Ninja';

  @override
  String get avatarNinjaDesc => '50 seans tamamlayarak kilidini aç.';

  @override
  String get avatarAstronaut => 'Astronot';

  @override
  String get avatarAstronautDesc => '75 seans tamamlayarak kilidini aç.';

  @override
  String get avatarViking => 'Viking';

  @override
  String get avatarVikingDesc => '100 seans tamamlayarak kilidini aç.';

  @override
  String get selectCharacter => 'Karakterini Seç';

  @override
  String get selectCharacterSub =>
      'Odaklanma seanslarında sana eşlik edecek karakterini seç.';

  @override
  String get confirmSelection => 'Seçimi Onayla';

  @override
  String get leagueAwardsTitle => 'Lig Kazanımları';

  @override
  String get leagueAwardsSub =>
      'Bir lig dönemini puan toplayarak ilk 3\'te bitirince kazanılır: 1.\'ye Şampiyonluk, 2. ve 3.\'ye Podyum Ödülü.';

  @override
  String get leagueAwardLockedTitle => 'Bu Avatar Kilitli';

  @override
  String get leagueAwardLockedBody =>
      'Bu avatarı kazanmak için bu kademede bir lig dönemini puan toplayarak ilk 3\'te bitirmen gerekiyor. Parayla satın alınamaz.';

  @override
  String get leagueAwardLockedBodyChampion =>
      'Bu Şampiyonluk Ödülü\'nü kazanmak için bu kademede bir lig dönemini puan toplayarak 1. sırada bitirmen gerekiyor. Parayla satın alınamaz.';

  @override
  String get leagueAwardLockedBodyPodium =>
      'Bu Podyum Ödülü\'nü kazanmak için bu kademede bir lig dönemini puan toplayarak 2. veya 3. sırada bitirmen gerekiyor (1. olan Şampiyonluk Ödülü\'nü alır). Parayla satın alınamaz.';

  @override
  String get leagueAwardLockedOk => 'Anladım';

  @override
  String get lockedCharacter => 'Kilitli Karakter';

  @override
  String get welcomeBackTitle => 'Tekrar hoş geldin. Odaklanmaya hazır mısın?';

  @override
  String get emailOrUsername => 'Kullanıcı Adı veya E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get loginBtn => 'Giriş Yap';

  @override
  String get forgotPassword => 'Şifremi Unuttum';

  @override
  String get noAccountText => 'Hesabın yok mu? ';

  @override
  String get signUpLink => 'Kayıt Ol';

  @override
  String get googleLogin => 'Google ile Giriş';

  @override
  String get appleOnAndroidLink => 'Apple ile mi kaydoldun?';

  @override
  String get appleOnAndroidTitle =>
      'Apple ile açılan hesaba Android\'den giriş';

  @override
  String get appleOnAndroidBody =>
      'Android\'de Apple ile giriş yok; hesabına e-posta ve şifreyle girebilirsin:\n\n1. Hesabının e-posta adresini bul. Apple\'da \"E-postamı Gizle\"yi seçtiysen bu bir gizli röle adresidir (…@privaterelay.appleid.com); iPhone\'da Ayarlar > Apple Hesabı (adın) > Apple ile Giriş > PomoSprint altında görünür.\n2. Bu ekranda o adresi yazıp \"Şifremi Unuttum\"a dokun ve gelen bağlantıyla bir şifre belirle.\n3. Sonra aynı adres ve yeni şifrenle giriş yap.\n\nE-posta gelmezse destek@pomosprint.app adresine yaz.';

  @override
  String get resendVerificationLink => 'Doğrulama E-postasını Tekrar Gönder 📬';

  @override
  String loginVerificationPendingInfo(String email) {
    return 'Onay bağlantısını $email adresine gönderdik. Bağlantıya dokunduktan sonra şifrenle buradan giriş yap.';
  }

  @override
  String get loginResendPrompt => 'E-posta gelmedi mi? Yeniden gönder';

  @override
  String get errEnterEmailForResend =>
      'Onay e-postasını yeniden göndermek için önce e-posta adresini yaz.';

  @override
  String get errFillFields => 'Lütfen tüm alanları doldurun.';

  @override
  String get errInvalidCredentials => 'E-posta adresi veya şifre hatalı!';

  @override
  String get verificationResentMsg =>
      '📬 Doğrulama bağlantısı tekrar gönderildi. Lütfen e-postanızı kontrol edin.';

  @override
  String get passwordResetMsg =>
      'E-posta adresine bir şifre sıfırlama bağlantısı gönderdik. Gelen kutunu (ve spam klasörünü) kontrol et.';

  @override
  String get errEnterEmailForReset =>
      'Şifreni sıfırlamak için önce e-posta adresini gir.';

  @override
  String get createAccountTitle => 'Yeni Hesap Oluştur';

  @override
  String get createAccountSub => 'PomoSprint\'e katıl ve odaklanmaya başla.';

  @override
  String get orDivider => 'VEYA';

  @override
  String get fullName => 'İsim Soyisim';

  @override
  String get fullNameHint => 'Örn: Ayşe Yılmaz';

  @override
  String get termsAgree =>
      'Kullanım Koşullarını ve Gizlilik Politikasını okudum, onaylıyorum.';

  @override
  String get termsAgreePrefix => '';

  @override
  String get termsLinkTerms => 'Kullanım Şartları\'nı';

  @override
  String get termsAgreeConnector => ' ve ';

  @override
  String get termsLinkPrivacy => 'Gizlilik Politikası\'nı';

  @override
  String get termsAgreeSuffix => ' okudum, onaylıyorum.';

  @override
  String get privacyPolicyLink => 'Gizlilik Politikası';

  @override
  String get termsOfServiceLink => 'Kullanım Şartları';

  @override
  String get updatesAgree =>
      'Yeni özelliklerden ve güncellemelerden haberdar olmak istiyorum.';

  @override
  String get registerBtn => 'Kayıt Ol';

  @override
  String get alreadyHaveAccount => 'Zaten hesabın var mı? ';

  @override
  String get verificationSentTitle => 'Doğrulama E-postası Gönderildi! 📬';

  @override
  String verificationSentDesc(Object email) {
    return '$email adresine bir onay bağlantısı gönderdik.\n\nLütfen e-posta kutunuzu açıp doğrulama linkine tıkla. Onayladıktan sonra hemen giriş yapabilirsin!';
  }

  @override
  String get backToLoginBtn => 'Anladım, Giriş Yap\'a Dön';

  @override
  String get errFillEmailPassword => 'Lütfen e-posta ve şifrenizi girin.';

  @override
  String get errShortPassword => 'Şifre en az 6 karakter olmalıdır.';

  @override
  String get errAcceptTerms =>
      'Devam etmek için Kullanım Şartları\'nı kabul etmelisin.';

  @override
  String get errEmailExists =>
      'Bu e-posta adresi zaten kayıtlı. \"Giriş Yap\" ekranından giriş yap. Bu adresle Google ya da Apple ile kaydolduysan o butonu kullan ya da \"Şifremi Unuttum\" ile bir şifre belirle.';

  @override
  String get reportsTabSubject => 'Ders Raporları';

  @override
  String get reportsTabHistory => 'Çalışma Geçmişi';

  @override
  String get totalFocusTime => 'Toplam Çalışma';

  @override
  String get subjectBreakdown => 'Ders Odaklanma Dağılımı';

  @override
  String get noDataTitle => 'Henüz detaylı raporun yok, çalışmaya başla! 🚀';

  @override
  String get noDataDesc =>
      'Zamanlayıcıyı başlatıp ilk Pomodoro seansını tamamladığında ders dağılımın ve raporların burada görünecek.';

  @override
  String get startStudyingBtn => 'Hemen Çalışmaya Başla';

  @override
  String get minutesUnit => 'dk';

  @override
  String get hoursUnit => 's';

  @override
  String get completedSessions => 'Tamamlanan Seanslar';

  @override
  String sessionsCount(Object count) {
    return '$count Seans';
  }

  @override
  String get weekly => 'Haftalık';

  @override
  String get allTime => 'Tüm Zamanlar';

  @override
  String get noUsersInRanking =>
      'Henüz sıralamada kayıtlı kullanıcı bulunmuyor.';

  @override
  String minutesStudy(Object minutes) {
    return '$minutes dk çalışma';
  }

  @override
  String get userDefault => 'Kullanıcı';

  @override
  String get youBadge => '(Sen)';

  @override
  String get virtualLibrary => 'Sanal Kütüphane & Masalar';

  @override
  String studentsStudying(Object count) {
    return '$count Öğrenci Masalarda Çalışıyor';
  }

  @override
  String get emptyTables => 'Masalar Boş - İlk Oturan Sen Ol!';

  @override
  String get leaveTable => 'Masadan Kalk';

  @override
  String get joinTable => 'Katıl';

  @override
  String get tableFull => 'Masa Dolu';

  @override
  String get silentRoom => 'Sadece Sessiz';

  @override
  String get chatPlaceholder => 'Mesajınızı yazın...';

  @override
  String get addCategoryTitle => 'Yeni Kategori Ekle';

  @override
  String get addCategorySub =>
      'Çalışmalarını düzenlemek için yeni bir ders veya konu oluştur.';

  @override
  String get categoryNameHint => 'Kategori Adı (Örn: Tarih)';

  @override
  String get chooseColor => 'Renk Seçimi';

  @override
  String addedToast(Object name) {
    return '$name eklendi!';
  }

  @override
  String get deleteBtn => 'Sil';

  @override
  String get profileTitle => 'Profil ve Ayarlar';

  @override
  String get editProfile => 'PROFİL BİLGİLERİ';

  @override
  String get nameSurname => 'İsim Soyisim';

  @override
  String get email => 'E-posta Adresi';

  @override
  String get emailReadonlyHint =>
      'E-posta adresi güvenlik nedeniyle değiştirilemez.';

  @override
  String get appLanguage => 'UYGULAMA DİLİ';

  @override
  String get langTr => 'Türkçe 🇹🇷';

  @override
  String get langEn => 'English 🇬🇧';

  @override
  String get changeAvatar => 'Avatarı Değiştir';

  @override
  String get totalPoints => 'Kazanılan Puan';

  @override
  String get streakDays => 'Günlük Seri';

  @override
  String get deleteAccount => 'Hesabımı Sil';

  @override
  String get logout => 'Çıkış Yap';

  @override
  String get logoutConfirmTitle => 'Çıkış yapılsın mı?';

  @override
  String get logoutConfirmBody =>
      'Bu cihazdaki oturumun kapanacak. İstediğin zaman aynı hesapla yeniden giriş yapabilirsin.';

  @override
  String logoutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seansın henüz sunucuya gönderilmedi.',
      one: '1 seansın henüz sunucuya gönderilmedi.',
    );
    return '$_temp0 Seans başladıktan sonraki 24 saat içinde aynı hesapla bu cihazdan giriş yapmazsan puanı, kum taneleri ve seriye katkısı kaybolur.';
  }

  @override
  String get logoutRunningWarning =>
      'Süren bir seansın var. Seans bu cihazda saklanır ve aynı hesapla yeniden girince kaldığı yerden sürer; ama çıkış yaptıktan sonra bitiş bildirimi gelmez.';

  @override
  String get logoutSendAndExit => 'Gönder ve çık';

  @override
  String get logoutAnyway => 'Yine de çık';

  @override
  String get logoutSendFailed =>
      'Seanslar şu an gönderilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get darkMode => 'Karanlık Mod';

  @override
  String get preferences => 'TERCİHLER';

  @override
  String get nameUpdatedSuccess => 'Profil adınız başarıyla güncellendi!';

  @override
  String get pointsCaption => 'PUAN';

  @override
  String get pauseUsedSnackbar =>
      '1/1 Duraklatma hakkını kullandın! Tekrar durduramazsın.';

  @override
  String get pauseLimitTitle => 'Duraklatma Hakkın Bitti!';

  @override
  String get pauseLimitContent =>
      'Bu seans boyunca 1 defalık duraklatma hakkını zaten kullandın.\n\nŞimdi durdurursan seans ilerlemen tamamen sıfırlanacak.';

  @override
  String get resetAndStop => 'Sıfırla & Durdur';

  @override
  String get continueBtn => 'Devam Et';

  @override
  String get sessionReset => 'Seans ilerlemen sıfırlandı.';

  @override
  String get dailyGoalLabel => 'Günlük Hedef';

  @override
  String get setDailyGoalTitle => 'Günlük Hedef Belirle';

  @override
  String get setDailyGoalSub => 'Bugün kaç Pomodoro tamamlamak istiyorsun?';

  @override
  String get saveGoalBtn => 'Hedefi Kaydet';

  @override
  String get efficiencyScoreCaption => 'VERİMLİLİK SKORU';

  @override
  String get efficiencyMsgExceeded => 'Hedefini aştın, harikasın! 🔥';

  @override
  String get efficiencyMsgClose => 'Hedefe yaklaşıyorsun!';

  @override
  String get efficiencyMsgLow => 'Bugün biraz daha çalışabilirsin';

  @override
  String get todayStudiesHeader => 'Bugünkü Çalışmalar';

  @override
  String get detailsLink => 'Detaylar';

  @override
  String get weeklyDistTitle => 'Haftalık Dağılım';

  @override
  String get weeklyDistSub => 'Son 7 günün özeti';

  @override
  String get hourToggle => 'Saat';

  @override
  String get totalLabel => 'Toplam';

  @override
  String get efficiencyTipHeader => 'Verimlilik İpucu';

  @override
  String get hourAbbr => 'sa';

  @override
  String get minAbbr => 'dk';

  @override
  String get tip1 =>
      'Sabah saatlerinde matematik çalışmak odaklanma kapasiteni %15 artırıyor.';

  @override
  String get tip2 =>
      'Her 25 dakikalık odaklanma seansından sonra 5 dakika mola ver.';

  @override
  String get tip3 =>
      'Günde 4 pomodoro tamamlamak düzenli çalışma alışkanlığı oluşturur.';

  @override
  String get tip4 =>
      'Zorlu konuları sabah saatlerinde çalışmak verimliliği artırır.';

  @override
  String get addBtn => 'Ekle';

  @override
  String get onboardingSelectOptionError => 'Lütfen bir seçenek seçin.';

  @override
  String get onboardingTimeoutError =>
      'Bağlantı zaman aşımına uğradı. Lütfen internetini kontrol edip tekrar dene.';

  @override
  String onboardingGenericError(Object error) {
    return 'Bir şeyler ters gitti, lütfen tekrar dene: $error';
  }

  @override
  String get onboardingAddCategoryTitle => 'Kategori Ekle';

  @override
  String get onboardingCategoryHint => 'Kategori adı';

  @override
  String get onboardingMaxCategoriesMsg => 'En fazla 8 kategori seçebilirsin.';

  @override
  String get onboardingWelcomeTitle => 'Hoş geldin! 👋';

  @override
  String get onboardingWelcomeBody =>
      'Ben senin odaklanma arkadaşınım. Sana eşlik etmeden önce doğum yılını öğrenebilir miyim?';

  @override
  String get onboardingSegmentTitle => 'Peki, hangi yolculuktasın?';

  @override
  String get onboardingSegmentBody =>
      'Beraber neye çalışacağız? Sana en uygun kategorileri seçeyim.';

  @override
  String get onboardingSegmentLgs => '🎓  LGS';

  @override
  String get onboardingSegmentYks => '📚  YKS';

  @override
  String get onboardingSegmentUniversity => '🏛️  Üniversite';

  @override
  String get onboardingSegmentWork => '💼  İş & Kişisel Gelişim';

  @override
  String get onboardingCategoryStepTitle => 'Harika seçim! 🎉';

  @override
  String get onboardingCategoryStepBody =>
      'Şimdi çalışacağın dersleri/alanları seç — istediğin zaman değiştirebilirsin. Ücretsiz planda en fazla 8 tane olur.';

  @override
  String get onboardingCreateOwnCategory => '+ Kendi kategorimi oluştur';

  @override
  String get onboardingGoalStepTitle => 'Son bir adım kaldı! 🚀';

  @override
  String get onboardingGoalStepBody =>
      'Günde ne kadar birlikte odaklanmak istersin?';

  @override
  String get onboardingGoal1h => '1 Saat';

  @override
  String get onboardingGoal2h => '2 Saat';

  @override
  String get onboardingGoal3h => '3 Saat';

  @override
  String get onboardingGoal4hPlus => '4 Saat+';

  @override
  String get onboardingFinishBtn => 'Bitir';

  @override
  String get categoriesManagementTitle => 'Kategorilerim';

  @override
  String categoryLimitReachedMsg(int limit) {
    return 'Limitinize ulaştınız. En fazla $limit kategori ekleyebilirsiniz.';
  }

  @override
  String get newCategoryDialogTitle => 'Yeni Kategori';

  @override
  String get editCategoryDialogTitle => 'Kategori Düzenle';

  @override
  String get activeCategoryCountLabel => 'Aktif Kategori Sayısı';

  @override
  String get archiveCategoryTooltip =>
      'Arşivle (Silmek yerine geçmiş raporlar için saklanır)';

  @override
  String get archivedCategoriesHeader => 'Arşivlenmiş Kategoriler';

  @override
  String get archivedCategoriesDesc =>
      'Bu kategoriler ders seçicide görünmez ama geçmiş raporlarda yer alır.';

  @override
  String get unarchiveTooltip => 'Arşivi Aç';

  @override
  String get categoryLastActiveRequired =>
      'En az bir aktif kategorin olmalı. Önce yeni bir kategori ekle ya da arşivden birini çıkar.';

  @override
  String get timerResetBtn => 'Sıfırla';

  @override
  String get timerResetConfirmTitle => 'Seans sıfırlansın mı?';

  @override
  String get timerResetConfirmBody =>
      'Bu seans kaydedilmeden silinecek; puan ve kum kazanmayacaksın. Bu işlem geri alınamaz.';

  @override
  String get timerResetConfirmAction => 'Sıfırla';

  @override
  String get timerDurationLocked =>
      'Süreyi değiştirmek için önce seansı sıfırla.';

  @override
  String get rankingZonePromotionChip => '↑ Terfi';

  @override
  String get rankingZoneDemotionChip => '↓ Düşme';

  @override
  String get rankingZonePromotionMe =>
      'Terfi bölgesindesin: dönem böyle biterse bir üst lige çıkarsın.';

  @override
  String get rankingZoneNeedsPointsMe =>
      'Terfi bölgesindesin ama 0 puanla terfi edilmez. Bir seans tamamla.';

  @override
  String get rankingZoneDemotionMe =>
      'Düşme bölgesindesin: dönem böyle biterse bir alt lige inersin.';

  @override
  String get authSocialNoticePrefix => 'Devam ederek ';

  @override
  String get authSocialNoticeTermsLink => 'Kullanım Şartları\'nı';

  @override
  String get authSocialNoticeMiddle => ' kabul etmiş ve ';

  @override
  String get authSocialNoticeKvkkLink => 'KVKK Aydınlatma Metni\'ni';

  @override
  String get authSocialNoticeSuffix => ' okumuş olursun.';

  @override
  String legalOpenFailed(String url) {
    return 'Sayfa açılamadı. Tarayıcında şu adresi açabilirsin: $url';
  }

  @override
  String get registerNameLabel => 'Görünen ad';

  @override
  String get registerNameHelper =>
      'Sıralamada ve arkadaş listelerinde bu ad görünür.';

  @override
  String get registerErrNameRequired => 'Görünen adını gir.';

  @override
  String get registerErrNameTooLong => 'Ad en fazla 50 karakter olabilir.';

  @override
  String get nameNotAllowed => 'Bu ad uygun değil. Lütfen başka bir ad seç.';

  @override
  String get registerErrEmailRequired => 'E-posta adresini gir.';

  @override
  String get registerErrPasswordRequired => 'Bir şifre belirle.';

  @override
  String get registerPasswordHelper =>
      'En az 6 karakter; büyük harf, küçük harf ve rakam içermeli.';

  @override
  String get passwordRuleLength => 'En az 6 karakter';

  @override
  String get passwordRuleCase => 'Büyük ve küçük harf (A-Z, a-z)';

  @override
  String get passwordRuleDigit => 'En az bir rakam (0-9)';

  @override
  String get changePasswordTile => 'Şifreyi değiştir';

  @override
  String get changePasswordTileSub =>
      'Mevcut şifrenle doğrulayıp yeni bir şifre belirle.';

  @override
  String get changePasswordCurrent => 'Mevcut şifre';

  @override
  String get changePasswordNew => 'Yeni şifre';

  @override
  String get changePasswordRepeat => 'Yeni şifre (tekrar)';

  @override
  String get changePasswordMismatch => 'Yeni şifreler aynı değil.';

  @override
  String get changePasswordSame => 'Yeni şifre mevcut şifrenle aynı olamaz.';

  @override
  String get changePasswordWrongCurrent => 'Mevcut şifre hatalı.';

  @override
  String get changePasswordSave => 'Şifreyi güncelle';

  @override
  String get changePasswordSuccess =>
      'Şifren güncellendi. Diğer cihazlardaki oturumların kapanmış olabilir.';

  @override
  String get registerShowPassword => 'Şifreyi göster';

  @override
  String get registerHidePassword => 'Şifreyi gizle';

  @override
  String get registerConsentsTitle => 'Onaylar';

  @override
  String get registerConsentRequiredTag => 'Zorunlu';

  @override
  String get registerConsentOptionalTag => 'İsteğe bağlı';

  @override
  String get registerConsentTermsPrefix => '';

  @override
  String get registerConsentTermsLink => 'Kullanım Şartları\'nı';

  @override
  String get registerConsentTermsSuffix => ' okudum ve kabul ediyorum.';

  @override
  String get registerConsentPrivacyPrefix => '';

  @override
  String get registerConsentKvkkLink => 'KVKK Aydınlatma Metni\'ni';

  @override
  String get registerConsentPrivacyConnector => ' ve ';

  @override
  String get registerConsentPrivacyLink => 'Gizlilik Politikası\'nı';

  @override
  String get registerConsentPrivacySuffix => ' okudum.';

  @override
  String get registerConsentMarketing =>
      'Yeni özellikler ve güncellemeler hakkında bana e-posta gönderilmesini kabul ediyorum (ticari elektronik ileti onayı).';

  @override
  String get registerConsentMarketingHint =>
      'İstediğin zaman e-postalardaki bağlantıyla abonelikten çıkabilirsin.';

  @override
  String get errAcknowledgePrivacy =>
      'Devam etmek için KVKK Aydınlatma Metni\'ni ve Gizlilik Politikası\'nı okuduğunu onaylamalısın.';

  @override
  String get profileLegalSectionTitle => 'Gizlilik ve yasal';

  @override
  String get kvkkNoticeLink => 'KVKK Aydınlatma Metni';

  @override
  String get accountDeletionInfoLink => 'Hesap silme hakkında';

  @override
  String get accountDeletionInfoSub =>
      'Hangi verilerin silindiği ve web üzerinden silme talebi';

  @override
  String get dataCopyRequestTile => 'Verilerimin kopyasını iste';

  @override
  String get dataCopyRequestSub =>
      'KVKK m.11 kapsamında. E-posta uygulaman açılır; hesabındaki e-posta adresinden gönder.';

  @override
  String get dataCopyEmailSubject =>
      'PomoSprint kişisel veri kopyası talebi (KVKK m.11)';

  @override
  String get dataCopyEmailBody =>
      'Merhaba,\n\nKVKK m.11 kapsamında PomoSprint hesabıma ait kişisel verilerin bir kopyasını talep ediyorum. Bu e-postayı hesabımda kayıtlı e-posta adresinden gönderiyorum.\n\nTercih ettiğim biçim (ör. JSON, PDF):\n';

  @override
  String dataCopyMailFailed(String email) {
    return 'E-posta uygulaması açılamadı. Talebini hesabındaki e-posta adresinden $email adresine gönderebilirsin.';
  }

  @override
  String get deleteAccountSub =>
      'Hesabını ve tüm verilerini kalıcı olarak siler.';

  @override
  String get hiddenUsersTitle => 'Gizlenen kullanıcıları göster';

  @override
  String hiddenUsersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kullanıcı gizli · dokununca liste sıfırlanır',
      zero: 'Gizlenen kullanıcı yok',
    );
    return '$_temp0';
  }

  @override
  String get hiddenUsersCleared => 'Gizlenen kullanıcılar yeniden görünecek.';

  @override
  String get userActionsTooltip => 'Kullanıcı seçenekleri';

  @override
  String get reportUserAction => 'Kullanıcıyı bildir';

  @override
  String get reportUserActionSub =>
      'Uygunsuz bir adı ya da davranışı destek ekibine e-postayla bildir.';

  @override
  String get hideUserAction => 'Bu kullanıcıyı gizle';

  @override
  String get hideUserActionSub =>
      'Sıralamada adı gizlenir, canlı akışta görünmez. Profil\'den geri alabilirsin.';

  @override
  String userHiddenMsg(String name) {
    return '$name gizlendi.';
  }

  @override
  String get undoAction => 'Geri al';

  @override
  String get hiddenUserLabel => 'Gizlenen kullanıcı';

  @override
  String reportEmailSubject(String name) {
    return 'PomoSprint kullanıcı bildirimi: $name';
  }

  @override
  String reportEmailBody(String name, String userId, String place) {
    return 'Bildirilen görünen ad: $name\nKullanıcı kimliği: $userId\nGörüldüğü yer: $place\n\nNeyi bildiriyorsun? Lütfen kısaca açıkla:\n';
  }

  @override
  String get reportUserIdUnknown =>
      'bilinmiyor (sıralamada kimlik gösterilmez)';

  @override
  String get reportPlaceLeague => 'Sıralama · Lig';

  @override
  String get reportPlaceMonthly => 'Sıralama · Aylık';

  @override
  String get reportPlaceFriendsRanking => 'Sıralama · Arkadaşlar';

  @override
  String get reportPlaceLiveFeed => 'Sosyal · Şu an odaklananlar';

  @override
  String get reportPlaceFriendsList => 'Arkadaş listesi';

  @override
  String get reportPlaceFriendRequest => 'Arkadaşlık isteği';

  @override
  String reportMailFailed(String email) {
    return 'E-posta uygulaması açılamadı. Bildirimini $email adresine gönderebilirsin.';
  }

  @override
  String get reportCopyAddress => 'Adresi kopyala';
}
