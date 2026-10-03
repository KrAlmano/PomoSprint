# Denetim Bulguları — Tam Liste (3 Ekim 2026)

Her bulgu ayrı bir ajan tarafından kodda çürütülmeye çalışıldı; aşağıdakiler doğrulananlar ve doğrulayıcıların ek bulgularıdır (V ile biten id). Durum sütunu düzeltme ajanlarının raporuna dayanır. "Kısmen" olanların bir kısmı aynı gün başka paket ya da canlı DB migration'ı ile tamamlandı; güncel durum için ana rapora bakın.

**Toplam:** 245 bulgu — 🔴 7 kritik, 🟠 28 yüksek, 🟡 112 orta, ⚪ 98 düşük. Durum: ✅ 193 düzeltildi, 🟨 30 kısmen, ⏸ 4 yapılmadı, ❔ 18 ayrı kayıt yok (çoğu başka bir bulguyla birlikte kapandı).

## TIMER — Sayaç, kabuk, bildirimler (32)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| TIMER-01 | 🔴 | Çalışan seans yalnızca bellekte; uygulama arka planda öldürülürse seans ve puan tamamen kayboluyor | `lib/screens/timer_screen.dart:47-67` | ✅ Düzeltildi |
| TIMER-02 | 🟠 | Android'de seans bitiş bildirimi hiç gösterilmiyor: receiver tanımlı değil, Android 13+ bildirim izni hiç istenmiyor | `android/app/src/main/AndroidManifest.xml:1-42` | ✅ Düzeltildi |
| TIMER-04 | 🟠 | Kategori yönetiminde yapılan ekleme/düzenleme/arşivleme Timer ekranına yansımıyor | `lib/screens/profile_screen.dart:315-321` | ✅ Düzeltildi |
| TIMER-V01 | 🟠 | Avatar 'açık' kontrolü bakiyeye bakıyor: satın alma akışı erişilemez, sahipsiz avatar 'kuşanılıyor' ama sunucu reddediyor | `lib/models/avatar_model.dart:39-47` | ✅ Düzeltildi |
| TIMER-V02 | 🟠 | Çevrimdışı kuyruktaki birden fazla seans senkronda tek tek 'overlap' ile siliniyor (completed_at = sunucu now()) | `supabase/migrations/20260809025000_social_feed_up.sql:140-149` | 🟨 Kısmen |
| TIMER-V05 | 🟠 | Android'de ana ekranda geri tuşu Flutter engine'i yok ediyor; çalışan seans uyarısız kayboluyor | `lib/main.dart:794-1104` | ✅ Düzeltildi |
| TIMER-03 | 🟡 | 3-2-1 geri sayımında Android geri tuşu/jesti BAŞLAT düğmesini kalıcı olarak kilitliyor | `lib/screens/timer_screen.dart:200-205` | ✅ Düzeltildi |
| TIMER-05 | 🟡 | Soğuk açılış ve token yenilemede açılmış avatarlar siliniyor; satın alınmış/lig ödülü avatarlar kilitli görünüyor | `lib/screens/splash_screen.dart:132-159` | ✅ Düzeltildi |
| TIMER-06 | 🟡 | Kuyruktaki çevrimdışı seans, yeni seans önce gönderilirse 'overlap' ile sessizce siliniyor | `lib/main.dart:627-636` | ✅ Düzeltildi |
| TIMER-07 | 🟡 | Yer tutucu (UUID olmayan) kategoriyle biten çevrimiçi seans kalıcı olarak kayboluyor | `lib/main.dart:136-143` | ✅ Düzeltildi |
| TIMER-08 | 🟡 | Kategori listesi yenilenince süren/duraklatılmış seansın kategorisi sessizce değişiyor | `lib/screens/timer_screen.dart:143-156` | ✅ Düzeltildi |
| TIMER-09 | 🟡 | Açılışta kuyruk senkronu başarılı olsa da profil (puan/kum/dakika) tazelenmiyor | `lib/main.dart:210-211` | ✅ Düzeltildi |
| TIMER-10 | 🟡 | Karanlık mod kalıcı değil ve Profil'deki anahtar eski değeri gösteriyor | `lib/main.dart:67-72` | ✅ Düzeltildi |
| TIMER-11 | 🟡 | Profil'deki 'Bildirimler' anahtarı hiçbir şeye bağlı değil | `lib/screens/profile_screen.dart:57-58` | ✅ Düzeltildi |
| TIMER-12 | 🟡 | iOS'ta bildirim izni, UI başlamadan önce main() içinde isteniyor ve runApp'i bloke ediyor; init hataları Sentry'ye ulaşmıyor | `lib/main.dart:46-56` | ✅ Düzeltildi |
| TIMER-13 | 🟡 | Splash'te getAvatars zaman aşımsız; kötü ağda açılış dakikalarca takılabiliyor | `lib/screens/splash_screen.dart:89-100` | ✅ Düzeltildi |
| TIMER-14 | 🟡 | Seri (streak) hesabı istemcide iki kopya, sunucudan farklı gün sınırı kullanıyor ve önbelleğe yazılmıyor | `lib/screens/splash_screen.dart:141-150` | ✅ Düzeltildi |
| TIMER-15 | 🟡 | Avatar kuşanma iki kez RPC çağırıyor, hata yutulduğu için geri alma kodu ölü | `lib/main.dart:504-536` | ✅ Düzeltildi |
| TIMER-16 | 🟡 | IndexedStack tüm sekmeleri açılışta kurup canlı tutuyor; görünmeyen sekmelerde sürekli ağ/CPU tüketimi | `lib/main.dart:593-783` | ✅ Düzeltildi |
| TIMER-17 | 🟡 | Android'de seans arka planda biterse cancelAll az önce gelen/gelecek bitiş bildirimini siliyor | `lib/screens/timer_screen.dart:97-113` | ✅ Düzeltildi |
| TIMER-18 | 🟡 | Cihaz saati 3 dk'dan fazla ileriyse her seans kalıcı olarak reddedilip siliniyor | `lib/screens/timer_screen.dart:232-238` | 🟨 Kısmen |
| TIMER-20 | 🟡 | iOS Info.plist'te UIApplicationSceneManifest yok; SceneDelegate ölü ve UIScene yaşam döngüsü zorunluluğu karşılanmıyor | `ios/Runner/Info.plist:1-82` | ✅ Düzeltildi |
| TIMER-23 | 🟡 | main.dart 1106 satır: iş mantığı, üç kopya yönlendirme kapısı ve 310 satırlık build | `lib/main.dart:89-109` | ✅ Düzeltildi |
| TIMER-27 | 🟡 | PROJECT_CONTEXT.md sayaç/splash/servis bölümleri koda uymuyor ve AI'ı yanlış yönlendiriyor | `PROJECT_CONTEXT.md:11` | ❔ |
| TIMER-V03 | 🟡 | Herkese açık global 'ranking_updates' broadcast kanalı: her seans tüm çevrimiçi istemcilerde sıralama sorgusu tetikliyor, kanal spam'e açık | `lib/services/supabase_service.dart:830-871` | ✅ Düzeltildi |
| TIMER-V04 | 🟡 | syncPendingSessions kuyruğu başta okuyup sonda tamamen üzerine yazıyor; senkron sürerken eklenen seans siliniyor | `lib/services/supabase_service.dart:700-719` | ✅ Düzeltildi |
| TIMER-19 | ⚪ | TimerScreen dispose olurken zamanlanmış bildirim ve sunucudaki 'şu an çalışıyor' kaydı temizlenmiyor | `lib/screens/timer_screen.dart:76-81` | ✅ Düzeltildi |
| TIMER-21 | ⚪ | iOS yapılandırmasında yanlış/işlevsiz anahtarlar: 3 adet NSSupportsLiveActivities, geçersiz NSUserNotificationsUsageDescription, eksik bildirim delegesi | `ios/Runner/Info.plist:5-6` | ✅ Düzeltildi |
| TIMER-22 | ⚪ | Duraklat-devam sonrası 'şu an çalışıyor' bitiş zamanı tam süreyle yeniden yazılıyor | `lib/screens/timer_screen.dart:244` | ✅ Düzeltildi |
| TIMER-24 | ⚪ | Alan genelinde ölü kod ve yanıltıcı parametreler | `lib/screens/onboarding_screen.dart:1-458` | ✅ Düzeltildi |
| TIMER-25 | ⚪ | Bildirim metni ve 'KUM' rozeti yalnızca Türkçe; alanda üç farklı yerelleştirme mekanizması | `lib/services/notification_service.dart:79-81` | ✅ Düzeltildi |
| TIMER-26 | ⚪ | `isVerified` adlı parametre aslında ön plan saniyesi; Android'de arka plan süresini de sayıyor | `lib/screens/timer_screen.dart:15` | ✅ Düzeltildi |

