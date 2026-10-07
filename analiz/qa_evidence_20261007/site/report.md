# Site ve e-posta bağlantıları QA — 7 Ekim 2026

Kapsam: `landing/`, site yardımcı sayfaları, `scripts/` ağsız testleri ve `unsubscribe` Edge Function. Mobil uygulama, fiziksel cihazlar, canlı Resend/SMTP ve canlı DB denetimi ayrı görevlerde ele alınır. Bu çalışmada canlı hesap oluşturulmadı, posta gönderilmedi, canlıya dağıtım veya üretim veri değişikliği yapılmadı. `.env` içerikleri okunmadı.

## Sonuç

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Başlangıç `cd scripts && npm test` | 35/35 geçti | `npm-baseline.log` |
| İlk tur son `cd scripts && npm test` | 61/61 geçti, 0 hata | `npm-final.log` |
| Son inceleme sonrası tüm `cd scripts && npm test` | 74/74 geçti, 0 hata/atlama; welcome 15 ve unsubscribe 24 dahil | `npm-final-followup.log` |
| `python3 landing/tools/sync_partials.py --check` | çıkış 0 | `partials-check.log` |
| `python3 analiz/qa_evidence_20261007/site/static_audit.py` | 18 HTML, 674 yerel başvuru, 16 CSS varlığı, 30 SRI kontrolü; sorun yok | `static_audit.json` |
| `git diff --check` | çıkış 0 | `diff-check.log` |
| Yerel PostgreSQL salt okunur ILIKE kontrolü | gerçek `%`, `_`, ters bölü ve case eşlemesi doğru; başka adres eşleşmedi | aşağıdaki SQL |
| Yerel tarayıcı kontrolleri | masaüstü, 390×844 telefon, TR/EN bağlantılar ve yardımcı sayfalar geçti | `browser_checks.json`, `local_requests.jsonl` |

Testler sahte Supabase/DOM ile çalışır; SMTP, canlı auth veya üretim DB bağlantısı kurmaz. İlk turda 26 yeni senaryo; parola kurtarma/onay, bekleyen gövde zaman aşımı, canonical yönlendirme ve abonelikten çıkma hata/yeniden deneme yollarını kapsar. Bekleme listesi mevcut testleri onay sözleşmesine göre güncellendi. Son incelemede 6 ek abonelikten çıkma senaryosu yazıldı; bu alt görev toplam 32 yeni senaryo ekledi.

## Düzeltilen bulgular

1. **Bekleme listesi onayı eksikti.** Form artık `email`, `marketing_consent: true`, `consent_text_version: "waitlist-2026-10-03"` gönderiyor. Onay zamanı sunucu trigger'ına bırakıldı. İşaretlenmemiş kutu gönderimi engelliyor. Eski NULL onaylı kayıtlar bu değişiklikle onaylı sayılmaz. 19 B uygulanmadı.
2. **Aylık sıralamada ortak geri sayım yanlış kural kullanıyordu.** İstanbul gece yarısına bağlı sayaç kaldırıldı. Metin, her kullanıcının profil saat diliminde ayın 1'i saat 04:00 çalışma ayı kuralını açıklıyor. Sıralama verisi/RPC değiştirilmedi.
3. **HTTP gövdesi takılınca form sonsuza kadar bekleyebiliyordu.** `config.js` zaman aşımı, yalnız başlıklar gelince temizleniyordu; artık tüm gövde okuması tamamlanana kadar etkin. Gövde takılması ve hata temizliği regresyonları geçti.
4. **Waitlist-only abonelikten çıkma token'ı 200 dönüyor ama satırı silmiyordu.** Fonksiyon iki tablodaki token'ı da buluyor ve ilgili aboneliği iki listeden çıkarıyor.
5. **Bekleme listesi DELETE hatası yutuluyordu.** Fonksiyon 500 döndürüyor; diğer listeyi önce, token sahibini en son siliyor. Token kaybolmadığı için aynı linkle yeniden deneme mümkün. İki yönde DB hatası, kısmi işlem ve yeniden deneme testleri geçti.
6. **Web parola sınırı canlı Auth ile uyuşmuyordu.** Minimum 6→8 olarak JS, iki HTML alanı ve TR/EN metinlerinde hizalandı. 7 karakter API isteği olmadan reddediliyor, 8 karakter kabul ediliyor. Sunucu şifre politikası değiştirilmedi; zayıf parola yanıtı kullanıcıya gösterilmeye devam ediyor.

