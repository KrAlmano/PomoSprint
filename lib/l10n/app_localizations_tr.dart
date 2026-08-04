// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

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
  String get resendVerificationLink => 'Doğrulama E-postasını Tekrar Gönder 📬';

  @override
  String get errFillFields => 'Lütfen tüm alanları doldurun.';

  @override
  String get errInvalidCredentials => 'E-posta adresi veya şifre hatalı!';

  @override
  String get verificationResentMsg =>
      '📬 Doğrulama bağlantısı tekrar gönderildi. Lütfen e-postanızı kontrol edin.';

  @override
  String get passwordResetMsg => 'Şifre sıfırlama bağlantısı gönderildi.';

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
      'Devam etmek için kullanım koşullarını kabul edin.';

  @override
  String get errEmailExists =>
      'Bu e-posta adresi zaten kayıtlı! Lütfen \"Giriş Yap\" ekranından giriş yapın.';

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
}
