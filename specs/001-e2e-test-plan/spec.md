# Feature Specification: Uçtan Uca Doğrulama Test Planı (Puan Sistemi, Realtime Senkron, Virtual Library)

**Feature Branch**: `001-e2e-test-plan`

**Created**: 2026-07-31

**Status**: Draft

**Input**: User description: "Pomodoro uygulaması için uçtan uca doğrulama test planı: (1) puan sistemi — gerçek pomodoro tamamlama ile profiles tablosunda +20 puan artışının doğrulanması, (2) Ranking ekranında gerçek zamanlı yansıma (iki cihaz), (3) Reports ekranında ders bazlı seans görünürlüğü, (4) Virtual Library (Social) — iki cihazla masaya oturma realtime senkronu, pomodoro ilerlemesinin canlı yansıması, uçak modunda koltuğun otomatik boşalması, aynı koltuğa eşzamanlı oturma atomikliği; artı test mühendisi gözüyle ek edge case'ler"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pomodoro Tamamlama → Puan Artışı (Priority: P1)

Bir öğrenci Pomo ekranından bir ders (Matematik) seçip pomodoro seansını başlatır ve süre dolana kadar bekler. Seans bittiğinde kalıcı puanı tam olarak 20 artar ve toplam çalışma dakikası seans süresi kadar artar.

**Why this priority**: Puanlama uygulamanın çekirdek motivasyon mekanizmasıdır; yanlışsa sıralama ve raporlar da anlamsızlaşır.