## DATA — Veri katmanı (28)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| DATA-01 | 🔴 | Avatar önbelleği boşken ana ekran StateError ile çöküyor (çevrimdışı soğuk açılış) | `lib/models/avatar_model.dart:56-64` | ✅ Düzeltildi |
| DATA-02 | 🔴 | Çevrimdışı kuyruktaki 2. ve sonraki seanslar sunucunun 'overlap' kontrolüyle sessizce siliniyor | `supabase/migrations/20260809025000_social_feed_up.sql:140-149` | 🟨 Kısmen |
| DATA-03 | 🟠 | Yer tutucu kategoriyle tamamlanan çevrimiçi seans kalıcı hata sayılıp kayboluyor; kategorisiz hesap bundan hiç çıkamıyor | `lib/services/supabase_service.dart:613-631` | ✅ Düzeltildi |
| DATA-04 | 🟠 | isUnlocked 'yetecek bakiye' ile 'satın alınmış' arasında ayrım yapmıyor; avatar takma hataları yutuluyor | `lib/models/avatar_model.dart:39-47` | ✅ Düzeltildi |
| DATA-05 | 🟠 | UserModel 4 farklı yerde 4 farklı şekilde kuruluyor: açılmış avatarlar her açılışta ve saatlik token yenilemede siliniyor, seri tutarsız | `lib/services/supabase_service.dart:22-36` | ✅ Düzeltildi |
| DATA-06 | 🟠 | Kategori yönetim ekranındaki değişiklikler Timer'daki kategori listesine yansımıyor; paralel ve ölü bir ekle/sil yolu duruyor | `lib/screens/profile_screen.dart:316-320` | ✅ Düzeltildi |
| DATA-07 | 🟡 | Herkese açık 'ranking_updates' yayını, dünyadaki her seans tamamlanmasında tüm istemcilerin tüm geçmişi yeniden çekmesine yol açıyor | `lib/services/supabase_service.dart:826-871` | ✅ Düzeltildi |
| DATA-08 | 🟡 | syncPendingSessions sırasında eklenen seans, senkronun yazdığı eski anlık görüntüyle eziliyor | `lib/services/supabase_service.dart:742` | ✅ Düzeltildi |
| DATA-09 | 🟡 | Seans önce kalıcı depoya yazılmıyor ve RPC'de zaman aşımı yok: istek askıdayken uygulama kapanırsa seans kaybolur | `lib/services/supabase_service.dart:613-644` | ✅ Düzeltildi |
| DATA-10 | 🟡 | Cihaz saati 3 dk'dan fazla ileriyse tüm seanslar kalıcı olarak reddediliyor; kuyrukta saat dilimi bilgisi saklanmıyor | `lib/screens/timer_screen.dart:120` | 🟨 Kısmen |
| DATA-11 | 🟡 | Kalıcı/geçici hata sınıflandırmasında boşluklar; reddedilen seanslar kullanıcıya hiç bildirilmiyor | `lib/services/supabase_service.dart:694-698` | ✅ Düzeltildi |
| DATA-12 | 🟡 | updateUserName e-postaya göre filtreliyor ve hatayı yutuyor; isim kaydedilmese de 'başarılı' gösteriliyor | `lib/services/supabase_service.dart:566-584` | ✅ Düzeltildi |
| DATA-13 | 🟡 | StudySession.createdAt = completed_at: çevrimdışı seanslar senkron gününde görünüyor, gün sınırı sunucuyla uyuşmuyor | `lib/models/study_session.dart:9` | ✅ Düzeltildi |
| DATA-14 | 🟡 | fetchStudySessions sınırsız: tüm geçmiş her seferinde çekiliyor ve 1000 satırdan sonra sessizce kesiliyor | `lib/services/supabase_service.dart:807-824` | ✅ Düzeltildi |
| DATA-15 | 🟡 | Profil okuma anlık hata verirse mevcut kullanıcı Google girişinde yeniden onboarding'e sokuluyor; e-posta girişinde oturum açılmış olsa da hata gösteriliyor | `lib/services/supabase_service.dart:341-354` | ✅ Düzeltildi |
| DATA-16 | 🟡 | Arkadaş listesi diğer kullanıcıların profillerini doğrudan tablodan okuyor; repoda olmayan RLS'e bağımlı ve ilişki yönü sunucu RPC'leriyle tutarsız | `lib/services/supabase_service.dart:1135-1186` | ✅ Düzeltildi |
| DATA-17 | 🟡 | 'Aylık' sıralama sekmesi tüm zamanların puanını gösteriyor; kendi satırı isimle eşleştirildiği için aynı isimli kullanıcı listeden siliniyor | `lib/services/supabase_service.dart:439-453` | ✅ Düzeltildi |
| DATA-18 | 🟡 | Kullanıcıya özel önbellek ve durum çıkışta veya hesap silmede temizlenmiyor: hesap değişince veri sızıyor, silinen hesabın kategorileri geri geliyor | `lib/services/supabase_service.dart:875-913` | ✅ Düzeltildi |
| DATA-19 | 🟡 | 1460 satırlık SupabaseService: enjekte edilemiyor, test edilemiyor, 3 farklı hata politikası var, ekranlar servisi atlıyor | `lib/services/supabase_service.dart:20-1461` | ✅ Düzeltildi |
| DATA-20 | 🟡 | PROJECT_CONTEXT.md veri katmanını yanlış anlatıyor (var olmayan metodlar/ekranlar, yanlış model alanları) | `PROJECT_CONTEXT.md:29` | ❔ |
| DATA-V01 | 🟡 | Onboarding'de seçilen günlük hedef (daily_goal_minutes) hiçbir yerde kullanılmıyor; raporlar cihaz genelinde ayrı bir yerel hedef kullanıyor | `lib/screens/post_auth_onboarding_screen.dart:31` | ✅ Düzeltildi |
| DATA-V02 | 🟡 | Çalışan seansın kategorisi, kategori listesi yenilenince sessizce değişiyor ve seans yanlış kategoriye kaydediliyor | `lib/screens/timer_screen.dart:144-156` | ✅ Düzeltildi |
| DATA-21 | ⚪ | Başarısız işlemler başarılıymış gibi davranıyor (sessiz no-op ve yutulan hatalar) | `lib/services/supabase_service.dart:530-543` | ✅ Düzeltildi |
| DATA-22 | ⚪ | Servis katmanında sabit Türkçe metinler ve ham exception metni kullanıcıya gösteriliyor | `lib/services/supabase_service.dart:259` | ✅ Düzeltildi |
| DATA-23 | ⚪ | Veri katmanında birikmiş ölü kod | `lib/services/supabase_service.dart:362-432` | ✅ Düzeltildi |
| DATA-24 | ⚪ | Model tutarsızlıkları: toMap/fromMap asimetrisi, gereksiz state, yanlış ikon kodu, 4 kopya hex ayrıştırma | `lib/models/user_model.dart:29` | ✅ Düzeltildi |
| DATA-25 | ⚪ | Varsayılan avatar 4 yerde farklı; Google ve e-posta yedeği 200 coin'lik ücretli avatarı bedavaya takıyor | `lib/services/supabase_service.dart:255` | ✅ Düzeltildi |
| DATA-26 | ⚪ | Sıralama değişikliği kategori başına ayrı istek atıyor ve atomik değil; 8/15 limiti 4 yerde kopyalanmış | `lib/services/supabase_service.dart:1446-1458` | ✅ Düzeltildi |

