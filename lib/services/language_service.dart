import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/category_names.dart';

enum AppLanguage { tr, en }

class LanguageService extends ChangeNotifier {
  static final LanguageService instance = LanguageService._internal();
  LanguageService._internal();

  AppLanguage _currentLanguage = AppLanguage.tr;
  AppLanguage get currentLanguage => _currentLanguage;
  Locale get currentLocale => Locale(_currentLanguage.name);

  bool get isTurkish => _currentLanguage == AppLanguage.tr;

  static const String _prefKey = 'app_language_code';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefKey);
    if (savedCode != null) {
      if (savedCode == 'en') {
        _currentLanguage = AppLanguage.en;
      } else {
        _currentLanguage = AppLanguage.tr;
      }
    } else {
      _currentLanguage = AppLanguage.tr;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language.name);
  }

  /// Hazır kategori adının arayüz dilindeki karşılığı (DB'deki ad Türkçe ya
  /// da İngilizce olabilir; kullanıcının kendi adı olduğu gibi kalır). Tablo:
  /// utils/category_names.dart.
  String translateCatName(String catName) => localizedKnownCategoryName(catName, turkish: isTurkish);

  String translateTableName(String tableName) {
    if (tableName == 'Sessiz Masa A1' || tableName == 'Silent Table A1') {
      return isTurkish ? 'Sessiz Masa A1' : 'Silent Table A1';
    }
    if (tableName == 'Sessiz Masa A2' || tableName == 'Silent Table A2') {
      return isTurkish ? 'Sessiz Masa A2' : 'Silent Table A2';
    }
    if (tableName == 'Grup Odak Masası 1' || tableName == 'Group Focus Table 1') {
      return isTurkish ? 'Grup Odak Masası 1' : 'Group Focus Table 1';
    }
    if (tableName == 'Grup Odak Masası 2' || tableName == 'Group Focus Table 2') {
      return isTurkish ? 'Grup Odak Masası 2' : 'Group Focus Table 2';
    }
    if (tableName == 'Kahve & Mola Masası' || tableName == 'Coffee & Break Table') {
      return isTurkish ? 'Kahve & Mola Masası' : 'Coffee & Break Table';
    }
    return tableName;
  }

  String translate(String key) {
    final Map<String, Map<AppLanguage, String>> translations = {
      // --- Bottom Navigation & Main App ---
      'nav_timer': {AppLanguage.tr: 'Süreç', AppLanguage.en: 'Timer'},
      'nav_social': {AppLanguage.tr: 'Sosyal', AppLanguage.en: 'Social'},
      'nav_reports': {AppLanguage.tr: 'Raporlar', AppLanguage.en: 'Reports'},
      'nav_profile': {AppLanguage.tr: 'Profil', AppLanguage.en: 'Profile'},
      'nav_history': {AppLanguage.tr: 'Geçmiş', AppLanguage.en: 'History'},
      'nav_ranking': {AppLanguage.tr: 'Sıralama', AppLanguage.en: 'Ranking'},
      'nav_categories': {AppLanguage.tr: 'Kategoriler', AppLanguage.en: 'Categories'},

      // --- App Bar Titles ---
      'title_timer': {AppLanguage.tr: 'PomoSprint', AppLanguage.en: 'PomoSprint'},
      'title_reports': {AppLanguage.tr: 'Ders Raporları & Geçmiş', AppLanguage.en: 'Study Reports & History'},
      'title_ranking': {AppLanguage.tr: 'Liderlik Tablosu', AppLanguage.en: 'Leaderboard'},
      'title_social': {AppLanguage.tr: 'Canlı Odaklanma', AppLanguage.en: 'Live Focus'},
      'title_categories': {AppLanguage.tr: 'Ders Kategorileri', AppLanguage.en: 'Course Categories'},

      // --- Timer Screen ---
      'timer_title': {AppLanguage.tr: 'Pomodoro', AppLanguage.en: 'Pomodoro'},
      'mode_pomodoro': {AppLanguage.tr: 'Pomodoro', AppLanguage.en: 'Pomodoro'},
      'mode_short_break': {AppLanguage.tr: 'Kısa Mola', AppLanguage.en: 'Short Break'},
      'mode_long_break': {AppLanguage.tr: 'Uzun Mola', AppLanguage.en: 'Long Break'},
      'btn_start': {AppLanguage.tr: 'BAŞLAT', AppLanguage.en: 'START'},
      'btn_pause': {AppLanguage.tr: 'DURDUR', AppLanguage.en: 'PAUSE'},
      'btn_reset': {AppLanguage.tr: 'SIFIRLA', AppLanguage.en: 'RESET'},
      'select_subject': {AppLanguage.tr: 'DERS SEÇ', AppLanguage.en: 'SELECT SUBJECT'},
      'add_subject': {AppLanguage.tr: 'Ders Ekle', AppLanguage.en: 'Add Subject'},
      'daily_streak': {AppLanguage.tr: 'Günlük Seri', AppLanguage.en: 'Daily Streak'},
      'daily_goal': {AppLanguage.tr: 'Günlük Hedef', AppLanguage.en: 'Daily Goal'},
      'session_completed': {AppLanguage.tr: 'Tebrikler! Seans Tamamlandı 🎉', AppLanguage.en: 'Congrats! Session Completed 🎉'},
      'duration_planning': {AppLanguage.tr: 'Süre Planlama', AppLanguage.en: 'Duration Planning'},
      'custom_minutes': {AppLanguage.tr: 'Özel Dakika Ayarla', AppLanguage.en: 'Custom Minutes'},
      'pause_credit_available': {AppLanguage.tr: '1/1 Duraklatma Hakkı', AppLanguage.en: '1/1 Pause Credit Available'},
      'pause_credit_used': {AppLanguage.tr: '0/1 Duraklatma Hakkı (Hakkın Bitti)', AppLanguage.en: '0/1 Pause Credit (Limit Reached)'},
      'points_badge': {AppLanguage.tr: 'PUAN', AppLanguage.en: 'POINTS'},

      // --- Reports & History Screen ---
      'summary_title': {AppLanguage.tr: 'Özet', AppLanguage.en: 'Summary'},
      'total_focus_this_week': {AppLanguage.tr: 'Bu Hafta Toplam Odaklanma', AppLanguage.en: 'Total Focus This Week'},
      'total_focus_this_month': {AppLanguage.tr: 'Bu Ay Toplam Odaklanma', AppLanguage.en: 'Total Focus This Month'},
      'active_session': {AppLanguage.tr: 'Aktif Seans', AppLanguage.en: 'Active Session'},
      'hours_unit': {AppLanguage.tr: 's', AppLanguage.en: 'h'},
      'minutes_unit_short': {AppLanguage.tr: 'dk', AppLanguage.en: 'min'},
      'reports_tab_subject': {AppLanguage.tr: 'Günlük Çalışma', AppLanguage.en: 'Daily Focus'},
      'reports_tab_history': {AppLanguage.tr: 'Haftalık Çalışma', AppLanguage.en: 'Weekly Focus'},
      'reports_tab_monthly': {AppLanguage.tr: 'Aylık Takip', AppLanguage.en: 'Monthly Tracking'},
      'total_focus_time': {AppLanguage.tr: 'Toplam Odaklanma Süresi', AppLanguage.en: 'Total Focus Time'},
      'subject_distribution': {AppLanguage.tr: 'Ders Odaklanma Dağılımı', AppLanguage.en: 'Subject Focus Breakdown'},
      'no_data_yet': {AppLanguage.tr: 'Henüz kayıtlı çalışma bulunmuyor', AppLanguage.en: 'No study sessions recorded yet'},
      'no_data_desc': {AppLanguage.tr: 'Pomodoro seansı tamamladıkça istatistiklerin burada görünecek.', AppLanguage.en: 'Complete Pomodoro sessions to see your statistics here.'},
      'no_reports_title': {AppLanguage.tr: 'Henüz detaylı raporun yok, çalışmaya başla! 🚀', AppLanguage.en: 'No detailed report yet, start studying! 🚀'},
      'no_reports_desc': {AppLanguage.tr: 'Zamanlayıcıyı başlatıp ilk Pomodoro seansını tamamladığında ders dağılımın ve raporların burada görünecek.', AppLanguage.en: 'When you start the timer and complete your first Pomodoro session, your breakdown and reports will appear here.'},
      'start_studying_now': {AppLanguage.tr: 'Hemen Çalışmaya Başla', AppLanguage.en: 'Start Studying Now'},
      'completed_sessions': {AppLanguage.tr: 'Tamamlanan Seanslar', AppLanguage.en: 'Completed Sessions'},
      'sessions': {AppLanguage.tr: 'Seans', AppLanguage.en: 'Sessions'},

      // --- Ranking / Leaderboard Screen ---
      'weekly': {AppLanguage.tr: 'Haftalık', AppLanguage.en: 'Weekly'},
      'monthly': {AppLanguage.tr: 'Aylık', AppLanguage.en: 'Monthly'},
      'friends': {AppLanguage.tr: 'Arkadaşlar', AppLanguage.en: 'Friends'},
      'rank': {AppLanguage.tr: 'Sıra', AppLanguage.en: 'Rank'},
      'user': {AppLanguage.tr: 'Kullanıcı', AppLanguage.en: 'User'},
      'points': {AppLanguage.tr: 'Puan', AppLanguage.en: 'Points'},
      'minutes': {AppLanguage.tr: 'Dakika', AppLanguage.en: 'Minutes'},
      'study_duration': {AppLanguage.tr: 'dk çalışma', AppLanguage.en: 'min study'},
      'you': {AppLanguage.tr: '(Sen)', AppLanguage.en: '(You)'},

      // --- Social Screen ---
      'virtual_library': {AppLanguage.tr: 'Sanal Kütüphane & Masalar', AppLanguage.en: 'Virtual Library & Tables'},
      'students_studying': {AppLanguage.tr: 'Öğrenci Masalarda Çalışıyor', AppLanguage.en: 'Students Studying at Tables'},
      'empty_tables': {AppLanguage.tr: 'Masalar Boş - İlk Oturan Sen Ol!', AppLanguage.en: 'Tables Empty - Be the First to Sit!'},
      'leave_table': {AppLanguage.tr: 'Masadan Kalk', AppLanguage.en: 'Leave Table'},
      'join_table': {AppLanguage.tr: 'Masaya Katıl', AppLanguage.en: 'Join Table'},
      'silent_room': {AppLanguage.tr: 'Sadece Sessiz', AppLanguage.en: 'Silent Only'},
      'all_tables': {AppLanguage.tr: 'Tüm Masalar 🏢', AppLanguage.en: 'All Tables 🏢'},
      'silent_library': {AppLanguage.tr: 'Sessiz Kütüphane 🤫', AppLanguage.en: 'Silent Library 🤫'},
      'main_hall': {AppLanguage.tr: 'Ana Çalışma Salonu 📚', AppLanguage.en: 'Main Study Hall 📚'},
      'lounge_mola': {AppLanguage.tr: 'Mola Lounge ☕', AppLanguage.en: 'Break Lounge ☕'},
      'search_table_student': {AppLanguage.tr: 'Masa veya öğrenci ara...', AppLanguage.en: 'Search table or student...'},
      'occupied': {AppLanguage.tr: 'Dolu', AppLanguage.en: 'Occupied'},
      'sit': {AppLanguage.tr: 'Otur', AppLanguage.en: 'Sit'},
      'focusing': {AppLanguage.tr: 'Odaklanıyor 🟢', AppLanguage.en: 'Focusing 🟢'},
      'waiting': {AppLanguage.tr: 'Bekliyor ⏳', AppLanguage.en: 'Waiting ⏳'},
      'quiet_zone': {AppLanguage.tr: 'Sessiz Bölge', AppLanguage.en: 'Quiet Zone'},
      'main_zone': {AppLanguage.tr: 'Grup Masaları', AppLanguage.en: 'Group Tables'},
      'lounge_zone': {AppLanguage.tr: 'Kahve & Mola Masası', AppLanguage.en: 'Lounge & Coffee'},
      'chat_placeholder': {AppLanguage.tr: 'Mesajınızı yazın...', AppLanguage.en: 'Type a message...'},

      // --- Categories Screen ---
      'add_new_category': {AppLanguage.tr: 'Yeni Kategori Ekle', AppLanguage.en: 'Add New Category'},
      'add_category': {AppLanguage.tr: 'Yeni Kategori Ekle', AppLanguage.en: 'Add New Category'},
      'add_category_sub': {AppLanguage.tr: 'Çalışmalarını düzenlemek için yeni bir ders veya konu oluştur.', AppLanguage.en: 'Create a new subject or topic to organize your studies.'},
      'category_name_hint': {AppLanguage.tr: 'Kategori Adı (Örn: Tarih)', AppLanguage.en: 'Category Name (e.g. History)'},
      'color_selection': {AppLanguage.tr: 'Renk Seçimi', AppLanguage.en: 'Color Selection'},
      'add_category_btn': {AppLanguage.tr: 'Kategori Ekle', AppLanguage.en: 'Add Category'},
      'existing_categories': {AppLanguage.tr: 'Mevcut Kategoriler', AppLanguage.en: 'Existing Categories'},
      'study_sessions_count': {AppLanguage.tr: 'Çalışma Oturumu', AppLanguage.en: 'Study Sessions'},
      'category_name': {AppLanguage.tr: 'Kategori Adı', AppLanguage.en: 'Category Name'},
      'choose_color': {AppLanguage.tr: 'Renk Seç', AppLanguage.en: 'Choose Color'},
      'delete': {AppLanguage.tr: 'Sil', AppLanguage.en: 'Delete'},

      // --- Profile Screen ---
      'profile_title': {AppLanguage.tr: 'Profil ve Ayarlar', AppLanguage.en: 'Profile & Settings'},
      'edit_profile': {AppLanguage.tr: 'Profili Düzenle', AppLanguage.en: 'Edit Profile'},
      'name_surname': {AppLanguage.tr: 'Ad Soyad', AppLanguage.en: 'Full Name'},
      'email': {AppLanguage.tr: 'E-posta Adresi', AppLanguage.en: 'Email Address'},
      'email_readonly_hint': {AppLanguage.tr: 'E-posta adresi güvenlik nedeniyle değiştirilemez.', AppLanguage.en: 'Email address cannot be changed for security.'},
      'app_language': {AppLanguage.tr: 'Uygulama Dili', AppLanguage.en: 'App Language'},
      'lang_tr': {AppLanguage.tr: 'Türkçe 🇹🇷', AppLanguage.en: 'Turkish 🇹🇷'},
      'lang_en': {AppLanguage.tr: 'English 🇬🇧', AppLanguage.en: 'English 🇬🇧'},
      'change_avatar': {AppLanguage.tr: 'Avatarı Değiştir', AppLanguage.en: 'Change Avatar'},
      'view_avatar_gallery': {AppLanguage.tr: 'Avatar galerisini gör', AppLanguage.en: 'View avatar gallery'},
      'manage_categories': {AppLanguage.tr: 'Kategori Ekle / Yönet', AppLanguage.en: 'Manage Categories'},
      'manage_categories_sub': {AppLanguage.tr: 'Ders ve çalışma kategorilerini düzenle', AppLanguage.en: 'Add & edit study categories'},
      'categories_section_title': {AppLanguage.tr: 'KATEGORİLERİM', AppLanguage.en: 'MY CATEGORIES'},
      'manage_categories_tile_title': {AppLanguage.tr: 'Kategorileri Yönet', AppLanguage.en: 'Manage Categories'},
      'manage_categories_tile_sub': {AppLanguage.tr: 'Kategori ekle, düzenle, sırala ve arşivle', AppLanguage.en: 'Add, edit, reorder & archive categories'},
      'total_study': {AppLanguage.tr: 'toplam çalışma', AppLanguage.en: 'total study'},
      'total_points': {AppLanguage.tr: 'Kazanılan Puan', AppLanguage.en: 'Total Points'},
      'streak_days': {AppLanguage.tr: 'Günlük Seri', AppLanguage.en: 'Streak Days'},
      'delete_account': {AppLanguage.tr: 'Hesabımı Sil', AppLanguage.en: 'Delete Account'},
      'delete_account_error': {AppLanguage.tr: '⚠️ Hesabınız silinirken bir hata oluştu', AppLanguage.en: '⚠️ An error occurred while deleting your account'},
      'privacy_policy': {AppLanguage.tr: 'Gizlilik Politikası', AppLanguage.en: 'Privacy Policy'},
      'terms_of_service': {AppLanguage.tr: 'Kullanım Şartları', AppLanguage.en: 'Terms of Service'},
      'logout': {AppLanguage.tr: 'Çıkış Yap', AppLanguage.en: 'Log Out'},
      'save': {AppLanguage.tr: 'Kaydet', AppLanguage.en: 'Save'},
      'cancel': {AppLanguage.tr: 'İptal', AppLanguage.en: 'Cancel'},
      'notifications': {AppLanguage.tr: 'Bildirimler', AppLanguage.en: 'Notifications'},
      'dark_mode': {AppLanguage.tr: 'Karanlık Mod', AppLanguage.en: 'Dark Mode'},
      'social_visibility': {AppLanguage.tr: 'Sosyal Listede Görün', AppLanguage.en: 'Show in Social List'},
      'social_visibility_sub': {
        AppLanguage.tr: 'Odaklanırken diğer kullanıcılar seni canlı listede görebilsin',
        AppLanguage.en: 'Let other users see you in the live list while you focus',
      },
      'preferences': {AppLanguage.tr: 'Tercihler', AppLanguage.en: 'Preferences'},
      'name_updated_success': {AppLanguage.tr: 'Profil adınız başarıyla güncellendi!', AppLanguage.en: 'Profile name updated successfully!'},

      // --- Login & Register ---
      'welcome_back': {AppLanguage.tr: 'Tekrar Hoş Geldiniz!', AppLanguage.en: 'Welcome Back!'},
      'login_subtitle': {AppLanguage.tr: 'Odaklanmaya devam etmek için giriş yapın.', AppLanguage.en: 'Sign in to continue your focus session.'},
      'password': {AppLanguage.tr: 'Şifre', AppLanguage.en: 'Password'},
      'login_btn': {AppLanguage.tr: 'Giriş Yap', AppLanguage.en: 'Sign In'},
      'no_account': {AppLanguage.tr: 'Hesabın yok mu? Kaydol', AppLanguage.en: "Don't have an account? Sign Up"},
      'register_title': {AppLanguage.tr: 'Hesap Oluştur', AppLanguage.en: 'Create Account'},
      'register_subtitle': {AppLanguage.tr: 'PomoSprint topluluğuna katılın.', AppLanguage.en: 'Join the PomoSprint community.'},
      'register_btn': {AppLanguage.tr: 'Kayıt Ol', AppLanguage.en: 'Sign Up'},
      'already_have_account': {AppLanguage.tr: 'Zaten hesabın var mı? Giriş Yap', AppLanguage.en: 'Already have an account? Sign In'},
      'verification_sent_title': {AppLanguage.tr: 'Doğrulama E-postası Gönderildi 📬', AppLanguage.en: 'Verification Email Sent 📬'},
      'verification_sent_desc': {AppLanguage.tr: 'E-posta adresinize doğrulama bağlantısı gönderildi. Lütfen gelen kutunuzu kontrol edip bağlantıya tıklayın.', AppLanguage.en: 'A verification link has been sent to your email. Please check your inbox and click the link.'},
      'resend_verification': {AppLanguage.tr: 'Doğrulama E-postasını Tekrar Gönder 📬', AppLanguage.en: 'Resend Verification Email 📬'},
      'minutes_unit': {AppLanguage.tr: 'dk', AppLanguage.en: 'min'},
      'points_unit': {AppLanguage.tr: 'puan', AppLanguage.en: 'pts'},

      // --- Puan/AppBar ---
      'points_caption': {AppLanguage.tr: 'PUAN', AppLanguage.en: 'POINTS'},

      // --- Timer: Pause dialogs ---
      'pause_used_snackbar': {AppLanguage.tr: '1/1 Duraklatma hakkını kullandın! Tekrar durduramazsın.', AppLanguage.en: "You've used your 1/1 pause credit! You can't pause again."},
      'pause_limit_title': {AppLanguage.tr: 'Duraklatma Hakkın Bitti!', AppLanguage.en: 'Pause Limit Reached!'},
      'pause_limit_content': {AppLanguage.tr: 'Bu seans boyunca 1 defalık duraklatma hakkını zaten kullandın.\n\nŞimdi durdurursan seans ilerlemen tamamen sıfırlanacak.', AppLanguage.en: "You've already used your one-time pause for this session.\n\nIf you stop now, your session progress will be completely reset."},
      'reset_and_stop': {AppLanguage.tr: 'Sıfırla & Durdur', AppLanguage.en: 'Reset & Stop'},
      'continue_btn': {AppLanguage.tr: 'Devam Et', AppLanguage.en: 'Continue'},
      'session_reset': {AppLanguage.tr: 'Seans ilerlemen sıfırlandı.', AppLanguage.en: 'Your session progress has been reset.'},

      // --- Reports Screen ---
      'daily_goal_label': {AppLanguage.tr: 'Günlük Hedef', AppLanguage.en: 'Daily Goal'},
      'set_daily_goal_title': {AppLanguage.tr: 'Günlük Hedef Belirle', AppLanguage.en: 'Set Daily Goal'},
      'set_daily_goal_sub': {AppLanguage.tr: 'Bugün kaç Pomodoro tamamlamak istiyorsun?', AppLanguage.en: 'How many Pomodoros do you want to complete today?'},
      'save_goal_btn': {AppLanguage.tr: 'Hedefi Kaydet', AppLanguage.en: 'Save Goal'},
      'efficiency_score_caption': {AppLanguage.tr: 'VERİMLİLİK SKORU', AppLanguage.en: 'EFFICIENCY SCORE'},
      'efficiency_msg_exceeded': {AppLanguage.tr: 'Hedefini aştın, harikasın! 🔥', AppLanguage.en: 'You exceeded your goal, amazing! 🔥'},
      'efficiency_msg_close': {AppLanguage.tr: 'Hedefe yaklaşıyorsun!', AppLanguage.en: "You're getting close to your goal!"},
      'efficiency_msg_low': {AppLanguage.tr: 'Bugün biraz daha çalışabilirsin', AppLanguage.en: 'You could study a bit more today'},
      'today_studies_header': {AppLanguage.tr: 'Bugünkü Çalışmalar', AppLanguage.en: "Today's Studies"},
      'details_link': {AppLanguage.tr: 'Detaylar', AppLanguage.en: 'Details'},
      'weekly_dist_title': {AppLanguage.tr: 'Bugünün Dağılımı', AppLanguage.en: "Today's Distribution"},
      'weekly_dist_sub': {AppLanguage.tr: 'Bugünün özeti', AppLanguage.en: 'Summary of today'},
      'month_intensity_suffix': {AppLanguage.tr: 'Yoğunluğu', AppLanguage.en: 'Intensity'},
      'heatmap_less': {AppLanguage.tr: 'Az', AppLanguage.en: 'Less'},
      'heatmap_more': {AppLanguage.tr: 'Çok', AppLanguage.en: 'More'},
      'topic_comparison_title': {AppLanguage.tr: 'Konu Karşılaştırması', AppLanguage.en: 'Topic Comparison'},
      'weekly_summary_title': {AppLanguage.tr: 'Haftalık Özet', AppLanguage.en: 'Weekly Summary'},
      'new_week_label': {AppLanguage.tr: 'Yeni', AppLanguage.en: 'New'},
      'week_day_breakdown_title': {AppLanguage.tr: 'Gün Gün Döküm', AppLanguage.en: 'Day-by-Day Breakdown'},
      'no_study_this_day': {AppLanguage.tr: 'Bu gün çalışma yok', AppLanguage.en: 'No study this day'},
      'hour_toggle': {AppLanguage.tr: 'Saat', AppLanguage.en: 'Hours'},
      'total_label': {AppLanguage.tr: 'Toplam', AppLanguage.en: 'Total'},
      'efficiency_tip_header': {AppLanguage.tr: 'Verimlilik İpucu', AppLanguage.en: 'Efficiency Tip'},
      'hour_abbr': {AppLanguage.tr: 'sa', AppLanguage.en: 'h'},
      'min_abbr': {AppLanguage.tr: 'dk', AppLanguage.en: 'm'},
      'tip_1': {AppLanguage.tr: 'Sabah saatlerinde matematik çalışmak odaklanma kapasiteni %15 artırıyor.', AppLanguage.en: 'Studying math in the morning increases your focus capacity by 15%.'},
      'tip_2': {AppLanguage.tr: 'Her 25 dakikalık odaklanma seansından sonra 5 dakika mola ver.', AppLanguage.en: 'Take a 5-minute break after every 25-minute focus session.'},
      'tip_3': {AppLanguage.tr: 'Günde 4 pomodoro tamamlamak düzenli çalışma alışkanlığı oluşturur.', AppLanguage.en: 'Completing 4 pomodoros a day builds a consistent study habit.'},
      'tip_4': {AppLanguage.tr: 'Zorlu konuları sabah saatlerinde çalışmak verimliliği artırır.', AppLanguage.en: 'Studying difficult topics in the morning improves productivity.'},

      // --- History Screen (Çalışma Geçmişi) ---
      'weekly_trend_caption': {AppLanguage.tr: 'HAFTALIK TREND', AppLanguage.en: 'WEEKLY TREND'},
      'weekly_efficiency_caption': {AppLanguage.tr: 'HAFTALIK VERİMLİLİK', AppLanguage.en: 'WEEKLY EFFICIENCY'},
      'eff_normal': {AppLanguage.tr: 'Normal', AppLanguage.en: 'Normal'},
      'eff_high': {AppLanguage.tr: 'Yüksek', AppLanguage.en: 'High'},
      'eff_very_high': {AppLanguage.tr: 'Çok Yüksek', AppLanguage.en: 'Very High'},
      'total_focus_label': {AppLanguage.tr: 'Toplam\nOdaklanma', AppLanguage.en: 'Total\nFocus'},
      'most_efficient_day_label': {AppLanguage.tr: 'En Verimli Gün', AppLanguage.en: 'Most Efficient Day'},
      'weekly_analysis_caption': {AppLanguage.tr: 'HAFTALIK ANALİZ', AppLanguage.en: 'WEEKLY ANALYSIS'},
      'top_subjects_label': {AppLanguage.tr: 'En Çok Çalışılan Dersler', AppLanguage.en: 'Most Studied Subjects'},
    };

    final localizedMap = translations[key];
    if (localizedMap == null) return key;
    return localizedMap[_currentLanguage] ?? localizedMap[AppLanguage.tr] ?? key;
  }
}
