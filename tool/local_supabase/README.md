# Yerel Supabase test altyapısı

9 Ekim 2026 yayın temizliğinde bu projeye ait yerel test veritabanı, test hesapları, kalıcı Docker verileri ve özel runtime fixture’ları silindi. Çalışan bir yerel QA ortamı veya hazır hesap yoktur. Yeniden denemek için Docker ve aşağıdaki yerel proje başlatılmalıdır. Silinmiş simülatör UUID’leri kullanılmaz; yeni bir test simülatörü/emülatörü oluşturup açıkça seçin.

`project_id = "pomosprint-local"`. Bu proje canlı Supabase’e bağlı değildir ve `supabase link` ile bağlanmamalıdır. Komutlarda daima `--workdir tool/local_supabase` kullanın. Kök `supabase/` dizininde toplu `db push/reset` çalıştırılmaz; canlı SQL kurulumu [SQL rehberindeki](../../supabase/README.md) kullanıcı SQL Editor akışıdır.

## Yeniden kurulum ve ortam

```sh
supabase start --workdir tool/local_supabase
supabase status --workdir tool/local_supabase
```

Başlangıç kaynakları `supabase/migrations/20261004120000_live_snapshot.sql` (4 Ekim’de salt okunur katalogdan alınan şema; kullanıcı satırı içermez) ve `supabase/seed.sql` (27 tarihsel katalog satırı) dosyalarıdır. Bunlar güncel canlı şemanın/kataloğun otomatik kopyası olarak sunulmaz. Yeni özellik testi için ilgili incelenmiş migration zincirini yalnız izole yerel kopyaya uygulayın; tüm kök migration’ları topluca uygulamayın. `parity_check.sh` yalnız repodaki kayıtlı parmak iziyle karşılaştırır; güncel canlı okuması yapmaz.

| Hizmet | Adres |
|---|---|
| API | `http://127.0.0.1:54321` |
| PostgreSQL | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio | `http://127.0.0.1:54323` |
| Mailpit | `http://127.0.0.1:54324` |

Yerel sıfırlama e-postaları Mailpit’te kalır; kişisel e-posta kutusuna teslim edilmez. Kişisel canlı hesap veya üretim ayrıcalıklı anahtarı kullanmayın. Uygulama için yalnız `supabase status` çıktısındaki **yerel anon** anahtarı gerekir; service-role anahtarı istemciye verilmez. Yerel portları güvenmediğiniz ağa açmayın.

## Uygulamayı yerel ortama bağlama

`SUPABASE_URL` ve `SUPABASE_ANON_KEY` birlikte verilmelidir; `lib/services/backend_config.dart` eksik ortam çiftini reddeder. Normal uygulamada sayaç her derlemede25/50dk, Maraton molası300sn ve onayı60sn’dir. Hızlandırılmış kayıt yolu ve QA tamamlanma RPC’leri kaldırılmıştır; kısa unit/widget simülasyonları yalnız test kaynağı içinde kalır.

```sh
flutter run -d <test-cihazı> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<yerel-anon-anahtarı>
```

Android emülatöründe URL `http://10.0.2.2:54321` olur. İki ortam define’ını kaldırınca normal `lib/main.dart` kök `.env` üretim yapılandırmasını kullanır. Yerel derlemeyi kullanıcıya canlı uygulama gibi açık bırakmayın.

## Native uçtan uca test

```sh
xcrun simctl list devices available
SIM_UDID=<yeni-test-simülatörü> tool/local_supabase/e2e/sim/run_sim_e2e.sh a b c d e

adb devices
ANDROID_SERIAL=<emulator-kimliği> tool/local_supabase/e2e/sim/run_android_e2e.sh a b c d e
```

Her iki runner varsayılan `a b c d e` çalıştırır. Cihaz seçimi zorunludur. Android için SDK, JDK ve önceden başlatılmış `emulator-*` gerekir; iOS Xcode/simülatör gerekir. `DEVELOPER_DIR` ile farklı Xcode seçilebilir. Tek platformu ve tek Flutter komutunu aynı anda çalıştırın; Android Gradle iki worker/2GB ile sınırlandırılır.