## STATS — İstatistik ekranları (21)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| STATS-01 | 🟠 | İstatistik ekranları global broadcast kanalını dinliyor: herhangi bir kullanıcının seansı, tüm istemcilerde tüm geçmişin yeniden çekilmesine yol açıyor | `lib/services/supabase_service.dart:830-839` | ✅ Düzeltildi |
| STATS-V01 | 🟠 | Repodaki complete_study_session overlap kontrolü completed_at=now() ile karşılaştırıyor: çevrimdışı kuyruktaki 2. ve sonraki seanslar ile senkron sırasında devam eden seans sessizce kayboluyor | `supabase/migrations/20260809025000_social_feed_up.sql:140-148` | 🟨 Kısmen |
| STATS-02 | 🟡 | Aylık hafta kovaları Duration(days: 7) ile ilerliyor: DST'li saat dilimlerinde haftalar kayıyor, gün kayboluyor | `lib/screens/monthly_tracking_screen.dart:143-152` | ✅ Düzeltildi |
| STATS-03 | 🟡 | Aylık hafta kartlarındaki % değişim, kırpılmış veya devam eden haftayı tam bir önceki haftayla kıyaslıyor | `lib/screens/monthly_tracking_screen.dart:128-132` | ✅ Düzeltildi |
| STATS-04 | 🟡 | Gün sınırı ve tarih alanı sunucuyla tutarsız: istemci completed_at ve gece yarısı, sunucu started_at ve 04:00 kullanıyor | `lib/models/study_session.dart:32` | ✅ Düzeltildi |
| STATS-05 | 🟡 | Günlük hedef üç ayrı ve senkronize olmayan kaynakta: onboarding, SharedPreferences ve iki ekran kopyası | `lib/screens/reports_screen.dart:28` | ✅ Düzeltildi |
| STATS-06 | 🟡 | Günlük sekme, deneyimli kullanıcıya her sabah 'Henüz detaylı raporun yok' gösteriyor ve hedef kartını gizliyor | `lib/screens/reports_screen.dart:249-252` | ✅ Düzeltildi |
| STATS-07 | 🟡 | fetchStudySessions hataları yutup [] döndürüyor: ağ hatasında ekranlar 'veri yok' gösteriyor ve yüklenmiş veriyi siliyor | `lib/services/supabase_service.dart:807-824` | ✅ Düzeltildi |
| STATS-08 | 🟡 | Gece yarısından sonra 'bugün' ve 'bu hafta' bayat kalıyor; Haftalık sekme seans bitince güncellenmiyor | `lib/screens/reports_screen.dart:52-62` | ✅ Düzeltildi |
| STATS-16 | 🟡 | İstatistik mantığı ve UI parçaları ekranlar arasında kopyalanmış; kopyalar farklı sonuç üretiyor | `lib/screens/reports_screen.dart:396-586` | ✅ Düzeltildi |
| STATS-09 | ⚪ | Aylık çizgi grafik tüm kategorileri çiziyor ama lejant ve renkler yalnızca ilk 6 kategori için | `lib/screens/monthly_tracking_screen.dart:172-177` | ✅ Düzeltildi |
| STATS-10 | ⚪ | Kategori renk, ikon ve ad gösterimi sekmeler arasında tutarsız; arşivlenmiş kategoriler aylıkta farklı renkte | `lib/screens/reports_screen.dart:104-120` | ✅ Düzeltildi |
| STATS-11 | ⚪ | 'En Verimli Gün' kartında sabit %85 ilerleme çubuğu ve 60 dakikanın altında '0sa' gösterimi | `lib/screens/history_screen.dart:557-566` | ✅ Düzeltildi |
| STATS-12 | ⚪ | Donut kartındaki 'Saat / %' anahtarı işlevsiz bir süs | `lib/screens/reports_screen.dart:860-904` | ✅ Düzeltildi |
| STATS-13 | ⚪ | Aylık sekme her yenilemede tam ekran spinner'a dönüyor ve kaydırma konumu sıfırlanıyor | `lib/screens/monthly_tracking_screen.dart:70` | ✅ Düzeltildi |
| STATS-14 | ⚪ | Seans sorgusu user_id filtresi ve limit olmadan çalışıyor; study_sessions SELECT RLS'i repoda ve testte yok | `lib/services/supabase_service.dart:807-818` | ✅ Düzeltildi |
| STATS-15 | ⚪ | İstatistik ekranlarında sabit TR/EN metinler, locale'e uymayan yüzde biçimi ve Türkçe 'Diğer' yedeği | `lib/screens/monthly_tracking_screen.dart:197-204` | ✅ Düzeltildi |
| STATS-17 | ⚪ | İstatistik alanında ölü parametre, ölü dal ve ölü catch blokları | `lib/screens/history_screen.dart:12-19` | ✅ Düzeltildi |
| STATS-18 | ⚪ | Grafikler ekran okuyucuya hiçbir bilgi vermiyor | `lib/screens/history_screen.dart:281-318` | ✅ Düzeltildi |
| STATS-19 | ⚪ | PROJECT_CONTEXT.md istatistik ekranlarını ve modeli yanlış tarif ediyor | `PROJECT_CONTEXT.md:43-49` | ❔ |
| STATS-20 | ⚪ | Çevrimdışı kuyruktaki seanslar istatistiklerde ve günlük hedef ilerlemesinde görünmüyor | `lib/services/supabase_service.dart:700-722` | ✅ Düzeltildi |