İlk turda abonelikten çıkma karşı liste eşlemesindeki `%`, `_` ve ters bölü LIKE kaçışı, aşağıdaki **yerel, salt okunur** sorguyla PostgreSQL düzeyinde doğrulandı. Bu kontrol PostgREST'in ayrıca dönüştürdüğü `*` takma adını kapsamıyordu; son incelemede gerçek REST kanıtı ve düzeltme eklendi (aşağıda). Güncel kaynak ILIKE kullanmaz.

```sql
select 'QA_%@Example.com' ilike 'qa\_\%@example.com' as literal_matches,
       'qa_other@example.com' ilike 'qa\_\%@example.com' as unrelated_matches,
       'QA\Name@Example.com' ilike 'qa\\name@example.com' as backslash_matches;
-- literal_matches=true, unrelated_matches=false, backslash_matches=true
```

### Son bağımsız inceleme: case kayıtları ve PostgREST joker takma adı

Yerel/pariteli katalog `waitlist UNIQUE(email)` değerinin büyük/küçük harfe duyarlı, `marketing_subscribers UNIQUE(lower(email))` değerinin duyarsız olduğunu doğruladı. Site formu adresi küçültür; doğrudan REST kaydı farklı case yazımlarını engellemez. İlk token sahibini yalnız id ile silme kodu diğer waitlist yazımını bırakabiliyordu.