| Senaryo | Kapsam |
|---|---|
| a | Kayıt ve onboarding |
| b | Sayaç düzeni ve taşma |
| c | Normal25dk kalıcı kayıtla, kapalıyken bitmiş seansın geri yüklenmesi; puan/kum/rapor/lig |
| d | Arkadaş isteği, kabul, görünürlük ve sosyal odak |
| e | Ayarlar ve yerel hesabın silinmesi |
| g | Kendi yerel hesabıyla şifre sıfırlama ekranı, Mailpit akışı, hafta/ay raporu ve bildirim |
| i | Gerçek50dk sayacın duraklatma hakkı, kalıcı kimliği, yeniden açılışı ve ödülsüz iptali |
| j | Yalnız Android’de native bildirim izin/zamanlama/teslim/iptal |
| k | Yalnız iOS’ta provisional bildirim ve ActivityKit kanalı |
| l | Saat dilimi, yasal onay ve arkadaş yönetimi |
| m | Kategori, arşivli rapor, tema/dil, avatar ve route açıkken çıkış |
| n | Kullanıcı şikâyet akışı |
| t | Görünür normal sayaç kontrolleri ve yatay düzen |

Eski hızlandırılmış, tek seferlik çoklu cihaz ve dış fixture’a bağlı senaryolar runner listesinden kaldırılmıştır. Native bildirim testlerindeki birkaç saniyelik alarm teslimi, seans/puan süresini kısaltmaz. Test hesapları yalnız yeni yerel ortamda oluşturulur; native testler platform izinlerini ve seçilmiş test cihazının uygulama tercihlerini değiştirebilir. `c/m` geçmiş normal süreli kalıcı kayıt kullanır; OS süreç öldürme veya gerçek25dk boyunca bekleme kanıtı olarak sunulmaz.

Runner’lar yalnız loopback test hostu başlatır. Log/SQL/ekran görüntüsü çıktıları `build/e2e_sim/` veya `build/e2e_android/` altındadır. `E2E_RUN_ID` ile benzersiz koşu adı, `E2E_SHOT_DIR` ile farklı çıktı klasörü, `E2E_HOST_PORT` ile farklı loopback portu seçilebilir. Ham çıktıları repoya eklemeyin. Her platformun varsayılan koşusu kısa olsa da bazı native izin adımları kullanıcı/sistem koşullarına bağlıdır; kaynaklardaki doğrulamaya bakın.

## Korunan SQL ve regresyon altyapısı

- `supabase/tests/run_local.sh`: yalnız yerel PostgreSQL’de sunucu assertion’ları.
- `tool/local_supabase/parity_check.sh`: kayıtlı şema referansına yerel parite.
- `tool/local_supabase/proposed_chain_check.sh`: öneri zinciri, DRYRUN/ileri gövde ve down kontrolleri; ayrı kopya veritabanında çalışır.
- `tool/local_supabase/e2e/league_launch_independent.py`: izole yerel DB’de25kişilik lig, dönem, terfi/düşme/ödül ve yarış kontrolleri; ana yerel DB veya canlıya yazmaz.
- `test/`, `scripts/test/` ve kalan `integration_test/`: anlamlı birim/widget/native regresyon kaynakları; üretim asset’lerine dahil değildir.

Eski30kişilik kapasite ve kaldırılmış hızlandırılmış RPC’yi kullanan `league_capacity_audit.py` emekliye ayrılmıştır. Güncel lig denetimi için korunan bağımsız SQL testini kullanın. Koşular önce gerekli incelenmiş yerel şemayı gerektirir; yalnız dosyanın varlığı testin çalıştırılmış olduğu anlamına gelmez.

## Durdurma ve veri temizliği

```sh
supabase stop --workdir tool/local_supabase             # yerel veri yedeği kalır
supabase stop --workdir tool/local_supabase --no-backup # bu yerel projeye ait test verisi silinir
```

İkinci komutu testler bittikten sonra çalıştırın. Diğer Docker projelerine, genel `docker prune` komutlarına, canlı Supabase verilerine veya kişisel cihazlara uygulanmaz. Son QA/devir özetleri [PROJE_DEVIR.md](../../PROJE_DEVIR.md) içindedir; silinmiş ham tarihsel kanıtlara bağlı kurulum adımı yoktur.