## SOCIAL — Sıralama, lig, sosyal, profil (33)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| SOCIAL-01 | 🔴 | Avatar kataloğu önbelleği boşken tüm avatar yardımcıları çöküyor: çevrimdışı açılışta ana ekran gri kalıyor | `lib/models/avatar_model.dart:56-64` | ✅ Düzeltildi |
| SOCIAL-V01 | 🔴 | Avatar kataloğu oturumsuz (anon) çekiliyor ve girişten sonra hiç tazelenmiyor: yeni kurulumda girişten sonra ana ekran çöküyor | `lib/screens/splash_screen.dart:89-100` | ✅ Düzeltildi |
| SOCIAL-02 | 🟠 | Repodaki son process_weekly_leagues tanımı bozuk: haftalık lig işlemi her çalışmada hata verir, terfi/düşme/sıfırlama hiç olmaz | `supabase/migrations/20260809025000_social_feed_up.sql:412-493` | 🟨 Kısmen |
| SOCIAL-03 | 🟠 | Avatar kilit mantığı 'bakiye fiyattan büyük veya eşit ise açık' sayıyor: satın alma akışına hiç ulaşılamıyor, seçilen avatar sunucuda reddediliyor | `lib/models/avatar_model.dart:39-47` | ✅ Düzeltildi |
| SOCIAL-04 | 🟠 | Sahip olunan avatarlar (avatar_unlocks) splash ve auth-state yolunda hiç yüklenmiyor: satın alınan ve lig ödülü avatarlar kilitli görünüyor | `lib/screens/splash_screen.dart:133-158` | ✅ Düzeltildi |
| SOCIAL-05 | 🟠 | Arkadaş listesi ve gelen istekler başka kullanıcıların profiles satırını doğrudan okuyor: canlı RLS'te istekler görünmüyor | `lib/services/supabase_service.dart:1135-1159` | ✅ Düzeltildi |
| SOCIAL-06 | 🟡 | 'Aylık' sekmesi aslında tüm zamanlar listesi: aylık sıfırlama sayacı, terfi/düşme renkleri ve aylık ödül avatarları yanıltıcı | `lib/screens/ranking_screen.dart:143-147` | ✅ Düzeltildi |
| SOCIAL-07 | 🟡 | Lig dönemi uzunluğu tutarsız: uygulama ve site '14 gün', README ve sunucu haftalık, istemci fallback'i cihaz saatine göre Pazartesi | `lib/widgets/league_info_sheet.dart:142-143` | ✅ Düzeltildi |
| SOCIAL-08 | 🟡 | Berabere puanda istemcinin gösterdiği sıra ile sunucunun terfi sırası farklı | `supabase/migrations/20260809022700_fixes_rls_zones_up.sql:201` | ✅ Düzeltildi |
| SOCIAL-09 | 🟡 | Sıralama yüklemesinde yarış: await sonrası güncel _selectedTab okunuyor, eski istek yeni sekmenin verisini ezebiliyor | `lib/screens/ranking_screen.dart:122-209` | ✅ Düzeltildi |
| SOCIAL-10 | 🟡 | 'Ben' satırı isim eşleşmesiyle de aranıyor: aynı isimdeki başka bir kullanıcı listeden siliniyor; hata durumunda kullanıcı tek başına 1. görünüyor | `lib/screens/ranking_screen.dart:159-163` | ✅ Düzeltildi |
| SOCIAL-11 | 🟡 | Görünmeyen sekmeler sürekli çalışıyor: saniyede bir tam ekran yeniden kurulum, 30 sn polling ve her seans tamamlanmasında tüm istemcilerde yeniden yükleme | `lib/screens/ranking_screen.dart:52-58` | ✅ Düzeltildi |
| SOCIAL-13 | 🟡 | Avatar kuşanma hatası yutuluyor, iyimser UI geri alınmıyor ve aynı RPC iki kez çağrılıyor | `lib/screens/character_collection_screen.dart:192-198` | ✅ Düzeltildi |
| SOCIAL-14 | 🟡 | İsim değiştirme: sonuç ana uygulama durumuna yansımıyor, sunucu hatası yutulup başarı gösteriliyor, doğrulama yok | `lib/main.dart:485-549` | ✅ Düzeltildi |
| SOCIAL-16 | 🟡 | Sosyal görünürlük önbelleği singleton'da hesaplar arası taşınıyor; yazma hatası yutuluyor ve UI geri alınmıyor | `lib/services/supabase_service.dart:875-926` | ✅ Düzeltildi |
| SOCIAL-17 | 🟡 | Profildeki 'Bildirimler' anahtarı hiçbir şeye bağlı değil | `lib/screens/profile_screen.dart:58` | ✅ Düzeltildi |
| SOCIAL-18 | 🟡 | Profilden kategori yönetimine gidip dönünce ana ekran kategorileri tazelenmiyor; ProfileScreen'de ölü parametreler var | `lib/screens/profile_screen.dart:315-321` | ✅ Düzeltildi |
| SOCIAL-19 | 🟡 | Arkadaşlık yönü tutarsız: arkadaş listesi tek yönlü, canlı liste iki yönlü OR-join yapıyor | `lib/services/supabase_service.dart:1142-1147` | ✅ Düzeltildi |
| SOCIAL-20 | 🟡 | Arkadaş yönetimi eksik: silme/engelleme/giden isteği iptal yok, kod normalize edilmiyor, ham hata metni gösteriliyor | `lib/screens/friends_sheet.dart:55-92` | ✅ Düzeltildi |
| SOCIAL-22 | 🟡 | Hesap silme: yükleniyor durumu yok, cihazdaki kullanıcı verileri silinmiyor, onay metni sadece Türkçe | `lib/screens/profile_screen.dart:735-791` | ✅ Düzeltildi |
| SOCIAL-V02 | 🟡 | Splash'teki getAvatars çağrısının zaman aşımı yok: zayıf ağda açılış dakikalarca takılabilir | `lib/screens/splash_screen.dart:86-100` | ✅ Düzeltildi |
| SOCIAL-V03 | 🟡 | Küçük liglerde (3 veya daha az üye) herkes terfi ediyor, 10'dan az üyede düşme yok: az kullanıcıyla lig sistemi anlamsızlaşıyor | `supabase/migrations/20260809022700_fixes_rls_zones_up.sql:43-64` | 🟨 Kısmen |
| SOCIAL-V04 | 🟡 | Profildeki 'Karanlık Mod' tercihi kalıcı değil: her açılışta açık temaya dönüyor | `lib/main.dart:66-72` | ✅ Düzeltildi |
| SOCIAL-12 | ⚪ | Lig bilgi sheet'i ilk açılışta, kullanıcı Sıralama sekmesine hiç gitmeden Timer ekranının üzerine açılıyor | `lib/screens/ranking_screen.dart:206-223` | ✅ Düzeltildi |
| SOCIAL-15 | ⚪ | Varsayılan avatar sabitleri 4 farklı yerde farklı: Google/Apple ile kaydolan kullanıcı sahip olmadığı 200 coin'lik avatarla başlıyor | `lib/services/supabase_service.dart:255` | ✅ Düzeltildi |
| SOCIAL-21 | ⚪ | Lig sheet'inde yükselme/düşme metni hatalı: Gümüş+ küçük ligde 'Bronz ligde düşme yoktur', İngilizcede çift virgül | `lib/widgets/league_info_sheet.dart:361-375` | ✅ Düzeltildi |
| SOCIAL-23 | ⚪ | Pazar 23:59:00-23:59:59 arasında tamamlanan seans, bitiş tarihi geçmiş yeni bir lig açıyor; o ligdekiler bir hafta 'Sıfırlanıyor...' görür | `supabase/migrations/20260809022700_fixes_rls_zones_up.sql:71` | 🟨 Kısmen |
| SOCIAL-24 | ⚪ | Sosyal alanda sabit Türkçe metinler ve tutarsız terimler | `lib/screens/ranking_screen.dart:324` | ✅ Düzeltildi |
| SOCIAL-25 | ⚪ | Sıralamada kullanıcının kendi satırı vurgulanmıyor; koleksiyonda bakiye hiç gösterilmiyor | `lib/screens/ranking_screen.dart:364-455` | ✅ Düzeltildi |
| SOCIAL-26 | ⚪ | Aktivite akışı ölü kod: sunucu her seansta activity_feed'e yazıyor ama istemci hiç okumuyor | `lib/services/supabase_service.dart:964-975` | ✅ Düzeltildi |
| SOCIAL-27 | ⚪ | Asset tutarsızlıkları: 9,6 MB kullanılmayan lig görseli, seed'deki eksik tomato_basic.png, 1 MB'lık onboarding görseli | `assets/league_award_avatars/` | ✅ Düzeltildi |
| SOCIAL-28 | ⚪ | Gereksiz karmaşıklık: 218 satırlık build, her öğede yeniden hesaplanan liste getter'ı, build içinde state mutasyonu, tekrarlı RPC | `lib/screens/ranking_screen.dart:251-469` | ✅ Düzeltildi |
| SOCIAL-29 | ⚪ | PROJECT_CONTEXT.md'nin sıralama, koleksiyon ve avatar bölümleri gerçeği yansıtmıyor | `PROJECT_CONTEXT.md:13` | ❔ |