**Independent Test**: Test kullanıcısının `profiles` satırının (points, total_minutes) seans öncesi/sonrası SQL ile karşılaştırılması. Tamamlama olayı GERÇEK zamanlayıcı bitişiyle tetiklenir (DB'ye manuel satır eklenmez).

**Acceptance Scenarios**:

1. **Given** puanı P olan giriş yapmış kullanıcı ve seçili "Matematik" kategorisi, **When** pomodoro seansı gerçek tamamlanma olayıyla biter, **Then** `profiles.points` tam olarak P+20 olur (P+19 veya P+21 değil) ve `profiles.total_minutes` seans dakikası kadar artar.
2. **Given** seans tamamlandı, **When** tamamlama diyaloğu görünür, **Then** diyalogdaki vaat edilen puan (+20) DB'ye yazılan değerle birebir aynıdır.
3. **Given** cloud bağlantısı kesik (uçak modu) tamamlanan seans, **When** RPC başarısız olur, **Then** kullanıcı kaybı görünür şekilde bilgilendirilir (sessiz veri kaybı KABUL EDİLEMEZ — bilinen risk: hata `catch (_) {}` ile yutuluyor).

---

### User Story 2 - Sıralama Ekranında Gerçek Zamanlı Yansıma (Priority: P1)

İkinci bir cihazda sadece Sıralama (Ranking) ekranı açık beklerken, birinci cihaz bir pomodoro tamamlar. İkinci cihazda puan artışı manuel yenileme olmadan birkaç saniye içinde görünür.

**Why this priority**: "Canlı rekabet" ürünün ana vaadi; kullanıcı isteği açıkça iki cihazlı realtime doğrulama istiyor.

**Independent Test**: Cihaz A pomodoro tamamlar; Cihaz B'nin Ranking ekranı gözlemlenir. Başarı kriteri: ≤10 sn içinde B'de yeni puan görünür, sayfa/etkileşim yenilemesi olmadan.

**Acceptance Scenarios**:

1. **Given** Cihaz B Ranking ekranında bekliyor, **When** Cihaz A +20 puan kazanır, **Then** Cihaz B'de A kullanıcısının puanı ≤10 sn içinde güncellenir (bilinen risk: kodda `profiles` için realtime aboneliği YOK ve tablo realtime publication'da DEĞİL — düzeltme gerekebilir).
2. **Given** sıralama listesi görünür, **When** liste yüklenir, **Then** görünen sıra tutarlı tek bir metrikle sıralıdır (bilinen tutarsızlık: sorgu `points`'e göre ilk 50'yi çekiyor, ekran `total_minutes`'a göre sıralıyor).

---

### User Story 3 - Raporlarda Ders Bazlı Seans Görünürlüğü (Priority: P2)

Tamamlanan Matematik pomodoro'su Raporlar ekranında hem "Ders Raporları" (Subject Reports) hem "Çalışma Geçmişi" (Study History) sekmelerinde görünür: Matematik'in seans sayısı +1, dakikası +seans süresi artar; toplam odaklanma süresi de artar.

**Why this priority**: Kişisel ilerleme görünürlüğü; puan kadar kritik değil ama veri bütünlüğünün parçası.

**Independent Test**: Seans öncesi/sonrası Reports ekranındaki değerler (ekran görüntüsü/ekran durumu) ve SharedPreferences'taki kategori agregatları karşılaştırılır.

**Acceptance Scenarios**:

1. **Given** Matematik'te S seans / M dakika görünüyor, **When** 1 pomodoro tamamlanır, **Then** Ders Raporları'nda Matematik S+1 seans / M+süre dakika gösterir.
2. **Given** Çalışma Geçmişi sekmesi, **When** seans tamamlanır, **Then** toplam süre artar (bilinen kısıt: günlük dağılım grafiği sabit ağırlıklarla sentetik üretiliyor; seans bazlı gerçek kayıt hiçbir katmanda tutulmuyor — bu bir bulgu olarak raporlanacak).

---

### User Story 4 - Virtual Library: Oturma/İlerleme Realtime Senkronu (Priority: P1)

İki cihaz aynı anda Sosyal ekranında. Cihaz A bir masaya oturur → Cihaz B'de koltuk ≤5 sn içinde dolu görünür. A pomodoro başlatır → B'de A'nın "çalışıyor" durumu ve ilerlemesi canlı yansır.

**Why this priority**: Realtime altyapının (postgres_changes stream) ana kullanım alanı; kullanıcının açık isteği.

**Independent Test**: İki fiziksel cihaz/emülatör; B'de manuel yenileme yapılmadan gözlem + `table_seats` satırlarının SQL ile eşzamanlı doğrulanması.

**Acceptance Scenarios**:

1. **Given** iki cihaz Sosyal ekranında, **When** A masaya oturur, **Then** B'de aynı koltuk ≤5 sn içinde A'nın adı/avatarıyla dolu görünür.
2. **Given** A oturmuş, **When** A pomodoro başlatır, **Then** B'de A'nın koltuğu "pomodoro başladı" durumuna geçer ve kalan süre canlı ilerler (bilinen risk: yayın sabit 1500 sn gönderiyor, alıcı `current_timer_seconds`'ı hiç okumuyor — canlı geri sayım muhtemelen yok).
3. **Given** A'nın uygulaması internetten kopar (uçak modu), **When** presence heartbeat düşer, **Then** B tarafında A'nın koltuğu makul sürede (ölçülecek; beklenti ≤120 sn) otomatik boşalır.
4. **Given** iki cihaz aynı boş koltuğa aynı anda oturmayı dener, **When** iki `claim_seat` çağrısı yarışır, **Then** yalnızca biri başarılı olur; diğeri anlaşılır bir hata mesajı görür ve koltukta tek kullanıcı kalır (DB'de o koltuk için tek satır).

---

### Edge Cases

- Pomodoro ortasında uygulama kapanır/öldürülürse: seans kaybolur mu, puan yazılır mı, koltuk durumu ne olur?
- Uygulama arka plana alınınca (iOS'ta timer suspend olur): sayaç duraklar mı, tamamlanma gecikir mi?
- Aynı hesap iki cihazda aynı anda pomodoro tamamlarsa: `increment_user_stats` iki kez atomik artırır mı, lokal state'ler ıraksar mı?
- Cloud kapalıyken (offline) tamamlanan seans: retry kuyruğu yok — puan kalıcı olarak DB'ye yazılmaz mı (sessiz kayıp)?
- "123123" kullanıcısı için login'de lokal seed hack'i (75 dk / 60 puan) gerçek DB verisini ekranda ezer mi?
- 1 dakikalık pomodoro da 20 puan verir (süreden bağımsız sabit) — puan/dakika oranı istismara açık mı?
- `claim_seat`'te koltuk satırında NULL kolon varsa (ör. `user_id`) doluluk kontrolü atlanıp PK ihlali ham hatası döner mi?
- Presence sync yarışı: yeni katılan istemci, presence listesi henüz eksikken oturmuş meşru kullanıcının koltuğunu yanlışlıkla `release_seat` ile boşaltır mı?
- Masaya oturup 5 dk içinde pomodoro başlatmama → otomatik kaldırma çalışıyor mu?
- Saat dilimi/saat kayması olan cihazda `seated_at` gösterimi ve sayaçlar tutarlı mı (sunucu NOW() vs cihaz saati)?
- SECURITY DEFINER RPC'ler (`increment_user_stats`, `release_seat`) anon anahtarla herhangi bir email için çağrılabilir — başka kullanıcı adına puan artırma/koltuk boşaltma mümkün mü? (güvenlik bulgusu)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Gerçek pomodoro tamamlanması `profiles.points`'i tam olarak +20, `profiles.total_minutes`'i tam olarak +seans dakikası artırMALIdır; kanıt: önce/sonra SQL sorgusu.
- **FR-002**: Tamamlama diyaloğunda vaat edilen puan ile DB'ye yazılan puan birebir aynı OLMALIdır.
- **FR-003**: Cihaz A'daki puan artışı, Cihaz B'nin Ranking ekranında manuel yenileme olmadan ≤10 sn içinde görünMELİdir.
- **FR-004**: Ranking listesi tek ve tutarlı bir metrikle sıralanMALIdır; çekilen küme ile sıralama metriği çelişmemelidir.
- **FR-005**: Tamamlanan seans, Reports > Ders Raporları'nda ilgili kategorinin seans sayısı ve dakikasına yansıMALIdır; Çalışma Geçmişi toplamı artMALIdır.
- **FR-006**: Cihaz A'nın masaya oturması Cihaz B'de ≤5 sn içinde görünMELİdir (manuel yenileme olmadan).
- **FR-007**: A'nın pomodoro başlatması B'de "başladı" durumu olarak yansıMALI; kalan süre bilgisi canlı ve doğru olMALIdır.
- **FR-008**: Bağlantısı kopan kullanıcının koltuğu diğer istemcilerce makul sürede otomatik boşaltılMALIdır; süre ölçülüp raporlanMALIdır.
- **FR-009**: Aynı koltuğa eşzamanlı iki oturma denemesinden yalnızca biri başarılı olMALIdır; DB'de koltuk başına tek satır kalMALIdır ve kaybeden anlaşılır mesaj görMELİdir.
- **FR-010**: Cloud yazımı başarısız olduğunda kullanıcı bilgilendirilMELİdir; sessiz veri kaybı kabul edilemez.
- **FR-011**: Testler gerçek tamamlama olayıyla yürütülMELİdir; DB'ye elle satır ekleyerek simülasyon YASAKtır (doğrulama sorguları serbesttir).

### Key Entities

- **profiles**: Kullanıcı profili; `points` (puan), `total_minutes` (toplam dakika), `email` (RPC eşleme anahtarı). Realtime publication'da DEĞİL (bilinen kısıt).
- **table_seats**: Sanal kütüphane koltuğu; PK (`table_id`,`seat_index`), `user_email`, `is_pomodoro_started`, `current_timer_seconds`, `completed_pomodoros`. Realtime publication'da ✓.
- **Lokal kategori agregatları**: SharedPreferences'ta; Reports ekranının tek veri kaynağı (cihaza özel, cloud'a yazılmaz — bilinen kısıt).
- **RPC'ler**: `increment_user_stats`, `claim_seat` (FOR UPDATE + PK koruması), `release_seat`, `update_seat_timer` — tümü SECURITY DEFINER.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 1 gerçek pomodoro tamamlanması sonrası puan artışı örneklerin %100'ünde tam +20 (SQL kanıtlı).
- **SC-002**: İzleyen cihazda ranking güncellemesi ≤10 sn (ölçülen süre raporlanır); sağlanamıyorsa kod düzeltilir ve düzeltme sonrası ölçüm tekrarlanır.
- **SC-003**: Koltuk doluluk değişimi izleyen cihazda ≤5 sn içinde görünür.
- **SC-004**: Uçak modu sonrası otomatik koltuk boşalma süresi ölçülür; ≤120 sn hedef, gerçek değer raporlanır.
- **SC-005**: 10 eşzamanlı çift-oturma denemesinde çakışma koruması %100 (hiçbir denemede aynı koltukta iki kullanıcı oluşmaz).
- **SC-006**: Her ✅/❌ sonucu somut kanıt (SQL çıktısı, log satırı, ekran davranışı, ölçülmüş süre) içerir; kanıtsız iddia raporda yer almaz.

## Assumptions

- Supabase projesi (`Pomodoro App`, eu-north-1) aktif; `.env` cloud bağlantısı için dolu; test profilleri mevcut (10 satır).
- "İki cihaz" gereksinimi fiziksel cihaz bulunamazsa iOS Simulator + Android Emulator kombinasyonuyla karşılanabilir; uçak modu testi emülatörde ağ kesme ile simüle edilir.
- Süre kısaltma (örn. 25 dk yerine 1 dk'lık plan) UI'daki mevcut seçeneklerle veya geçici debug değişikliğiyle yapılabilir; tamamlanma OLAYI her durumda gerçek zamanlayıcı bitişiyle tetiklenir.
- Bilinen kod kısıtları (realtime aboneliği yokluğu, sabit 1500 sn yayını, orphan `onPomodoroSessionCompleted`, sessiz hata yutma) test sırasında doğrulanıp gerekiyorsa düzeltilecek; düzeltme öncesi/sonrası ayrı raporlanacak.
