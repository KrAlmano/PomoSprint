# Pomodoro App - Proje Bağlamı ve Teknik Dokümantasyon (AI Handoff)

Bu belge, projeyi inceleyen geliştiricilerin veya diğer Yapay Zeka (AI) asistanlarının uygulamanın ne işe yaradığını, tüm ekranlarını, fonksiyonlarını ve uçtan uca mimarisini saniyeler içinde kavraması için hazırlanmıştır.

## 1. Proje Özeti ve Genel İş Akışı (Uçtan Uca)
Bu proje, kullanıcıların odaklanma sürelerini (Pomodoro tekniği) ölçen, çalışmalarını kategorize eden, istatistiklerini tutan ve oyunlaştırma (gamification - liderlik tablosu, karakter kilitleri) unsurları barındıran **Flutter** tabanlı bir mobil uygulamadır.

**Uygulama İçi Kullanıcı Akışı:**
1. **Açılış (Splash):** Kullanıcı uygulamayı açar, `SplashScreen` Supabase'de aktif oturum (session) var mı diye kontrol eder.
2. **Kimlik Doğrulama (Auth):** Oturum yoksa kullanıcı `LoginScreen`'e yönlendirilir. E-posta/şifre veya Google Sign-In ile giriş yapar.
3. **Zamanlayıcı (Timer):** Giriş sonrası ana ekran `TimerScreen`'dir. Kullanıcı çalışmak istediği dersi (`CategoriesScreen` üzerinden) seçer ve pomodoro sayacını başlatır.
4. **Çalışmanın Kaydedilmesi:** Sayaç sıfırlandığında, çalışılan süre `study_sessions` tablosuna kaydedilir ve kullanıcının `profiles` tablosundaki toplam puanı & çalışma süresi (`increment_user_stats` fonksiyonu aracılığıyla) artırılır.
5. **Raporlama ve Oyunlaştırma:** Kullanıcı `ReportsScreen`'de detaylı analizlerini görür. Kazandığı puanlarla `CharacterCollectionScreen`'de yeni avatarların kilidini açar ve `RankingScreen`'de global liderlik tablosunda yer edinir.

---

## 2. Teknoloji Yığını ve Klasör Mimarisi
- **Frontend:** Flutter (Dart)
- **Backend, DB & Auth:** Supabase (PostgreSQL, Supabase Auth)
- **Mimari:** Servis tabanlı Singleton mimarisi (`SupabaseService` her şeyin merkezindedir).

---

## 3. Ekranlar (Screens) ve İşlevleri
Tüm ekranlar `lib/screens/` dizini altındadır:

1. **`splash_screen.dart`:**
   - **Görevi:** Uygulama açılışında gösterilen logo ekranıdır.
   - **Mekanizma:** Supabase'in `auth.currentSession` değerini kontrol eder. Oturum varsa doğrudan ana ekrana (`TimerScreen`), yoksa giriş ekranına yönlendirir.

2. **`login_screen.dart` & `register_screen.dart`:**
   - **Görevi:** Kullanıcı giriş ve kayıt işlemlerini yürütür.
   - **Mekanizma:** `SupabaseService` üzerinden email/password ile üyelik veya `google_sign_in` paketiyle Google OAuth işlemini tetikler.

3. **`timer_screen.dart`:**
   - **Görevi:** Uygulamanın en temel "Ana" ekranıdır. Pomodoro sayacı burada çalışır.
   - **Mekanizma:** 25 dk çalışma, 5 dk mola gibi süreçleri sayar. Süre bittiğinde Supabase'e oturum kaydını (`saveStudySession`) atar ve kullanıcı profil istatistiklerini günceller.

4. **`categories_screen.dart`:**
   - **Görevi:** Kullanıcının çalışma başlıklarını (ör: Matematik, Yazılım, İngilizce) yönettiği ekrandır.
   - **Mekanizma:** Supabase'deki `categories` tablosundan sadece kullanıcının kendi (`auth.uid() = user_id`) kategorilerini okur/yazar (RLS ile korunur).

5. **`history_screen.dart`:**
   - **Görevi:** Kullanıcının tamamladığı geçmiş Pomodoro seanslarının listesini (Timeline) sunar.
   - **Mekanizma:** `study_sessions` tablosundan verileri tarihe göre sıralı çeker.

6. **`reports_screen.dart`:**
   - **Görevi:** İstatistiklerin (haftalık/aylık çalışma, en çok odaklanılan dersler vb.) görselleştirildiği analiz ekranıdır.
   - **Mekanizma:** Grafik kütüphaneleri kullanarak (bar chart, pie chart vb.) `study_sessions` verisini derler ve özetler.

7. **`ranking_screen.dart`:**
   - **Görevi:** Tüm kullanıcılar arasındaki "Liderlik Tablosu" (Leaderboard).
   - **Mekanizma:** `profiles` tablosundan en yüksek puanlı veya en çok süre çalışan kullanıcıları çeker. RLS sayesinde kullanıcıların "email" veya özel bilgileri değil, sadece açık "username", "avatar" ve "puan" bilgileri görünür kılınmıştır.