## AUTH — Giriş, onboarding, kategoriler, dil (34)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| AUTH-01 | 🟠 | Şifre sıfırlama PKCE yüzünden hiç çalışmıyor: reset-password.html yalnızca #access_token bekliyor | `lib/services/supabase_service.dart:549-556` | ✅ Düzeltildi |
| AUTH-02 | 🟠 | Onboarding'de kategori seçmeyen (veya kategori kaydı yarıda kalan) kullanıcı yer tutucu kategorilerle kalıyor; tüm seansları reddediliyor | `lib/screens/post_auth_onboarding_screen.dart:37-50` | ✅ Düzeltildi |
| AUTH-03 | 🟠 | Kategori Yönetimi'ndeki ekleme/düzenleme/arşiv/sıralama Timer'a yansımıyor | `lib/screens/profile_screen.dart:315-320` | ✅ Düzeltildi |
| AUTH-04 | 🟡 | Üç paralel çeviri sistemi; ARB'nin 123/210, LanguageService'in 82/176 anahtarı ölü, 21 ortak anahtarın metni çelişiyor | `lib/services/language_service.dart:132-343` | ✅ Düzeltildi |
| AUTH-06 | 🟡 | Auth, onboarding ve kategori hataları kullanıcıya ham exception metni ya da yalnızca Türkçe olarak gösteriliyor | `lib/screens/login_screen.dart:100` | ✅ Düzeltildi |
| AUTH-07 | 🟡 | Google ile girişte hesap oluşturuluyor ama Kullanım Şartları/Gizlilik onayı ve bilgilendirme hiç gösterilmiyor | `lib/screens/login_screen.dart:416-440` | ✅ Düzeltildi |
| AUTH-08 | 🟡 | Yaş kapısı canlı onboarding'de yok: 13 yaş altı doğum yılı kabul edilip kaydediliyor | `lib/screens/post_auth_onboarding_screen.dart:341-364` | ✅ Düzeltildi |
| AUTH-11 | 🟡 | Onboarding'de seçilen günlük hedef hiçbir yerde kullanılmıyor; Raporlar ayrı bir yerel hedef kullanıyor | `lib/screens/post_auth_onboarding_screen.dart:522-550` | ✅ Düzeltildi |
| AUTH-14 | 🟡 | Apple ile Giriş kodu var ama UI'da yok ve iOS entitlement'ı tanımsız (App Review 4.8 riski) | `lib/services/supabase_service.dart:361-432` | ✅ Düzeltildi |
| AUTH-20 | 🟡 | Profil adı güncellemesi e-posta kolonuyla filtreliyor, hatayı yutup başarı gösteriyor ve sonucu üst state'e iletmiyor | `lib/services/supabase_service.dart:566-584` | ✅ Düzeltildi |
| AUTH-24 | 🟡 | PROJECT_CONTEXT.md auth/onboarding/kategori/l10n bölümleri gerçekle uyuşmuyor | `PROJECT_CONTEXT.md:9-13` | ❔ |
| AUTH-31 | 🟡 | Kullanıcıya görünen sabit (hardcoded) metin envanteri: ARB dışında kalan TR-only/EN-only metinler ve ternary'ler | `lib/screens/login_screen.dart:100` | ✅ Düzeltildi |
| AUTH-V01 | 🟡 | Soğuk başlangıçta ve auth dinleyicisinde açılmış avatarlar (avatar_unlocks) yüklenmiyor; satın alınan/kazanılan avatarlar kilitli görünüyor, coin'i yeten kullanıcı satın almadan avatar 'kuşanabiliyor' | `lib/screens/splash_screen.dart:150-156` | ✅ Düzeltildi |
| AUTH-V02 | 🟡 | Google girişinde profil oluşturma hatası yutuluyor ama profil satırı hiçbir yerde yeniden oluşturulmuyor; onboarding 0 satır güncelleyip başarı sayıyor | `lib/services/supabase_service.dart:332-353` | ✅ Düzeltildi |
| AUTH-V03 | 🟡 | cleanup_unconfirmed_duplicate_identity RPC'si istemcinin verdiği p_email ile çağrılıyor; tanımı repoda yok, başkasının onaysız hesabını silme riski doğrulanmalı | `lib/services/supabase_service.dart:324-330` | ✅ Düzeltildi |
| AUTH-05 | ⚪ | İlk açılış dili cihaz dilinden bağımsız hep Türkçe; giriş/kayıt/onboarding'de dil seçimi yok | `lib/services/language_service.dart:18-31` | ⏸ Yapılmadı |
| AUTH-09 | ⚪ | Girişte şifre trim'leniyor, kayıtta trim'lenmiyor: başında/sonunda boşluk olan şifreyle giriş imkânsız | `lib/screens/login_screen.dart:30` | ✅ Düzeltildi |
| AUTH-10 | ⚪ | Başarılı girişte yükleme durumu erken kapanıyor; 5 sn'ye kadar donuk ekran ve çift submit | `lib/screens/login_screen.dart:51-54` | ✅ Düzeltildi |
| AUTH-12 | ⚪ | Onboarding sonucu üst bileşene iletilmiyor; segment/hedef null kalıyor ve saved_user önbelleği eziliyor | `lib/screens/post_auth_onboarding_screen.dart:13` | 🟨 Kısmen |
| AUTH-13 | ⚪ | Auth/kategori alanında ~1000 satır ölü kod (iki ekran, Apple girişi, kategori callback zinciri) | `lib/screens/onboarding_screen.dart:1-458` | ✅ Düzeltildi |
| AUTH-15 | ⚪ | E-posta ve Apple girişinde oturum açıldıktan sonraki profil hatası girişi başarısız gösteriyor (Google yolunda düzeltilmiş) | `lib/services/supabase_service.dart:247-262` | ✅ Düzeltildi |
| AUTH-16 | ⚪ | Onboarding kategorileri Türkçe adla kaydediliyor; çeviri yalnızca bazı ekranlarda uygulanıyor | `lib/screens/post_auth_onboarding_screen.dart:147-169` | ✅ Düzeltildi |
| AUTH-17 | ⚪ | Kategori Yönetimi ekranında dispose sonrası setState, yakalanmayan sıralama hatası ve çevrimdışıyken yanıltıcı boş liste | `lib/screens/categories_management_screen.dart:31-44` | ✅ Düzeltildi |
| AUTH-18 | ⚪ | Kategori limiti (8/15), renk paletleri ve varsayılanlar ~15 yerde kopyalanmış | `lib/screens/categories_management_screen.dart:48` | ✅ Düzeltildi |
| AUTH-19 | ⚪ | Kategori adı için uzunluk/biçim doğrulaması yok; benzersizlik büyük-küçük harfe duyarlı, yeniden adlandırma çakışması ham hata | `lib/screens/categories_management_screen.dart:70-73` | ✅ Düzeltildi |
| AUTH-21 | ⚪ | OAuth kullanıcılarına 200 coin'lik 'avatar_1_gamer' varsayılan atanıyor; varsayılan avatar 4 yerde 4 farklı değer | `lib/services/supabase_service.dart:255` | ✅ Düzeltildi |
| AUTH-22 | ⚪ | LanguageService.translate() her çağrıda 176 girdili map oluşturuyor; Timer saniyede bir çağırıyor | `lib/services/language_service.dart:132-343` | ❔ |
| AUTH-23 | ⚪ | iOS Info.plist'te CFBundleLocalizations yok; bildirim izin açıklaması yalnızca Türkçe | `ios/Runner/Info.plist:10-11` | ✅ Düzeltildi |
| AUTH-25 | ⚪ | Giriş alanı 'Kullanıcı Adı veya E-posta' diyor ama yalnızca e-posta destekleniyor; klavye tipi ve autofill eksik | `lib/l10n/app_tr.arb:70` | ✅ Düzeltildi |
| AUTH-26 | ⚪ | PostAuthOnboarding akış hataları: oturum düşünce ölü Bitir butonu, çıkış/geri yok, çift isim, çift '+' | `lib/screens/post_auth_onboarding_screen.dart:62-66` | 🟨 Kısmen |
| AUTH-27 | ⚪ | Shell içi girişte yeni kullanıcının kategori önbelleği önceki/yer tutucu listeyle eziliyor | `lib/main.dart:562-572` | ✅ Düzeltildi |
| AUTH-28 | ⚪ | Auth ekranlarında TextEditingController, PageController ve TapGestureRecognizer dispose edilmiyor | `lib/screens/login_screen.dart:21-22` | ✅ Düzeltildi |
| AUTH-29 | ⚪ | Şifre sıfırlama/yeniden gönderme: bulut pasifken sahte başarı, yeniden gönderde çift tık koruması yok | `lib/services/supabase_service.dart:530-543` | ✅ Düzeltildi |
| AUTH-30 | ⚪ | confirmed.html 'Uygulamayı Aç' PKCE kodunu (query) düşürüyor; giriş öncesi auth dinleyicisi de yok | `landing/confirmed.html:105-107` | ✅ Düzeltildi |