Ayrıca PostgREST ILIKE filtre değerinde `*` işaretini `%` jokerine çevirir. İlk sahte SDK yalnız PostgreSQL eşlemesini taklit ettiği için bu kusuru kaçırıyordu. Bu davranış [resmî PostgREST operatör belgesi](https://docs.postgrest.org/en/stable/references/api/tables_views.html) ile doğrulandı. Güncel kaynak [Supabase raw filter](https://supabase.com/docs/reference/javascript/filter) üzerinden `imatch` ve tam adresi sabitleyen, regex metakarakterleri kaçışlanmış desen kullanıyor.

`postgrest_filter_readonly.py` gerçek **yerel REST GET** kanıtını `postgrest_filter_readonly.json` dosyasına kaydetti: mevcut 4 abonede `ilike.*` 4 satır, literal `imatch` yıldız 0 satır, literal diğer metakarakterler 0 satır, mevcut adresin case değişimi 1 satır eşledi. Yalnız sayı/status saklandı; anahtar/e-posta/yanıt satırı kaydedilmedi, DB veya posta mutasyonu yapılmadı.

Yeni işlem sırası: diğer liste → token sahibinin listesindeki aynı adresin diğer id'leri → token sahibinin id'si. Üç aşamadaki hata 500 ile görünür, token sahibi korunur ve aynı bağlantıyla yeniden deneme mümkündür. Case-variant bütün kayıtlar, iki token yolunda `*`, tüm regex metakarakterleri, prefix adresinin korunması ve GET/OPTIONS ile mail güvenlik tarayıcısı davranışı için 6 regresyon eklendi. Odaklı `node --test test/unsubscribe_function.test.mjs` **24/24 geçti**. SQL şeması değiştirilmedi, canlı deploy yapılmadı.

## Yardımcı sayfalar ve tarayıcı davranışı

- Parola sıfırlama: eksik/geçersiz bağlantı, PKCE uyumsuzluğu, token_hash ve implicit akış, adres çubuğundan token temizliği, çok kısa/uzun ve farklı parolalar, zayıf parola sonrası yeniden deneme, süresi geçmiş bağlantı, ağ hatası ve ham sunucu hata metninin gizlenmesi doğrulandı.
- E-posta onayı: parametresiz sayfa yanlış başarı göstermiyor; TR/EN, token temizliği, bağlantı süresi ve yalnız ilgili oturumu kapatma doğrulandı.
- Abonelikten çıkma: sayfa açılışında DELETE yok, yalnız buton/POST; token zorunlu, eski email+token bağlantısı, uyuşmazlık 403, bilinmeyen token idempotent 200, iki liste temizliği ve DB hata/yeniden deneme doğrulandı.
- Worker: HTTP ve www canonical yönlendirmesi yol/sorguyu koruyor; HTTPS ve yerel istek ASSETS'e geçiyor.
- Yerel mock site masaüstünde açıldı; 3 satırlık aylık sıralama fixture'ı, onay kutusu engeli ve başarılı form POST'u görüldü. POST gövdesi `local_requests.jsonl` içinde; kullanılan adres `example.invalid` ve yalnız yerel fixture'a gitti.
- 390×844 görünümde yatay taşma görülmedi; mobil menü ve FAQ açma/kapatma, İngilizce gizlilik bağlantısı doğrulandı. Chrome'da ilk inceleme sırasında konsol hata/uyarı yoktu. Kullanıcı Safari tercihini bildirdikten sonra Chrome otomasyonu bırakıldı.
- Safari'de İngilizce eksik parola bağlantısı, Türkçe parametresiz onay sayfası, İngilizce token'sız abonelikten çıkma sayfası görüldü. Yalnız QA için açılan sekmeler kapatıldı; mevcut kullanıcı sekmeleri korunarak bırakıldı.

Yerel sunucu sayfaların API adresini yalnız verilen yanıt içinde localhost'a çevirir; kaynak `config.js` canlı URL'si değiştirilmedi. Mock verileri canlı uçtan uca test kanıtı değildir. Gerçek Google/Apple girişleri, gerçek posta teslimatı ve farklı Safari telefon boyutları bu alt görevin doğrulanmış kapsamı değildir.

## Yasal metinlerin teknik eşleşmesi

TR/EN gizlilik, KVKK ve hesap silme sayfaları 7 Ekim'e güncellendi. Sunucu engellerinin arkadaşlık/istek/canlı durum erişimine etkisi, bekleme listesi onay alanları ve hesap silme sırasında doğrulanmış hesap e-postasına bağlı liste temizliği açıklandı. Bilinen kullanıcı kimliğiyle bildirim formu `submit_user_report` sözleşmesini kullanır; kimlik yoksa e-posta yolu sürer. Kullanıcı bildirimi ekran/reason/details/name snapshot ve canlı konu snapshot'ı gibi alanlar içerir.

Hesap silme bu bildirimlerdeki hesap referanslarını `ON DELETE SET NULL` ile kaldırır; inceleme kayıtları, anlık görüntüler ve açıklamalar kalabilir. Metinlerde bütün kişisel verinin koşulsuz silindiği iddiası kaldırıldı; destek üzerinden silme talebi yolu açıklandı. Uydurma saklama süresi veya işletme kimliği eklenmedi. Geliştirici adı/adres placeholder'ları kullanıcı tarafından son aşamada tamamlanacak.

## Yayın öncesi kalanlar

- `landing/` değişiklikleri ve `unsubscribe` kaynak sürümü henüz canlıya dağıtılmadı. Fonksiyon `--no-verify-jwt` sözleşmesini korur.
- Güncel kaynakların deploy sonrası salt okunur/izinli smoke kontrolü ve gerçek posta teslimatı ayrı doğrulama gerekir. Bu rapor canlı e-postanın ulaştığını iddia etmez.
- Yasal geliştirici kimliği/adres alanları bilinçli olarak bekliyor. Ana ajan yasal belge sürümü ve devir belgelerini güncelliyor.
- 19 B DB önerisi uygulanmadı; bu QA mevcut 19 A kolonlarıyla uyumlu minimal istemci düzeltmesi yaptı.