8. **`character_collection_screen.dart`:**
   - **Görevi:** Oyunlaştırma unsuru. Belirli seviye veya puan baremleri aşıldığında kilidi açılan profil avatarlarının / rozetlerinin listelendiği koleksiyon ekranı.

9. **`profile_screen.dart`:**
   - **Görevi:** Ayarlar, mevcut puan durumu, kullanıcı adı ve şifre/çıkış (Sign Out) işlemlerinin yapıldığı ekran.

10. **`database_inspector_screen.dart`:**
    - **Görevi:** Geliştiricilerin test sürecinde Supabase içindeki tabloları kolayca izleyebilmesi için oluşturulmuş bir "Debug/Geliştirici" kontrol panelidir.

---

## 4. Servisler (Services) Katmanı
Tüm dış iletişim bu katmandan (`lib/services/`) geçer:

1. **`supabase_service.dart` (EN KRİTİK DOSYA):**
   - **Görevi:** Uygulama ile Supabase (Veritabanı ve Kimlik Doğrulama) arasındaki köprüdür.
   - **İçerik:** `signInWithGoogle`, `saveStudySession`, `loadCategories` gibi projede veritabanıyla konuşan **bütün** metotlar bu dosyadadır. Veri çekme/yazma işlemi asla ekranların içine doğrudan yazılmaz, her zaman bu sınıftaki bir metot çağrılır.

2. **`language_service.dart`:**
   - **Görevi:** Uygulamanın çoklu dil (i18n / Yerelleştirme) desteğini yönetir. Kullanıcının seçtiği dile göre metinlerin anlık değişmesini sağlar.

3. **`database_helper.dart`:**
   - **Görevi:** Supabase entegrasyonu öncesinde yerel (local) veritabanı veya önbellekleme süreçleri için yazılmış yardımcı bir sınıftır.

---

## 5. Modeller (Models) Katmanı
Supabase'den dönen JSON verilerinin Dart objelerine dönüştürüldüğü sınıflardır (`lib/models/`):

- **`user_model.dart`:** `profiles` tablosunu yansıtır (id, username, total_minutes, current_points, avatar_id).
- **`category_model.dart`:** `categories` tablosunu yansıtır (id, name, color, user_id).
- **`study_session.dart`:** `study_sessions` tablosunu yansıtır (id, user_id, category_id, duration_minutes, start_time).
- **`avatar_model.dart`:** Puan ile kilidi açılan avatarların özelliklerini tutar.

---

## 6. Veritabanı (Supabase) ve Güvenlik (RLS) Durumu
Uygulamanın veri güvenliği doğrudan PostgreSQL katmanında, **Row Level Security (RLS)** ile sağlanır.
- **Kişisel Veri Koruması:** `study_sessions` ve `categories` tablolarında kesin bir `user_id = auth.uid()` kuralı vardır. Bir kullanıcı istese bile kod değiştirerek başkasının çalışma kayıtlarını göremez, silemez.
- **RPC Fonksiyonları:** Supabase'de `increment_user_stats` isimli bir Stored Procedure (RPC) mevcuttur. Puan hesaplaması client'ta (telefonda) değil, güvenli bir şekilde sunucuda işlenir (3 parametreli: `added_minutes, added_points, local_date_str`).
- **Google Sign-In Nonce Bypass:** iOS cihazlarda `google_sign_in` paketinin `nonce` göndermemesi sebebiyle Supabase'in "Skip nonce checks" güvenlik ayarı Google provider için açık (true) bırakılmıştır. Aksi takdirde iOS'te Google OAuth çalışmaz.
- **Sadeleştirme:** Geçmişteki "Sanal Kütüphane / Arkadaşlık" gibi sosyal özelliklerin tüm kodları ve veritabanı tabloları (`friendships`, `table_seats` vb.) güvenlik ve odaklanma amacıyla tamamen silinmiştir.

---

## 7. Gelecek Geliştirmeler ve AI Asistanları İçin Notlar
Eğer bu projede bir geliştirme yapacaksan:
- **Her Şey RLS ile Korunmalıdır:** Yeni bir tablo eklendiğinde MUTLAKA `user_id` kolonu ekle ve ilgili RLS politikasını eklemeden kodu yayına alma. `USING(true)` kullanma.
- **Test Verisi Temizliği:** Eğer test amacıyla (özellikle `reports_screen` tasarımı veya filtreleme testleri için) veritabanına dummy (sahte) veriler basarsan, görevin bitiminde test hesabındaki bu hayalet verileri mutlak suretle temizle.
- **UI Prensipleri:** Kullanıcı modern, göze hitap eden, hafif animasyonlu ve "Premium" hissiyatı veren arayüzleri seviyor. Placeholder, kaba tasarımlar veya ilkel renk paletlerinden kesinlikle kaçın.
- **Merkezi Veri Yönetimi:** Yeni bir veri okuma/yazma gereksiniminde ekran içinden Supabase'i direkt çağırma. Gidip `supabase_service.dart` içine bir fonksiyon ekle ve ekran (UI) kodundan sadece o fonksiyonu çağır.