## BACKEND — Supabase backend (33)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| BACKEND-01 | 🔴 | Kuyruktaki ikinci ve sonraki seanslar 'overlap' ile reddedilip sessizce siliniyor | `supabase/migrations/20260809025000_social_feed_up.sql:140-149` | 🟨 Kısmen |
| BACKEND-02 | 🔴 | Avatar kataloğu boş kalınca ana kabuk `avatars.first` ile çöküyor (çevrimdışı soğuk açılış) | `lib/screens/splash_screen.dart:92-100` | ✅ Düzeltildi |
| BACKEND-03 | 🟠 | _down.sql dosyaları migrations/ içinde ve _up ile aynı sürüm numarasını taşıyor; Supabase CLI ile uygulanırsa veri kaybı | `supabase/migrations/20260809021500_categories_and_expanded_tables_down.sql:1-22` | ✅ Düzeltildi |
| BACKEND-06 | 🟠 | Uygulamadaki 'Aylık' sıralama sekmesi tüm zamanlar sıralamasını gösteriyor | `lib/screens/ranking_screen.dart:145-146` | ✅ Düzeltildi |
| BACKEND-V01 | 🟠 | Herkese açık 'ranking_updates' broadcast'i: her seans tamamlaması tüm çevrimiçi istemcilerde ağır sorgular tetikliyor; anon key'e sahip herkes bunu spam'leyebilir | `lib/services/supabase_service.dart:830-871` | ✅ Düzeltildi |
| BACKEND-04 | 🟡 | Repodaki son process_weekly_leagues tanımı çalışmıyor; haftalık lig devri hiç gerçekleşmiyor | `supabase/migrations/20260809025000_social_feed_up.sql:412-493` | 🟨 Kısmen |
| BACKEND-05 | 🟡 | profiles okuma tarafı repoda herkese açık; canlıda tersi geçerliyse istemcinin arkadaş listeleri boş kalıyor | `supabase/migrations/20260809033000_fix_profiles_permissions.sql:2` | 🟨 Kısmen |
| BACKEND-07 | 🟡 | purchase_avatar eşzamanlı çağrılarda çift harcamaya ve coin kaybına açık | `supabase/migrations/20260809030000_avatars_and_economy_up.sql:179` | 🟨 Kısmen |
| BACKEND-08 | 🟡 | Cihaz saati 3 dakikadan fazla ileriyse tüm seanslar kalıcı reddedilip siliniyor | `supabase/migrations/20260928120000_security_hardening_up.sql:45-49` | 🟨 Kısmen |
| BACKEND-09 | 🟡 | profiles.timezone hiç yazılmıyor; gün sınırı, seri ve günlük 16 tavanı herkes için İstanbul saatine göre | `supabase/migrations/20260809021500_categories_and_expanded_tables_up.sql:46` | 🟨 Kısmen |
| BACKEND-10 | 🟡 | completed_at senkron anını tutuyor; çevrimdışı seanslar geçmiş ve raporlarda yanlış güne yazılıyor | `supabase/migrations/20260809025000_social_feed_up.sql:249` | ✅ Düzeltildi |
| BACKEND-11 | 🟡 | Seri (streak) istemcide iki kopya halinde ve sunucudan farklı kuralla yeniden hesaplanıyor | `lib/main.dart:286-296` | ✅ Düzeltildi |
| BACKEND-12 | 🟡 | Profil oluşturma email ve avatar_id'yi doğrulamadan kabul ediyor; varsayılan avatar ataması etkisiz | `supabase/migrations/20260928120000_security_hardening_up.sql:87` | 🟨 Kısmen |
| BACKEND-13 | 🟡 | İsim güncelleme e-postaya göre filtreliyor ve hatayı yutuyor | `lib/services/supabase_service.dart:566-584` | ✅ Düzeltildi |
| BACKEND-14 | 🟡 | Arkadaşlık yönü sözleşmesi tutarsız: get_live_friends aynı arkadaşı iki kez döndürüyor | `supabase/migrations/20260809025000_social_feed_up.sql:356-362` | ✅ Düzeltildi |
| BACKEND-17 | 🟡 | Migration'lar yeni bir ortamı kuramıyor ve canlıyla belgelenmiş drift var (önceki 4.7 hâlâ açık) | `supabase/migrations/20260809021500_categories_and_expanded_tables_up.sql:6` | 🟨 Kısmen |
| BACKEND-21 | 🟡 | PROJECT_CONTEXT.md'nin backend bölümleri gerçek akışla uyuşmuyor | `PROJECT_CONTEXT.md:37` | ❔ |
| BACKEND-V02 | 🟡 | Kuyruk senkronu sırasında eklenen bekleyen seans, senkron sonunda listenin üzerine yazılmasıyla siliniyor | `lib/services/supabase_service.dart:733-804` | ✅ Düzeltildi |
| BACKEND-V03 | 🟡 | Lig dönemi UI'da ve landing'de '14 gün', repo sunucu mantığında ve istemci fallback'inde haftalık | `lib/widgets/league_info_sheet.dart:268-270` | ✅ Düzeltildi |
| BACKEND-V04 | 🟡 | Yerel kullanıcı önbelleği (saved_user) seri bilgisini hiç saklamıyor; çevrimdışı ya da yavaş açılışta seri 0 görünüyor | `lib/models/user_model.dart:36-52` | ✅ Düzeltildi |
| BACKEND-15 | ⚪ | Seans geçmişi sayfalamasız çekiliyor; 1000 satır sınırında raporlar sessizce eksik kalıyor | `lib/services/supabase_service.dart:807-824` | ✅ Düzeltildi |
| BACKEND-16 | ⚪ | SQL testleri yanlış güven veriyor: stub gerçek RPC'yi modellemiyor ve hiçbir assertion yok | `supabase/tests/security_hardening_stub.sql:16-23` | ✅ Düzeltildi |
| BACKEND-18 | ⚪ | Seans doğrulaması gerçek zamanla sınırlı, ama uygulama hiç açılmadan 7/24 puan ve coin toplanabiliyor | `supabase/migrations/20260928120000_security_hardening_up.sql:32-69` | ⏸ Yapılmadı |
| BACKEND-19 | ⚪ | activity_feed RLS'i 'sosyal akışta görün' tercihini atlıyor | `supabase/migrations/20260809025000_social_feed_up.sql:26-42` | 🟨 Kısmen |
| BACKEND-20 | ⚪ | Bülten script'i bu haliyle çalışmıyor; çalışsa bile hataları başarı olarak raporluyor | `scripts/send_newsletter.js:1` | ✅ Düzeltildi |
| BACKEND-22 | ⚪ | get_friends_feed SQL hatası veriyor ve istemcide hiç çağrılmıyor; activity_feed yazımları boşa çalışıyor | `supabase/migrations/20260809025000_social_feed_up.sql:370-408` | 🟨 Kısmen |
| BACKEND-23 | ⚪ | unsubscribe fonksiyonunun deploy ayarı repoda yok; CORS www'yi, ilike de '*' jokerini hesaba katmıyor | `supabase/functions/unsubscribe/index.ts:11` | ✅ Düzeltildi |
| BACKEND-24 | ⚪ | Puan sabitleri üç yerde kopya; 50 dk'lık seansta duraklatma cezası UI'daki %20 değil %25 | `supabase/migrations/20260809025000_social_feed_up.sql:156-164` | 🟨 Kısmen |
| BACKEND-25 | ⚪ | SECURITY DEFINER RPC'ler anon'a açık; toplu search_path=public ataması extensions kullanan fonksiyonları kırabilir | `supabase/migrations/20260928120000_security_hardening_up.sql:193-221` | 🟨 Kısmen |
| BACKEND-26 | ⚪ | Eski bir kuyruk seansının senkronu o an süren seansı canlı listeden siliyor; start_study_session girdileri doğrulanmıyor | `supabase/migrations/20260809025000_social_feed_up.sql:89-93` | 🟨 Kısmen |
| BACKEND-27 | ⚪ | Seans trigger'ındaki ve RPC'deki gün sorguları index kullanamıyor; her tamamlama tüm geçmişi tarıyor | `supabase/migrations/20260928120000_security_hardening_up.sql:51-58` | 🟨 Kısmen |
| BACKEND-28 | ⚪ | Kategori limiti dört yerde kopya ve eşzamanlı eklemede aşılabiliyor | `supabase/migrations/20260809031000_onboarding_and_categories_up.sql:42-60` | 🟨 Kısmen |
| BACKEND-29 | ⚪ | Sıralama listelerinde 'ben' satırı isimle de eşleştiriliyor; aynı isimli başka bir kullanıcının satırı eziliyor | `lib/screens/ranking_screen.dart:159-178` | ✅ Düzeltildi |

