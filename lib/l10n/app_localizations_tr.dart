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
  String onboardingCategoryStepPreparedBody(int limit) {
    return 'Derslerin/alanların seçili geldi; istersen değiştir. Dokunarak çıkarabilir ya da yenisini ekleyebilirsin. En fazla $limit tane seçebilirsin.';
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
      'Şu an odaklanan veya molada olan arkadaşın yok. Çalışmaya başladıklarında burada görünecekler.';

  @override
  String get socialLoadError =>
      'Arkadaşlarının durumu yüklenemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get leagueTierBronze => 'Bronz Lig';

  @override
  String get leagueTierSilver => 'Gümüş Lig';

  @override
  String get leagueTierGold => 'Altın Lig';

  @override
  String get leagueTierSapphire => 'Safir Lig';

  @override
  String get leagueTierDiamond => 'Elmas Lig';

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
      'İlk puanlı seansından sonra benzer seviyedeki kullanıcılarla bir lig odasına yerleşirsin. Oda kapasitesi ve dönem kuralları sunucudan okunur; puan topladıkça sıralamada ilerlersin.';

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
      'İlk puanlı pomodoronu tamamladığında seninle aynı kademedeki uygun bir lig odasına yerleşirsin. Sıralaman ve güncel dönem kuralları burada görünür.';

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
  String profileDeleteConfirmCopyHint(String email) {
    return 'Verilerinin bir kopyasını istiyorsan silmeden önce hesabındaki e-posta adresinden $email adresine yaz.';
  }

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
  String get specialAvatarsTitle => 'Özel Avatarlar';

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
  String get sessionResultSaving => 'Seans kaydediliyor…';

  @override
  String sessionResultPoints(int points) {
    return '+$points puan';
  }

  @override
  String sessionResultCoins(int coins) {
    return '+$coins kum';
  }

  @override
  String sessionResultStreak(int days) {
    return '$days günlük seri';
  }

  @override
  String get sessionResultDuplicate => 'Bu seans daha önce kaydedilmişti.';

  @override
  String get sessionStartUnverified =>
      'Sunucu başlangıcı doğrulayamadı. Seansın kaydedilir; puan ve kum kazanımı sunucu kurallarına bağlıdır.';

  @override
  String get sessionUnverifiedNoRewards =>
      'Sunucu başlangıcı doğrulayamadığı için seansın kaydedildi; bu seanstan puan ve kum kazanılmadı.';

  @override
  String get sessionResultTestNotSaved => 'Test seansı — kaydedilmez';

  @override
  String get sessionResultOk => 'Tamam';

  @override
  String get sessionNotSavedTitle => 'Seans kaydedilemedi';

  @override
  String get sessionQueuedOffline =>
      'Seans cihazına kaydedildi; bağlantı gelince otomatik gönderilecek. Puan ve kum için 24 saat içinde çevrimiçi olman gerekiyor.';

  @override
  String get sessionQueuedClockSkew =>
      'Seans bekletiliyor: cihazının saati sunucudan farklı görünüyor. Saat ayarını kontrol et; seans otomatik olarak yeniden denenecek.';

  @override
  String get sessionQueuedTimingUnverified =>
      'Seans bekletiliyor: seans süresi sunucuyla henüz doğrulanamadı. Otomatik olarak yeniden denenecek.';

  @override
  String get sessionQueuedOverlap =>
      'Seans önceki bir kayıtla çakışıyor; bekletiliyor ve daha sonra yeniden denenecek.';

  @override
  String get sessionRejectedTooOld =>
      'Bu seans 24 saatten eski olduğu için kaydedilemedi.';

  @override
  String get sessionRejectedClock =>
      'Bu seans kaydedilemedi: cihazının saati ileri görünüyor. Saat ayarını kontrol et.';

  @override
  String get sessionRejectedNotElapsed =>
      'Bu seans kaydedilemedi: sunucuya göre seans süresi henüz dolmamıştı.';

  @override
  String get sessionRejectedFutureStart =>
      'Bu seans kaydedilemedi: başlangıç zamanı sunucu saatiyle doğrulanamadı.';

  @override
  String get sessionRejectedOverlap =>
      'Bu seans kaydedilemedi: aynı zaman aralığında kayıtlı başka bir seans var.';

  @override
  String get sessionRejectedGeneric =>
      'Bu seans kaydedilemedi: sunucu doğrulamasından geçmedi.';

  @override
  String rejectedSessionsNotice(int count) {
    return '⚠️ Bekleyen $count seans sunucu tarafından reddedildi ve kaydedilemedi.';
  }

  @override
  String get rejectedSessionsTitle => 'Kaydedilemeyen seanslar';

  @override
  String get rejectedSessionsInfo =>
      'Sunucunun kabul etmediği seanslar burada listelenir; puana, kuma ve seriye eklenmezler. Bu cihazda son 50 kayıt tutulur.';

  @override
  String get rejectedSessionsEmpty => 'Kaydedilemeyen seans yok.';

  @override
  String rejectedSessionsLink(int count) {
    return 'Kaydedilemeyen seanslar ($count)';
  }

  @override
  String get rejectedSessionsView => 'Göster';

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
    return '$category seansın bitti. Puan ve kum kazanman için 24 saat içinde uygulamayı aç.';
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
  String get lockTimerDoneHint =>
      'Seansını kaydetmek için 24 saat içinde PomoSprint\'i aç.';

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
    return 'Bugünkü 25 dakikalık odak eşdeğeri: $count';
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
      'Bu ay bir Pomodoro veya deneme tamamladığında aylık takip burada görünecek.';

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
  String get googleLogin => 'Google ile Giriş Yap';

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
  String get errShortPassword => 'Şifre en az 8 karakter olmalıdır.';

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
      'Bir Pomodoro veya deneme tamamladığında raporların burada görünecek.';

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
  String get onboardingWelcomeTitle => 'PomoSprint’e hoş geldin';

  @override
  String get onboardingWelcomeBody =>
      'Odaklan, çalışmalarını takip et ve hedefindeki arkadaşlarınla birlikte ilerle. Önce uygulamayı sana göre hazırlayalım.';

  @override
  String get onboardingSegmentTitle => 'Peki, hangi yolculuktasın?';

  @override
  String get onboardingSegmentBody =>
      'Beraber neye çalışacağız? Sana uygun kategorileri önereyim. Uymuyorsa \"Diğer\"i seç.';

  @override
  String get onboardingSegmentLgs => '🎓  LGS';

  @override
  String get onboardingSegmentYks => '📚  YKS';

  @override
  String get onboardingSegmentKpss => '📝  KPSS';

  @override
  String get onboardingSegmentLanguage =>
      '🌍  Dil sınavı (YDS, YÖKDİL, IELTS, TOEFL)';

  @override
  String get onboardingSegmentUniversity => '🏛️  Üniversite';

  @override
  String get onboardingSegmentWork => '💼  İş & Kişisel Gelişim';

  @override
  String get onboardingCategoryStepTitle => 'Harika seçim! 🎉';

  @override
  String get onboardingCategoryStepPreparedTitle =>
      'Hedefine göre hazırladık 🎯';

  @override
  String get onboardingCreateOwnCategory => '+ Kendi kategorimi oluştur';

  @override
  String get onboardingGoalStepTitle => 'Günlük hedefini seç';

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
  String get timerQuickTestBadge => 'TEST';

  @override
  String get timerQuickTestSemantics =>
      'Hızlı test sayacı: seanslar kaydedilmez';

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
      'En az 8 karakter; büyük harf, küçük harf ve rakam içermeli.';

  @override
  String get passwordRuleLength => 'En az 8 karakter';

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
      'Uygunsuz bir adı, içeriği ya da davranışı uygulama içinden bildir.';

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

  @override
  String get onboardingBirthYearRequired =>
      'Devam etmek için doğum yılını seç.';

  @override
  String get onboardingBirthYearPlaceholder => 'Doğum yılını seç';

  @override
  String get profileNotificationsLabelSub =>
      'Seans bitiş bildirimi ve kilit ekranı sayacı';

  @override
  String get profileNotificationsBlockedSub =>
      'Bildirim izni kapalı. Seans bitiş bildirimi ve kilit ekranı sayacı için telefonunun ayarlarından izin ver.';

  @override
  String get profileOpenSettings => 'Ayarları aç';

  @override
  String get profileSocialVisibilityTitle =>
      'Sıralamalarda ve canlı listede görün';

  @override
  String get profileSocialVisibilitySub =>
      'Açıkken adın ve avatarın aylık sıralamada, pomosprint.app\'teki herkese açık listede (kısaltılmış adla) ve çalışırken arkadaşlarının canlı listesinde görünür. Lig grubun ve arkadaşların seni her durumda görür.';

  @override
  String get gameRulesTitle => 'Nasıl çalışır?';

  @override
  String get gameRulesProfileSub => 'Duraklatma, günlük sınır, puan ve kum';

  @override
  String gameRulesSessions(String pct) {
    return 'Seanslar 25 ya da 50 dakika sürer. Her seansta tek duraklatma hakkın var; duraklatırsan puanın %$pct azalır. İkinci kez durdurursan seans sıfırlanır.';
  }

  @override
  String gameRulesPoints(
    String points25,
    String points50,
    String coins,
    String limit,
  ) {
    return 'Tamamladığın her seans puan (25 dk: $points25, 50 dk: $points50) ve $coins kum tanesi kazandırır. Günde en fazla $limit seans sayılır; sonrakiler yalnızca çalışma süresine ve serine eklenir.';
  }

  @override
  String get gameRulesLeague =>
      'Puanınla ligde yükselirsin, her gün çalışarak seri bonusu kazanırsın. Kum taneleriyle koleksiyondan yeni kum saatleri açarsın.';

  @override
  String get profileHelpSectionTitle => 'Yardım';

  @override
  String get profileSupportTitle => 'Destek ve geri bildirim';

  @override
  String get profileSupportSub =>
      'Bir sorunu ya da önerini e-postayla bize yaz';

  @override
  String profileAppVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get supportEmailSubject => 'PomoSprint destek ve geri bildirim';

  @override
  String supportEmailBody(String version, String device) {
    return 'Mesajın:\n\n\n---\nUygulama sürümü: $version\nCihaz: $device';
  }

  @override
  String supportMailFailed(String email) {
    return 'E-posta uygulaması açılamadı. Bize $email adresinden yazabilirsin.';
  }

  @override
  String get selectCategory => 'KATEGORİ SEÇ';

  @override
  String get sessionCompletedTitle => 'Tebrikler! 🎉';

  @override
  String sessionCompletedBody(int minutes) {
    return '$minutes dakikalık odaklanma seansını\nbaşarıyla tamamladın! ⏳';
  }

  @override
  String get sessionCompletedOk => 'Harika!';

  @override
  String get timerGetReady => 'Hazırlan! Odaklanıyorsun...';

  @override
  String get languagePickerLabel => 'Uygulama dili';

  @override
  String get onboardingSegmentOther => '✨  Diğer / belirtmek istemiyorum';

  @override
  String get onboardingVisibilityTitle => 'Sıralamalarda görünmek ister misin?';

  @override
  String get onboardingVisibilityBody =>
      'Açarsan adın ve avatarın aylık sıralamada, pomosprint.app\'teki herkese açık listede (adın kısaltılarak) ve çalışırken arkadaşlarının canlı listesinde görünür. Kapalıyken bu yerlerde görünmezsin. Lig grubundakiler ve arkadaşların seni her durumda görür. Bu tercihi istediğin zaman Profil\'den değiştirebilirsin.';

  @override
  String get onboardingVisibilityYes => 'Evet, sıralamalarda görüneyim';

  @override
  String get onboardingVisibilityNo => 'Hayır, görünmeyeyim';

  @override
  String get onboardingRulesBody =>
      'Başlamadan önce bilmen gereken birkaç kural:';

  @override
  String timerDurationOption(int minutes) {
    return '$minutes dakikalık seans';
  }

  @override
  String get timerEditCategories => 'Kategorileri düzenle';

  @override
  String timerRemainingSemantics(int minutes, int seconds) {
    return '$minutes dakika $seconds saniye kaldı';
  }

  @override
  String get timerNotificationsDenied =>
      'Bildirim izni yok: seans bitince haber veremeyiz ve kilit ekranında sayaç görünmez.';

  @override
  String onboardingCategoriesSkippedLimit(int count, int limit) {
    return 'Kategori sınırına ($limit) ulaşıldığı için seçtiğin $count kategori eklenmedi. Kategorilerim\'den düzenleyebilirsin.';
  }

  @override
  String get categoryColorInvalidMsg =>
      'Bu renk kullanılamıyor. Listeden bir renk seç.';

  @override
  String get categoryIconInvalidMsg =>
      'Bu kategori simgesi kullanılamıyor. Lütfen tekrar dene.';

  @override
  String leagueInfoPromoteMinPoints(int count, int points) {
    return 'Bu dönem en az $points puan toplayan ilk $count kişi bir üst lige yükselir.';
  }

  @override
  String get leagueAloneInRoomTitle => 'Odanda şimdilik yalnızsın';

  @override
  String get leagueAloneInRoomBody =>
      'Bu lig odasında şu an yalnızca sen varsın. Odaya katılanlar burada görünür; pomodoro tamamladıkça puan toplarsın.';

  @override
  String get friendsErrInvalidCode =>
      'Arkadaş kodu 6–8 harf ve rakamdan oluşur. Kodu kontrol et.';

  @override
  String get friendsErrRateLimited =>
      'Çok fazla deneme yaptın. Lütfen bir süre sonra tekrar dene.';

  @override
  String get friendsErrCooldown =>
      'Bu kullanıcı isteğini yakın zamanda reddetti. Bir süre sonra tekrar deneyebilirsin.';

  @override
  String get friendsErrBlocked =>
      'Bu kullanıcıyı engellediğin için arkadaş olarak ekleyemezsin.';

  @override
  String leagueAwardsSubMinPoints(int points) {
    return 'Bir lig dönemini en az $points puanla ilk 3\'te bitirince kazanılır: 1.\'ye Şampiyonluk, 2. ve 3.\'ye Podyum Ödülü.';
  }

  @override
  String leagueAwardMinMembersNote(int members) {
    return 'Ödül yalnızca dönem sonunda en az $members kişi olan odalarda verilir.';
  }

  @override
  String leagueAwardLockedBodyMinPoints(int points) {
    return 'Bu avatarı kazanmak için bu kademede bir lig dönemini en az $points puanla ilk 3\'te bitirmen gerekiyor. Parayla satın alınamaz.';
  }

  @override
  String leagueAwardLockedBodyChampionMinPoints(int points) {
    return 'Bu Şampiyonluk Ödülü\'nü kazanmak için bu kademede bir lig dönemini en az $points puanla 1. sırada bitirmen gerekiyor. Parayla satın alınamaz.';
  }

  @override
  String leagueAwardLockedBodyPodiumMinPoints(int points) {
    return 'Bu Podyum Ödülü\'nü kazanmak için bu kademede bir lig dönemini en az $points puanla 2. veya 3. sırada bitirmen gerekiyor (1. olan Şampiyonluk Ödülü\'nü alır). Parayla satın alınamaz.';
  }

  @override
  String rankingZoneNeedsMinPointsMe(int points) {
    return 'Terfi bölgesindesin ama terfi için en az $points puan gerekiyor. Seans tamamlamaya devam et.';
  }

  @override
  String get forgotPasswordDescription =>
      'E-posta adresini gir. Şifreni yenilemen için bir doğrulama bağlantısı göndereceğiz.';

  @override
  String get sendPasswordResetEmail => 'Doğrulama maili gönder';

  @override
  String get passwordResetSentTitle => 'E-postanı kontrol et';

  @override
  String get passwordResetSentDescription =>
      'Bu adresle kayıtlı bir hesap varsa şifre sıfırlama bağlantısını gönderdik. Gelen kutunu ve spam klasörünü kontrol et; e-postadaki bağlantıdan yeni şifreni belirleyebilirsin.';

  @override
  String get passwordResetLocalTitle => 'Yerel e-posta';

  @override
  String get passwordResetLocalDescription =>
      'Bu sürüm yerel ortama bağlı. E-postalar gerçek gelen kutuna gönderilmez; yerel Mailpit kutusunda tutulur. Buradaki hesaplar ve şifreler normal hesabından ayrıdır. Normal hesabını sıfırlamak için PomoSprint normal çalıştırma seçeneğini kullan.';

  @override
  String get timerQuickRecordedSemantics =>
      'Yerel hızlı test sayacı: seanslar 25 veya 50 dakika olarak kaydedilir';

  @override
  String get friendsOutgoingTitle => 'Gönderilen istekler';

  @override
  String get friendsCancelRequest => 'İsteği iptal et';

  @override
  String get friendsRemoveAction => 'Arkadaşlıktan çıkar';

  @override
  String get friendsRemoveConfirm =>
      'Arkadaşlıktan çıkarmak istiyor musun? Yeniden arkadaş olmak için istek göndermen gerekir.';

  @override
  String get friendsCancelConfirm =>
      'Bu arkadaşlık isteğini iptal etmek istiyor musun?';

  @override
  String get blockedUsersTitle => 'Engellenen kullanıcılar';

  @override
  String get blockUserAction => 'Kullanıcıyı engelle';

  @override
  String get blockUserConfirm =>
      'Arkadaşlık ve aranızdaki istekler kaldırılır. Birbirinizi canlı akışta göremez, arkadaşlık isteği gönderemezsiniz.';

  @override
  String get unblockUserAction => 'Engeli kaldır';

  @override
  String get unblockUserConfirm =>
      'Engel kaldırılacak. Önceki arkadaşlığınız otomatik olarak geri gelmez.';

  @override
  String get friendActionCompleted => 'İşlem tamamlandı.';

  @override
  String get friendActionFailed =>
      'İşlem tamamlanamadı. Listeyi yenileyip tekrar dene.';

  @override
  String get friendActionConfirm => 'Onayla';

  @override
  String get friendActionCancel => 'Vazgeç';

  @override
  String get reportReasonLabel => 'Bildirme nedeni';

  @override
  String get reportChooseReason => 'Lütfen bir bildirme nedeni seç.';

  @override
  String get reportReasonOffensiveName => 'Uygunsuz ad';

  @override
  String get reportReasonOffensiveContent => 'Uygunsuz içerik';

  @override
  String get reportReasonHarassment => 'Taciz veya zorbalık';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonImpersonation => 'Başkasını taklit etme';

  @override
  String get reportReasonOther => 'Diğer';

  @override
  String get reportDetailsLabel => 'Açıklama (isteğe bağlı)';

  @override
  String get reportSendButton => 'Bildirimi gönder';

  @override
  String get reportSent => 'Bildirimin alındı. Destek ekibi inceleyecek.';

  @override
  String get reportAlreadyReceived =>
      'Bu kullanıcı hakkında bildirimin zaten alındı.';

  @override
  String get reportRateLimited =>
      'Bugünkü bildirim sınırına ulaştın. Daha sonra tekrar dene.';

  @override
  String get reportUserUnavailable =>
      'Bu kullanıcı artık bildirilemiyor. Listeyi yenile.';

  @override
  String get reportSendFailed => 'Bildirim gönderilemedi. Tekrar dene.';

  @override
  String get marathonTitle => 'Maraton';

  @override
  String get marathonSingle => 'Tek seans';

  @override
  String get marathonChooseCount => 'Kaç seans yapmak istiyorsunuz?';

  @override
  String marathonCountOption(int count) {
    return '$count Pomodoro';
  }

  @override
  String marathonProgress(int current, int total) {
    return '$current/$total Pomodoro';
  }

  @override
  String get marathonBreakTitle => 'Mola';

  @override
  String get marathonBreakHint =>
      'Mola bitince 1 dakika içinde “Buradayım” diyerek devam et.';

  @override
  String get marathonAutomaticHint =>
      'Maraton, art arda 2, 3 veya 4 Pomodoro yapmanı sağlayan bir çalışma planıdır. Planın için 25 ya da 50 dakika seçersin; maratondaki tüm Pomodorolar bu sürede olur.\n\nSeansların arasında 5 dakika mola verirsin. Mola bitince 1 dakika içinde “Buradayım”a dokunarak sıradaki seansı başlatırsın. Devam onayı için internet bağlantısı gerekir.\n\nOnay vermezsen veya maratonu erken bitirirsen kalan plan durur. Tamamladığın seanslar ve normal puanların korunur; tamamlama bonusu kazanılmaz. Mola ve onay bekleme süresi çalışma sürene eklenmez.';

  @override
  String marathonBreakRemainingSemantics(int minutes, int seconds) {
    return 'Mola: $minutes dakika $seconds saniye kaldı';
  }

  @override
  String get marathonStart => 'MARATONU BAŞLAT';

  @override
  String get marathonStop => 'Maratonu bitir';

  @override
  String get marathonStopped =>
      'Maraton bitirildi. Tamamladığın Pomodorolar ve normal puanların korundu.';

  @override
  String get marathonStopConfirmTitle => 'Maratonu bitirelim mi?';

  @override
  String marathonStopConfirmBody(int completed, int total) {
    return '$completed/$total Pomodoro tamamladın. Tamamladıkların korunur; devam eden Pomodoro kaydedilmez.';
  }

  @override
  String get marathonStopConfirmAction => 'Maratonu bitir';

  @override
  String get marathonCompletedTitle => 'Maraton tamamlandı!';

  @override
  String marathonCompletedBody(int count, int minutes) {
    return '$count Pomodoro ile $minutes dakika odaklandın.';
  }

  @override
  String get marathonSaving => 'Pomodoro kaydediliyor…';

  @override
  String get marathonRetrySave => 'Kaydı tekrar dene';

  @override
  String get marathonSaveFailed =>
      'Tamamlanan Pomodoro cihazında saklanıyor. Kaydı yeniden göndermek için tekrar dene. Devam süresi dolarsa maraton durur; tamamladığın kayıt korunur.';

  @override
  String get marathonStoppedRejected =>
      'Pomodoro kaydı kabul edilmedi. Maraton durduruldu; önceki kayıtların korundu.';

  @override
  String marathonMinutesSummary(int focusMinutes, int elapsedMinutes) {
    return '$focusMinutes dk çalışma · molalarla yaklaşık $elapsedMinutes dk';
  }

  @override
  String get marathonResumePlan => 'Maratona devam et';

  @override
  String get notifMarathonBreakDoneTitle => 'Mola bitti';

  @override
  String notifMarathonBreakDoneBody(int nextSession, int totalSessions) {
    return 'Maraton: $nextSession/$totalSessions Pomodoro. 1 dakika içinde uygulamayı açıp “Buradayım” diyerek devam et.';
  }

  @override
  String get socialOnBreak => 'Molada';

  @override
  String get socialNoBreakFriends => 'Şu an molada olan arkadaşın yok.';

  @override
  String marathonBonusPoints(int points) {
    return '+$points Maraton bonusu';
  }

  @override
  String marathonBonusHint(int points) {
    return 'Maratonu tamamlayınca +$points ek puan';
  }

  @override
  String get marathonBonusPending =>
      'Maraton bonusu, bekleyen Pomodorolar kaydedildiğinde ve tamamlama koşulları sağlandığında hesaplanacak.';

  @override
  String get marathonUnavailable => 'Maraton şu an kullanılamıyor.';

  @override
  String get marathonStartFailed =>
      'Maraton başlatılamadı. Lütfen tekrar dene.';

  @override
  String get marathonPresenceTitle => 'Burada mısın?';

  @override
  String get marathonPresenceHint =>
      'Molan bitti. Sıradaki seansı başlatmak için 1 dakika içinde “Buradayım”a dokun.';

  @override
  String get marathonPresenceConfirm => 'Buradayım';

  @override
  String get marathonPresenceChecking => 'Onaylanıyor…';

  @override
  String get marathonPresenceConnectionNeeded =>
      'Onay alınamadı. İnternet bağlantını kontrol edip süre dolmadan tekrar dene.';

  @override
  String get marathonPresenceExpired =>
      'Devam onayı gelmediği için maraton durdu. Tamamladığın seanslar korundu.';

  @override
  String marathonPresenceRemainingSemantics(int minutes, int seconds) {
    return 'Devam onayı için $minutes dakika $seconds saniye kaldı';
  }

  @override
  String get marathonStepStart => 'Başlangıç';

  @override
  String get marathonStepGoal => 'Hedef';

  @override
  String marathonSessionCount(int count) {
    return '$count seans';
  }

  @override
  String get marathonStepCompleted => 'Tamamlandı';

  @override
  String get marathonStepCurrent => 'Şimdiki seans';

  @override
  String get marathonStepUpcoming => 'Sıradaki seans';

  @override
  String get marathonStoppedInvalid =>
      'Maraton doğrulanamadığı için durduruldu. Tamamlanan seansların ve bu seanslardan kazanılan normal puan ile kum korunur. Bu plan için ek Maraton puanı verilmez.';

  @override
  String get marathonPlanTitle => 'Maratonunu planla';

  @override
  String get marathonDurationLabel => 'Pomodoro süresi';

  @override
  String get marathonStartingWelcome => 'Maraton başlıyor. İyi çalışmalar!';

  @override
  String get marathonViewProgress => 'Maraton ilerlemesi';

  @override
  String get marathonInfoTitle => 'Maraton nedir?';

  @override
  String marathonInfoBonusMatrix(
    int shortTwo,
    int shortThree,
    int shortFour,
    int longTwo,
    int longThree,
    int longFour,
  ) {
    return 'Tamamlama bonusu\n25 dk: 2 seans +$shortTwo, 3 seans +$shortThree, 4 seans +$shortFour puan.\n50 dk: 2 seans +$longTwo, 3 seans +$longThree, 4 seans +$longFour puan.\n\nBu ek puan, tüm seanslar kaydedilip normal puan kazandığında ve her devam onayı zamanında verildiğinde bir kez kazanılır. Her seansın normal puanına eklenir; ek kum kazandırmaz.';
  }

  @override
  String get onboardingGuideTitle => 'Uygulamayı tanı';

  @override
  String get onboardingGuideBody =>
      'Başlamadan önce ekranların nasıl çalıştığına göz at.';

  @override
  String get onboardingGuidePomoTitle => 'Pomo';

  @override
  String get onboardingGuidePomoBody =>
      'Kategorini ve 25 ya da 50 dakikalık seansını seçip Başlat’a dokun. Her seansta bir duraklatma hakkın var; duraklatılan seansın puanı azalır. Tamamlanan seanslar kaydedilir.';

  @override
  String get onboardingGuideMarathonTitle => 'Maraton';

  @override
  String get onboardingGuideMarathonBody =>
      'Maraton’u başlat düğmesinden 2, 3 veya 4 seans planla. Seanslar arasında 5 dakika mola verilir. Mola bitince 1 dakika içinde Buradayım’a dokunarak devam et; onay vermezsen Maraton biter. Bitirdiğin seansların normal puanları korunur. Planın tamamını bitirince 25 dakikalık seanslarda sırasıyla +2/+3/+5, 50 dakikalıklarda +4/+6/+10 ek puan kazanırsın.';

  @override
  String get onboardingGuideReportsTitle => 'Raporlar';

  @override
  String get onboardingGuideReportsBody =>
      'Günlük, haftalık ve aylık raporlar Pomodoro, Maraton odakları ve tamamlanmış denemelerin toplam çalışma süresini gösterir. Molalar ve vazgeçilen denemeler dahil değildir. Çalışma günü 04:00’da değişir; deneme süresi ayrı bir Deneme satırında görünür.';

  @override
  String get onboardingGuideRankingTitle => 'Sıralama';

  @override
  String get onboardingGuideRankingBody =>
      'Normal ve deneme ligleri ayrıdır; kendi hedefindeki kişilerle yarışırsın. Global sıralama tüm hedefleri kapsar. Dönem İstanbul saatine göre ayın 1’inde 00:00’da yenilenir. Az katılımcılı gruplar hazırlıkta kalabilir; terfi ve ödül koşulları Sıralama’daki ? rehberindedir.';

  @override
  String get onboardingGuideSocialTitle => 'Sosyal';

  @override
  String get onboardingGuideSocialBody =>
      'Arkadaş koduyla ekle ve isteklerini yönet. Görünür arkadaşların Odaklanıyor, yalnız Maraton molasında Molada, deneme sırasında Denemede olarak görünür. Liste açıkken düzenli yenilenir. Görünürlüğünü Ayarlar’dan değiştirebilir, kullanıcı gizleyebilir veya engelleyebilirsin.';

  @override
  String get onboardingGuideProfileTitle => 'Profil';

  @override
  String get onboardingGuideProfileBody =>
      'Üstteki avatarına dokunarak Profil’i aç. Kategorilerini düzenle, kazandığın kumla avatar koleksiyonunu genişlet ve avatarını seç. Dil, tema, bildirim ve görünürlük ayarlarını; yardım, gizlilik ve hesap işlemlerini burada bulursun.';

  @override
  String leagueInfoWhatBodyWithCapacity(int capacity) {
    return 'İlk puanlı seansını tamamladığında aynı kademede ve aynı dönemdeki uygun mevcut odaya yerleşirsin. Her odada en fazla $capacity kişi bulunur; oda doluysa yeni oda açılır. Dönem sırası sunucunun kabul ettiği seans puanlarına göre belirlenir.';
  }

  @override
  String leagueLaunchPreparingBody(int users) {
    return 'Ligler hazırlık döneminde. Son 14 günde seans tamamlayan $users farklı kullanıcıya ulaşınca ilk resmi yarışma sonraki tam 14 günlük dönemde başlar. Seansların, puanın ve raporların kaydolur; hazırlıkta terfi, düşme ve lig avatar ödülü yoktur. Hazırlık puanları resmi yarışmaya taşınmaz.';
  }

  @override
  String leagueLaunchScheduledBody(String date) {
    return 'İlk resmi lig dönemi $date başlayacak. O zamana kadar seansların ve raporların kaydolur; terfi, düşme ve lig avatar ödülü verilmez. Hazırlık puanları yarışmaya taşınmaz.';
  }

  @override
  String get leagueLaunchScheduledShort => 'Resmi lig dönemi başlıyor';

  @override
  String leaguePromotionPolicyBody(
    int active,
    int days,
    int minutes,
    int points,
  ) {
    return 'Terfi için odada bu dönem seans tamamlayan en az $active aktif kişi olmalı. Terfi kotası aktif kişi sayısının üçte biridir, aşağı yuvarlanır (3 aktif kişi: 1; 25 aktif kişi: 8). Bu dönem en az $days farklı çalışma gününde toplam $minutes dakika odaklanıp en az $points puan kazanmalı ve kotanın içinde bitirmelisin. Elmas Lig’de terfi yoktur.';
  }

  @override
  String leaguePromotionCurrentQuota(int count) {
    return 'Bu odada mevcut terfi kotası: ilk $count sıra. Gün, dakika ve puan şartları ayrıca sağlanmalıdır.';
  }

  @override
  String get leagueNoPromotionCurrentPeriod =>
      'Bu odada şu an terfi için yeterli aktif katılımcı yok. Tamamladığın seanslar kaydolmaya devam eder.';

  @override
  String get leagueDemotionPolicyBody =>
      'Düşme yalnızca en az 10 aktif kişinin bulunduğu odalarda uygulanır: sıralamanın sonundan aktif kişi sayısının üçte biri, aşağı yuvarlanarak bir alt lige düşer. Son 3 günde katılanlar ve Bronz Lig’dekiler düşmez.';

  @override
  String leagueAwardActiveRequirements(
    int members,
    int days,
    int minutes,
    int points,
  ) {
    return 'Resmi lig döneminde odada en az $members aktif kişi olmalı. En az $days farklı çalışma gününde toplam $minutes dakika odaklanıp $points puana ulaşman gerekir. Hazırlık döneminde ödül verilmez.';
  }

  @override
  String get leaguePreparationNoChanges =>
      'Hazırlık sırasında herkes mevcut liginde kalır; terfi, düşme ve lig avatar ödülü verilmez.';

  @override
  String get leagueLaunchPreparingShort =>
      'Hazırlık dönemi · Terfi, düşme ve lig ödülleri henüz başlamadı.';

  @override
  String get examTab => 'Deneme';

  @override
  String get examTitle => 'Denemeler';

  @override
  String get examNew => 'Yeni deneme';

  @override
  String get examHistory => 'Denemelerim';

  @override
  String get examLeague => 'Deneme ligi';

  @override
  String get examIntro =>
      'Sınavını seç, gerçek süresinde çöz. Netlerini sonradan ekleyebilirsin.';

  @override
  String get examUnavailable => 'Deneme modu yakında';

  @override
  String get examUnavailableBody =>
      'Bu sunucuda deneme modu henüz etkin değil. Sınavları inceleyebilirsin; normal çalışma ve Maraton devam eder.';

  @override
  String get examCatalogFallback =>
      'Çevrimdışı sınav bilgileri gösteriliyor. Başlatmak için sunucu bağlantısı gerekir.';

  @override
  String get examStart => 'Denemeyi başlat';

  @override
  String get examRulesTitle => 'Başlamadan önce';

  @override
  String get examRulesBody =>
      'Denemede mola ve duraklatma yoktur. Sayaç uygulama kapalıyken de ilerler. Tam süre dolmadan vazgeçersen puan ve deneme kumu kazanmazsın; denemen geçmişinde kalır. Netlerin puanını veya ligini etkilemez.';

  @override
  String get examReady => 'Hazır olduğunda başla';

  @override
  String get examNoPause => 'Duraklatma ve mola yok';

  @override
  String get examRunning => 'Deneme sürüyor';

  @override
  String get examTimeRemaining => 'Kalan süre';

  @override
  String get examAbandon => 'Denemeden vazgeç';

  @override
  String get examAbandonTitle => 'Denemeden vazgeçmek istiyor musun?';

  @override
  String get examAbandonBody =>
      'Bu deneme vazgeçildi olarak saklanacak. Puan, deneme kumu ve çalışma süresi kazanılmayacak.';

  @override
  String get examCompleted => 'Deneme tamamlandı';

  @override
  String get examAbandoned => 'Vazgeçildi';

  @override
  String get examPending => 'Sunucu onayı bekleniyor';

  @override
  String get examPendingBody =>
      'Denemen bu cihazda saklandı. Bağlantı geldiğinde aynı kayıt tekrar gönderilecek.';

  @override
  String get examStartPending => 'Başlatma sonucu bekleniyor';

  @override
  String get examStartPendingBody =>
      'Başlatma isteğinin sonucu henüz bilinmiyor. Tekrar denemek yeni bir deneme oluşturmaz.';

  @override
  String get examError =>
      'Deneme bilgileri alınamadı. Bağlantını kontrol edip tekrar dene.';

  @override
  String get examStartRateLimited =>
      'Son 24 saatte çok fazla deneme başlattın. Bir süre sonra tekrar deneyebilirsin.';

  @override
  String get examConflict => 'Önce devam eden çalışma veya denemeni tamamla.';

  @override
  String get examRetry => 'Tekrar dene';

  @override
  String get examEnterResults => 'Netlerini gir';

  @override
  String get examEditResults => 'Netlerini düzenle';

  @override
  String get examResultsTitle => 'Derslere göre sonuçlar';

  @override
  String get examResultsInfo =>
      'Netler kişisel rapor ve içgörü içindir; puan ve kuma etkisi yoktur.';

  @override
  String get examCorrect => 'Doğru';

  @override
  String get examWrong => 'Yanlış';

  @override
  String get examBlank => 'Boş';

  @override
  String get examNet => 'Net';

  @override
  String get examSaveResults => 'Sonuçları kaydet';

  @override
  String get examResultsInvalid =>
      'Her ders için doğru, yanlış ve boş toplamı soru sayısına eşit olmalı. Yalnızca negatif olmayan tam sayılar gir.';

  @override
  String get examResultsSaved => 'Netlerin kaydedildi.';

  @override
  String get examResultsSaveError =>
      'Sonuçlar kaydedilemedi. Girdilerin korundu; tekrar deneyebilirsin.';

  @override
  String get examNoHistory => 'Henüz denemen yok';

  @override
  String get examNoHistoryBody =>
      'Başlattığın ve vazgeçtiğin denemeler burada görünür.';

  @override
  String get examPracticeSand => 'Deneme kumu';

  @override
  String get examInsights => 'Süre ve netlerin';

  @override
  String get examInsightsEmpty =>
      'Henüz gösterilecek bir süre–net içgörüsü yok. Aynı dersten en az iki sonuç kaydettiğinde burada karşılaştırabilirsin.';

  @override
  String get examInsightsDisclaimer =>
      'Bu karşılaştırma bir ilişki gösterir; net değişiminin tek nedeninin çalışma süresi olduğunu söylemez.';

  @override
  String get examLeagueEmpty =>
      'İlk puan kazandığın denemeden sonra ligde yerini alırsın.';

  @override
  String get examLeaguePreparing =>
      'Bu grupta yarışma için yeterli aktif kullanıcı bekleniyor.';

  @override
  String get examGlobal => 'Global';

  @override
  String get examTargetGroup => 'Hedef grubum';

  @override
  String get examRewardAvatars => 'Deneme ligi avatarları';

  @override
  String get examRewardAvatarsPending =>
      'Özel görseller hazırlanıyor. Görsel hazır olmadan sahip olmadığın bir ödül gösterilmez.';

  @override
  String get examFinishedNoResults => 'Netler henüz girilmedi';

  @override
  String get examStartTime => 'Başlangıç';

  @override
  String get examEndTime => 'Bitiş';

  @override
  String get examDismiss => 'Tamam';

  @override
  String get examLgsBreakInfo =>
      'LGS iki ayrı oturumdur. Gerçek sınavda sözel ve sayısal oturum arasında 45 dakika ara bulunur.';

  @override
  String get examLoadMore => 'Daha fazla göster';

  @override
  String get examNoAward => 'Ödül yok';

  @override
  String get examNetUnavailable => '—';

  @override
  String get examQueuedResults =>
      'Sonuçların bu cihazda saklandı. Bağlantı geldiğinde gönderilecek.';

  @override
  String get examTotalStudy => 'Toplam çalışma';

  @override
  String get examNoVerifiedDuration =>
      'Çalışma süresi yalnızca sunucunun onayladığı tamamlanmış denemelere eklenir.';

  @override
  String get examStarting => 'Başlatılıyor…';

  @override
  String get examSaving => 'Kaydediliyor…';

  @override
  String get examAllGroups => 'Tüm sınavlar';

  @override
  String examQuestionsMinutes(int questions, int minutes) {
    return 'Soru: $questions · Süre: $minutes dk';
  }

  @override
  String examSubjectQuestions(int questions) {
    return '$questions soru';
  }

  @override
  String examNetRule(int divisor) {
    return 'Net = Doğru − Yanlış / $divisor';
  }

  @override
  String examRewardSummary(int points, int sand) {
    return '$points puan · $sand deneme kumu';
  }

  @override
  String examInsightsChange(
    String subject,
    int minutes,
    String before,
    String after,
  ) {
    return 'İlişkili çalışma kategorilerinde $minutes dk; $subject neti: $before → $after.';
  }

  @override
  String examResultsQuestionTotal(int actual, int expected) {
    return 'Toplam $actual / $expected';
  }

  @override
  String examMonthlyReset(String date) {
    return 'Dönem bitişi: $date';
  }

  @override
  String get onboardingSegmentTus => 'TUS (Tıpta Uzmanlık)';

  @override
  String get onboardingLanguageTitle => 'Hangi dili kullanmak istersin?';

  @override
  String get onboardingLanguageBody =>
      'Dilini daha sonra Ayarlar’dan değiştirebilirsin.';

  @override
  String get onboardingGuideExamTitle => 'Deneme: sınav süresini deneyimle';

  @override
  String get onboardingGuideExamBody =>
      'Sınavını seç; soru sayısı ve süresi otomatik gelir. Denemede mola ve duraklatma yoktur. Tam süreyi tamamladığında ayrı deneme puanı ve kumu kazanırsın. Vazgeçersen kaydın geçmişte kalır, ödül ve çalışma süresi kazanmazsın.';

  @override
  String get onboardingGuideInsightsTitle => 'Netler ve süre–net içgörüleri';

  @override
  String get onboardingGuideInsightsBody =>
      'Denemelerim’den ders ders doğru, yanlış ve boşlarını girip sonra düzenleyebilirsin. Netlerin yalnız kişisel raporlarındadır; puanını veya ligini değiştirmez. Yeterli veri oluştuğunda ders çalışma süreni netlerindeki değişimle birlikte görürsün.';

  @override
  String get languageNativeTr => 'Türkçe';

  @override
  String get languageNativeEn => 'English';

  @override
  String get languageSettingsTitle => 'Uygulama Dili';

  @override
  String get categoriesSectionTitle => 'KATEGORİLERİM';

  @override
  String get editProfileAction => 'Profili Düzenle';

  @override
  String get effHigh => 'Yüksek';

  @override
  String get effNormal => 'Normal';

  @override
  String get effVeryHigh => 'Çok Yüksek';

  @override
  String get legacyEmailReadonlyHint =>
      'E-posta adresi güvenlik nedeniyle değiştirilemez.';

  @override
  String get heatmapLess => 'Az';

  @override
  String get heatmapMore => 'Çok';

  @override
  String get manageCategoriesTileSub =>
      'Kategori ekle, düzenle, sırala ve arşivle';

  @override
  String get manageCategoriesTileTitle => 'Kategorileri Yönet';

  @override
  String get monthIntensitySuffix => 'Yoğunluğu';

  @override
  String get mostEfficientDayLabel => 'En Verimli Gün';

  @override
  String get profileFullNameLabel => 'Ad Soyad';

  @override
  String get newWeekLabel => 'Yeni';

  @override
  String get noReportsDesc =>
      'Bir Pomodoro veya deneme tamamladığında ders dağılımın ve raporların burada görünecek.';

  @override
  String get noStudyThisDay => 'Bu gün çalışma yok';

  @override
  String get notificationsAndLockScreen => 'Bildirimler ve kilit ekranı sayacı';

  @override
  String get preferencesSectionTitle => 'Tercihler';

  @override
  String get reportsWeeklyTab => 'Haftalık Çalışma';

  @override
  String get reportsMonthlyTab => 'Aylık Takip';

  @override
  String get reportsDailyTab => 'Günlük Çalışma';

  @override
  String get reportsTabDailyShort => 'Günlük';

  @override
  String get reportsTabWeeklyShort => 'Haftalık';

  @override
  String get reportsTabMonthlyShort => 'Aylık';

  @override
  String get reportsTabExamsShort => 'Deneme';

  @override
  String get topSubjectsLabel => 'En Çok Çalışılan Dersler';

  @override
  String get topicComparisonTitle => 'Konu Karşılaştırması';

  @override
  String get totalFocusLabel => 'Toplam\nOdaklanma';

  @override
  String get weekDayBreakdownTitle => 'Gün Gün Döküm';

  @override
  String get weeklyAnalysisCaption => 'HAFTALIK ANALİZ';

  @override
  String get legacyWeeklyDistSub => 'Bugünün özeti';

  @override
  String get legacyWeeklyDistTitle => 'Bugünün Dağılımı';

  @override
  String get weeklyEfficiencyCaption => 'HAFTALIK VERİMLİLİK';

  @override
  String get weeklySummaryTitle => 'Haftalık Özet';

  @override
  String get weeklyTrendCaption => 'HAFTALIK TREND';

  @override
  String get statsSessionTypesTitle => 'Oturum türleri';

  @override
  String get statsNormalSessions => 'Normal seans';

  @override
  String get statsCompletedMarathons => 'Tamamlanan maraton';

  @override
  String get statsCompletedExams => 'Tamamlanan deneme';

  @override
  String get statsExamCategory => 'Deneme';

  @override
  String get statsOpenExamDetails => 'Denemelerim, netler ve içgörüler';

  @override
  String get statsUnknownSessionTypes =>
      'Eski sunucu bu kayıtların normal seans ve Maraton ayrımını henüz iletmiyor. Süre toplamları korunur.';

  @override
  String get statsExamTotalsInfo =>
      'Toplam süre, Pomodoro ve Maraton odakları ile tamamlanmış denemeleri içerir. Deneme süresi derslere paylaştırılmaz.';

  @override
  String statsMarathonFocusCount(int count) {
    return '$count Maraton odağı';
  }

  @override
  String statsFocusEquivalent(int count) {
    return '$count × 25 dk odak eşdeğeri';
  }

  @override
  String statsCountsPending(int count) {
    return '$count seans sunucu onayı bekliyor';
  }

  @override
  String get socialTakingExam => 'Denemede';

  @override
  String get rankingTabGlobal => 'Global';

  @override
  String get rankingGlobalResetIn =>
      'Global sıralamanın sıfırlanmasına kalan süre';

  @override
  String get leagueCalendarMonthBody =>
      'Normal lig ve deneme ligi ayrı puanlarla yarışır. Her ikisi de İstanbul saatiyle ayın 1’inde 00:00’da yenilenir. Günlük çalışma ve seri takibi 04:00 kuralıyla devam eder.';

  @override
  String leagueCalendarPreparingBody(String date) {
    return 'Aylık yarışma için hazırlık sürüyor. Resmî başlangıç: $date (İstanbul). Odada yeterli aktif katılımcı olduğunda terfi ve ödül şartları uygulanır. Tamamladığın seanslar ve kazandığın toplam puan korunur.';
  }

  @override
  String get leagueCalendarPreparingGeneric =>
      'Aylık yarışma için hazırlık sürüyor. Yeterli aktif katılımcı olmadan terfi, düşme veya lig ödülü verilmez; seansların kaydolmaya devam eder.';

  @override
  String get leagueTargetTitle => 'Lig hedefin';

  @override
  String leagueTargetCurrent(String target) {
    return 'Bu ay: $target';
  }

  @override
  String leagueTargetPending(String target, String date) {
    return 'Sonraki hedef: $target · $date (İstanbul)';
  }

  @override
  String get leagueTargetChange => 'Hedefi değiştir';

  @override
  String get leagueTargetDialogTitle => 'Lig hedefini seç';

  @override
  String get leagueTargetPolicy =>
      'Normal ligde ve deneme liginde aynı hedefteki kullanıcılarla eşleşirsin. İlk seansından önce hedef hemen değişir. Ay içinde değiştirdiğinde yeni hedef sonraki ayın 1’inde, İstanbul saatiyle 00:00’da uygulanır; bu ayki puanın ve odan korunur. Global görünüm hedefini değiştirmez ve ek ödül kazandırmaz.';

  @override
  String get leagueTargetSave => 'Hedefi kaydet';

  @override
  String get leagueTargetSaveError =>
      'Hedef kaydedilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get leagueTargetOther => 'Diğer';

  @override
  String get leagueGlobalScopeBody =>
      'Tüm hedeflerdeki kullanıcıların bu ay kazandığı normal odak puanları. Deneme puanları ayrı ligdedir; global görünüm ek ödül vermez.';

  @override
  String get examFinishEarly => 'AYT\'yi bitir';

  @override
  String get examFinishEarlyTitle => 'AYT\'yi erken bitirmek istiyor musun?';

  @override
  String get examFinishEarlyBody =>
      'Bitirme isteğin sunucu tarafından kabul edildiğinde süre ve ödül kesinleşir. Ardından çözdüğün testleri seçip netlerini, başlığını ve notunu kaydedebilirsin.';

  @override
  String get examEarlyPendingTitle => 'Erken bitirme onayı bekleniyor';

  @override
  String get examEarlyPendingBody =>
      'İsteğin bu cihazda saklandı. Süre ve ödül sunucu kabul ettiğinde kesinleşir; bağlantı geldiğinde tekrar gönderilir. O zamana kadar planlanan süre dolarsa tam süre kuralları uygulanır.';

  @override
  String get examEarlyUnavailable =>
      'Bu sunucuda erken bitirme şu anda kullanılamıyor. Kaydın silinmedi; yeniden deneyebilir veya bağlantı durumunu kontrol edebilirsin.';

  @override
  String get examEarlyTooSoon =>
      'Bitirmeden önce en az bir saniye geçmeli. Yeniden deneyebilirsin.';

  @override
  String get examCompletedEarly => 'Erken tamamlandı';

  @override
  String examActualPlanned(String actual, String planned) {
    return 'Gerçek süre: $actual · Planlanan: $planned';
  }

  @override
  String examCreditedMinutes(int minutes) {
    return 'Rapora eklenen: $minutes dk';
  }

  @override
  String examSeconds(int seconds) {
    return '$seconds sn';
  }

  @override
  String get examDetailsTitle => 'Deneme ayrıntıları ve netler';

  @override
  String get examTitleLabel => 'Deneme başlığı';

  @override
  String get examNoteLabel => 'Not';

  @override
  String get examSelectModules => 'Çözdüğün AYT testlerini seç';

  @override
  String get examModuleHint =>
      'Net girmek için en az bir test seç. Başlık ve notunu net girmeden de kaydedebilirsin.';

  @override
  String get examModuleUnknown => 'Bu kayıtta AYT test seçimi henüz yok.';

  @override
  String get examScopeUnavailable => 'Seçilen kapsam hesaplanamadı.';

  @override
  String examSelectedQuestions(int selected, int total) {
    return 'Seçilen kapsam: $selected / $total soru';
  }

  @override
  String get examReligionAlternativeInfo =>
      'Sosyal Bilimler-2\'de Din Kültürü / ek felsefe alanı toplam 6 sorudur; aynı alan iki kez sayılmaz.';

  @override
  String get examDetailsEdit => 'Ayrıntıları ve netleri düzenle';

  @override
  String get examDetailsSaved => 'Deneme ayrıntıların ve netlerin kaydedildi.';

  @override
  String get examDetailsQueued =>
      'Ayrıntıların ve netlerin bu cihazda saklandı; bağlantı geldiğinde aynı istek gönderilecek.';

  @override
  String get examDetailsConflict =>
      'Bu deneme başka bir yerde düzenlenmiş. Güncel kaydı yükle, değişikliklerini kontrol et ve tekrar kaydet.';

  @override
  String get examScopeConflict =>
      'Sonuçları kaydedilmiş bir testi seçimin dışına çıkaramazsın. Test seçimini ve girdiğin dersleri kontrol et.';

  @override
  String get examDetailsInvalid =>
      'Başlık en fazla 120, not en fazla 2000 karakter olabilir. Başlık tek satır olmalı; test seçimini ve sonuçlarını da kontrol et.';

  @override
  String get examDetailsReload => 'Güncel kaydı yükle';

  @override
  String get examDetailsPending =>
      'Önceki kayıt isteğinin sonucu bekleniyor. Yeniden gönderebilir, sonucu aldıktan sonra düzenlemeye devam edebilirsin.';

  @override
  String get examDefinitionUnsupported =>
      'Bu AYT kaydının test yapısı tanınmıyor. Kaydın korundu; güncel sınav bilgisi için bağlantını kontrol et.';

  @override
  String get examDetailsUnavailable =>
      'Bu sunucuda başlık, not ve test seçimi düzenleme henüz kullanılamıyor.';

  @override
  String get examIntroEarly =>
      'Sınavını seç ve çalışmaya başla. AYT\'yi erken bitirebilir, ardından çözdüğün testleri ve netlerini kaydedebilirsin.';

  @override
  String examCharacterCount(int current, int maximum) {
    return '$current / $maximum karakter';
  }

  @override
  String get onboardingSegmentDus => 'DUS (Diş Hekimliğinde Uzmanlık)';

  @override
  String get examTabNew => 'Yeni';

  @override
  String get examTabHistory => 'Geçmiş';

  @override
  String get examTabLeague => 'Lig';

  @override
  String get examFilterAll => 'Tümü';

  @override
  String examMyGoal(String goal) {
    return '$goal sınavlarım';
  }

  @override
  String get examExtraExams => 'Ek sınavlar';

  @override
  String get examEmptyFilter => 'Bu seçim için henüz deneme bulunmuyor.';

  @override
  String get examHistoryDetails => 'Deneme ayrıntıları';

  @override
  String get examNetInfo =>
      'YKS, TUS, DUS ve KPSS: 4 yanlış 1 doğruyu; LGS: 3 yanlış 1 doğruyu götürür. Netlerin bu kurala göre hesaplanır.';

  @override
  String get examAytTestCount => '4 test';

  @override
  String get examKpssChooseTrack => 'KPSS türünü seç';

  @override
  String get examKpssBachelor => 'Lisans';

  @override
  String get examKpssAssociate => 'Ön Lisans';

  @override
  String get examKpssSecondary => 'Ortaöğretim';

  @override
  String get examKpssField => 'Alan Bilgisi';
}