## PLATFORM — Platform, bağımlılık, doküman (36)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| PLATFORM-01 | 🟠 | Android'de seans bitiş bildirimi hiç gösterilmiyor: ScheduledNotificationReceiver manifest'te tanımlı değil | `android/app/src/main/AndroidManifest.xml:3` | ✅ Düzeltildi |
| PLATFORM-02 | 🟠 | Android 13+'ta bildirim izni hiç istenmiyor: tek requestPermission çağrısı ölü OnboardingScreen'de | `lib/screens/onboarding_screen.dart:60` | ✅ Düzeltildi |
| PLATFORM-03 | 🟠 | iOS'ta Google girişi var ama Sign in with Apple ne UI'da ne entitlement'ta: App Store 4.8 reddi riski | `lib/services/supabase_service.dart:362` | ✅ Düzeltildi |
| PLATFORM-V02 | 🟠 | Android'de seans sürerken geri tuşu/hareketi uygulamayı kapatıyor; çalışan seans kayboluyor (PopScope yok, predictive back etkin değil, timer durumu kalıcı değil) | `lib/main.dart:89` | ✅ Düzeltildi |
| PLATFORM-04 | 🟡 | Kullanılmayan özel URL şeması ve açık detectSessionInUri: zararlı bir bağlantı oturumu saldırganın hesabına çevirebilir | `android/app/src/main/AndroidManifest.xml:29` | ✅ Düzeltildi |
| PLATFORM-05 | 🟡 | Sentry release'de debugPrint'leri breadcrumb olarak topluyor: kullanıcı e-postaları Sentry'ye gidiyor, gizlilik politikasında Sentry yok | `lib/main.dart:49` | ✅ Düzeltildi |
| PLATFORM-06 | 🟡 | .env uygulamaya asset olarak gömülüyor; regresyon scripti service role anahtarını kök .env'de aramaya yönlendiriyor | `pubspec.yaml:95` | ✅ Düzeltildi |
| PLATFORM-09 | 🟡 | iOS UIScene yapılandırması yok (SceneDelegate ölü); Info.plist'te yanlış yere eklenmiş ve etkisiz anahtarlar var | `ios/Runner/Info.plist:5` | ✅ Düzeltildi |
| PLATFORM-10 | 🟡 | Profil ekranındaki 'Bildirimler' anahtarı hiçbir şeye bağlı değil | `lib/screens/profile_screen.dart:58` | ✅ Düzeltildi |
| PLATFORM-11 | 🟡 | UserModel.toMap seri ve son çalışma tarihini yazmıyor: çevrimdışı açılışta seri 0 görünüyor; id alanı int olduğu için hep null | `lib/models/user_model.dart:36` | ✅ Düzeltildi |
| PLATFORM-13 | 🟡 | Çift yerelleştirme sistemi: ARB anahtarlarının %59'u, LanguageService anahtarlarının %47'si kullanılmıyor; translate() her çağrıda 175 girişli map kuruyor | `lib/services/language_service.dart:132` | ⏸ Yapılmadı |
| PLATFORM-25 | 🟡 | PROJECT_CONTEXT: silinmiş database_inspector_screen listede; gerçek ekranların ve notification_service'in yarısı eksik | `PROJECT_CONTEXT.md:61` | ❔ |
| PLATFORM-27 | 🟡 | PROJECT_CONTEXT: var olmayan metotlar (saveStudySession, loadCategories), olmayan mola modu ve 'veri erişimi asla ekranda değil' iddiası | `PROJECT_CONTEXT.md:37` | ❔ |
| PLATFORM-V01 | 🟡 | Seans bitiminde cancelAll() çağrılıyor: Android'de süreç arka planda canlıyken bitiş bildirimi iptal ediliyor veya gösterildiği anda siliniyor | `lib/screens/timer_screen.dart:111` | ✅ Düzeltildi |
| PLATFORM-V03 | 🟡 | unsubscribe Edge Function'ının JWT doğrulaması kapalı olmalı ama bu yalnızca bir kod yorumunda; supabase/config.toml yok | `supabase/functions/unsubscribe/index.ts:11` | ✅ Düzeltildi |
| PLATFORM-07 | ⚪ | iOS Info.plist'te CFBundleLocalizations yok: Türkçe kullanıcılar sistem diyaloglarını İngilizce görüyor | `ios/Runner/Info.plist:10` | ✅ Düzeltildi |
| PLATFORM-08 | ⚪ | Uygulama dili cihaz dilini yok sayıyor, ilk açılış her zaman Türkçe; bildirim metni sabit Türkçe | `lib/services/language_service.dart:10` | ✅ Düzeltildi |
| PLATFORM-12 | ⚪ | Test kapsamı: en riskli mantık (çevrimdışı kuyruk, model önbelleği, zamanlayıcı süresi) test edilmiyor | `test/session_sync_test.dart:1` | ✅ Düzeltildi |
| PLATFORM-14 | ⚪ | google_sign_in 6.x (Android'de kullanımdan kalkmış GoogleSignIn API'si) ve bekleyen bağımlılık güncellemeleri | `pubspec.yaml:46` | ⏸ Yapılmadı |
| PLATFORM-15 | ⚪ | Ölü kod: hiç kullanılmayan iki ekran (812 satır), ikinci MainActivity, çağrılmayan signInWithApple | `lib/screens/onboarding_screen.dart:8` | ✅ Düzeltildi |
| PLATFORM-16 | ⚪ | Kullanılmayan bağımlılıklar: timeago, path, cupertino_icons | `pubspec.yaml:39` | ✅ Düzeltildi |
| PLATFORM-17 | ⚪ | macos/linux/windows/web klasörleri çalışmayan şablonlar; açılışta bildirim başlatma hatası yakalanmıyor | `lib/services/notification_service.dart:41` | ✅ Düzeltildi |
| PLATFORM-18 | ⚪ | Release APK, key.properties yoksa hâlâ sessizce debug anahtarıyla imzalanıyor (yalnızca AAB korunuyor) | `android/app/build.gradle.kts:56` | ✅ Düzeltildi |
| PLATFORM-19 | ⚪ | Bildirim small icon'u renkli adaptive launcher ikonu (@mipmap/ic_launcher) | `lib/services/notification_service.dart:33` | ✅ Düzeltildi |
| PLATFORM-20 | ⚪ | android:allowBackup varsayılan açık: Supabase oturum token'ları ve yerel önbellek Google yedeğine giriyor | `android/app/src/main/AndroidManifest.xml:3` | ✅ Düzeltildi |
| PLATFORM-21 | ⚪ | iOS açılış ekranı boş beyaz (1x1 yer tutucu), Android'de markalı splash var | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png:1` | ✅ Düzeltildi |
| PLATFORM-22 | ⚪ | Repo hijyeni: kişisel AI ayar dosyaları ve doldurulmamış şablonlar izleniyor, .wrangler/ ignore edilmiyor | `.gitignore:1` | 🟨 Kısmen |
| PLATFORM-23 | ⚪ | Kullanılmayan 9.6 MB asset repoda, assets/avatars/.DS_Store uygulama paketine giriyor | `assets/league_award_avatars/` | 🟨 Kısmen |
| PLATFORM-24 | ⚪ | analysis_options yalnızca varsayılan lint seti: 17 await edilmemiş Future ve 15 dinamik çağrı fark edilmiyor | `analysis_options.yaml:10` | ✅ Düzeltildi |
| PLATFORM-26 | ⚪ | PROJECT_CONTEXT: ders seçimi CategoriesScreen üzerinden yapılıyor iddiası yanlış (dosya ölü) | `PROJECT_CONTEXT.md:11` | ❔ |
| PLATFORM-28 | ⚪ | PROJECT_CONTEXT: Raporlar 'grafik kütüphaneleri', Sıralama 'profiles tablosundan RLS ile' iddiaları yanlış | `PROJECT_CONTEXT.md:49` | ❔ |
| PLATFORM-29 | ⚪ | PROJECT_CONTEXT: modeller bölümündeki alan listeleri gerçek modellerle uyuşmuyor | `PROJECT_CONTEXT.md:81` | ❔ |
| PLATFORM-30 | ⚪ | PROJECT_CONTEXT: 'repoda olmayan RPC'ler' listesi eksik; bazı tablolar hiç oluşturulmuyor | `PROJECT_CONTEXT.md:96` | ❔ |
| PLATFORM-31 | ⚪ | PROJECT_CONTEXT: Splash akışı 'oturum varsa doğrudan TimerScreen' diye eksik ve yanlış anlatılıyor | `PROJECT_CONTEXT.md:9` | ❔ |
| PLATFORM-32 | ⚪ | README eksikleri: script kurulumu ve anahtarlar, .env.example, desteklenen platformlar, debug seans notu | `README.md:18` | ❔ |
| PLATFORM-33 | ⚪ | Eski analiz raporu ve specs/001 belgesi var olmayan özellikleri anlatıyor (Live Activities, Apple girişi, Sanal Kütüphane, +20 puan) | `analiz/PomoSprint_Analiz_Raporu.md:48` | ❔ |

## LANDING — Landing sitesi (28)

| Id | Önem | Bulgu | Konum | Durum |
|---|---|---|---|---|
| LANDING-01 | 🟠 | Canlıdaki unsubscribe Edge Function token doğrulamıyor; repo'daki düzeltme deploy edilmemiş | `supabase/functions/unsubscribe/index.ts:41-66` | ✅ Düzeltildi |
| LANDING-02 | 🟠 | reset-password.html implicit akış bekliyor, uygulama PKCE kullanıyor: şifre sıfırlama her zaman 'Bağlantı Geçersiz' diyor | `landing/reset-password.html:101-121` | ✅ Düzeltildi |
| LANDING-03 | 🟠 | Sitenin her yerinde kaldırılmış 'Sanal Kütüphane / masalar' özelliği vaat ediliyor | `landing/index.html:7` | ✅ Düzeltildi |
| LANDING-04 | 🟡 | Site mola zamanlayıcısı ve özelleştirilebilir süreler vaat ediyor; uygulamada yalnızca 25/50 dk odak var | `landing/index.html:123` | ✅ Düzeltildi |
| LANDING-05 | 🟡 | CSS display:flex 'hidden' özniteliğini eziyor: ana sayfada boş podyum ve sonsuz iskelet görünüyor | `landing/css/style.css:1580-1587` | ✅ Düzeltildi |
| LANDING-06 | 🟡 | confirmed.html mobilde taşıyor, parametresiz açılınca bile 'onaylandı' diyor ve PKCE kodunu uygulamaya iletmiyor | `landing/confirmed.html:24-31` | ✅ Düzeltildi |
| LANDING-07 | 🟡 | Gizlilik politikası gerçek veri işlemeyle uyumsuz (Sentry, Google Fonts/jsDelivr, waitlist, onboarding alanları) | `landing/privacy.html:84-96` | ❔ |
| LANDING-08 | 🟡 | Waitlist formu: çift onay ve bot koruması yok, e-posta kaydı sorgulanabiliyor, bülten hattına bağlı değil | `landing/js/main.js:51-90` | 🟨 Kısmen |
| LANDING-10 | 🟡 | SEO ve URL düzeni eksik: www kopyası, .html'den 307, canonical yok, robots/sitemap 404, 404 sayfası boş, og:image yok | `landing/wrangler.jsonc:8-11` | ✅ Düzeltildi |
| LANDING-11 | 🟡 | Sitedeki 'Bu ayın ilk 10'u' ile uygulamanın 'Aylık' sekmesi farklı veri gösteriyor; RPC'ler repoda yok, geri sayım yerel saate göre | `landing/js/main.js:93-96` | ✅ Düzeltildi |
| LANDING-12 | 🟡 | Lig dönemi: site ve uygulama '14 gün' diyor, repo migration'ları haftalık çalışıyor | `landing/index.html:156` | ✅ Düzeltildi |
| LANDING-13 | 🟡 | 'Cihaz diline otomatik uyum' vaadi gerçek değil; uygulama her zaman Türkçe açılıyor | `landing/features.html:161-167` | ✅ Düzeltildi |
| LANDING-14 | 🟡 | SSS 'tamamen ücretsiz' ve 'doktor, pilot... 16 karakterden birini seç' diyor; bu avatarların bir kısmı Premium ve satın alma yolu yok | `landing/faq.html:60` | ✅ Düzeltildi |
| LANDING-16 | 🟡 | Yasal metinler yalnızca Türkçe; uygulama İngilizce moddayken de Türkçe Gizlilik/Şartlar açıyor | `landing/privacy.html:2` | ✅ Düzeltildi |
| LANDING-V01 | 🟡 | Bülten scripti çalışmıyor: şablon dosyası repoda yok, 100'den fazla abonede gönderim tamamen başarısız oluyor ve hata 'başarılı' diye raporlanıyor | `scripts/send_newsletter.js:30-31` | ✅ Düzeltildi |
| LANDING-V02 | 🟡 | Kullanıcı adları (Google/Apple ile girişte gerçek tam ad) herkese açık web sıralamasında yayınlanıyor; gizlilik metni bunu bildirmiyor | `landing/js/main.js:93-96` | ✅ Düzeltildi |
| LANDING-09 | ⚪ | Güvenlik başlıkları yok; supabase-js sürümü sabitlenmemiş ve SRI'sız CDN'den yükleniyor | `landing/wrangler.jsonc:1-13` | ✅ Düzeltildi |
| LANDING-15 | ⚪ | Renk kontrastı WCAG AA'yı karşılamıyor: ana CTA, linkler, ikincil metinler | `landing/css/style.css:7` | ✅ Düzeltildi |
| LANDING-17 | ⚪ | Auth sayfaları URL'deki error_description'ı basıyor: metin enjeksiyonu ve URIError ile yarım kalan sayfa | `landing/reset-password.html:116-120` | ✅ Düzeltildi |
| LANDING-18 | ⚪ | Tüm statik dosyalar max-age=0 ile sunuluyor; fontlar üçüncü taraftan render'ı blokluyor | `landing/wrangler.jsonc:1-13` | 🟨 Kısmen |
| LANDING-19 | ⚪ | İki çağrı için 218KB supabase-js, iki ayrı client ve dört kopya sabit; hero animasyonu gecikip titriyor | `landing/js/main.js:30-36` | ✅ Düzeltildi |
| LANDING-20 | ⚪ | Lig ödülü avatarlarının (league_*) webp kopyası sitede yok; liderler sıradan avatarla görünüyor | `landing/js/main.js:116-117` | ✅ Düzeltildi |
| LANDING-21 | ⚪ | Erişilebilirlik eksikleri: etiketsiz şifre alanları, kapalı SSS'de odaklanabilir link, hareket tercihini yok sayan videolar | `landing/reset-password.html:88-93` | ✅ Düzeltildi |
| LANDING-22 | ⚪ | features.html'de dönen orbit-track'ler mobilde yatay taşma oluşturuyor | `landing/css/style.css:902` | ✅ Düzeltildi |
| LANDING-23 | ⚪ | Abonelikten çıkma sayfa açılır açılmaz çalışıyor; tek tık abonelikten çıkma başlıkları yok | `landing/unsubscribe.html:24-50` | ✅ Düzeltildi |
| LANDING-24 | ⚪ | Ölü bağımlılık ve yapılandırma: @vercel/analytics, .vercel, izlenen .claude ayarı, kullanılmayan JS kancaları | `landing/package.json:1-5` | 🟨 Kısmen |
| LANDING-25 | ⚪ | Header, footer ve mağaza rozetleri 7 sayfada elle kopyalanmış; auth sayfaları ayrı inline CSS taşıyor | `landing/index.html:62-79` | ✅ Düzeltildi |
| LANDING-26 | ⚪ | Landing için AI devir dokümantasyonu yok; README lig dönemini yanlış anlatıyor | `PROJECT_CONTEXT.md:1-105` | ❔ |
