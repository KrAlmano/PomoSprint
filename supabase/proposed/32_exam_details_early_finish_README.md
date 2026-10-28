# Öneri32: Deneme ayrıntıları ve AYT erken bitiş

**Öneri — canlıya ve ana yerel veritabanına uygulanmadı.** Bu paket 27 → 28 → 29 ve bağımsız30 üstüne hazırlanır. **31 kurulmaz.** Kullanıcı erken AYT kumunu geçen süreyle orantılı ve dondurulmuş tam ödüle kadar orantılı olarak seçti: `floor(snapshot_full_coins × elapsed_seconds / planned_seconds)`, dondurulmuş tam ödüle kadar. Yeni AYT90 dakika72 kum, tam süre145 kum verir; eski7 kumluk aktif AYT90 dakikada3, önceki175kumluk snapshot87kum verir. Kaynakta `early_coin_mode=proportional`, `early_enabled=true` vardır.

## Davranış

- Tek tamamlama ödül tablosu: LGS Sözel60, LGS Sayısal70, YDT95, TUS Temel110, TUS Klinik110, DUS120, TYT130, AYT145 Deneme kumu. Sekiz tanımda reward_policy_version2 kullanılır.
- Ödül politikası soru kataloğundan ayrıdır. Sekiz tanımda `reward_policy_version=2`; `catalog_version=1`, soru kotaları ve net bölenleri korunur. Önceden başlayan veya biten kayıtların saklı tanımları ve kazanımları değiştirilmez.
- AYT için ayrı `finish_ayt_early(uuid)` vardır. Eski `complete_exam_attempt(uuid)` süre dolmadan hâlâ reddeder. Diğer yedi sınav erken bitirilemez.
- Erken bitişte server saati kullanılır. Bir tam saniyeden önce ret; puan `min(snapshot_full_points, floor(elapsed_seconds/300))`. Tamamlanan1–59 saniyelik deneme1 adet sayılır,0 dakika/0 puan/0 seri katkısı/0 lig olayı verir.
- Saklı `ends_at` ve `definition.duration_seconds` planlanan değerdir. Gerçek `finished_at`, `elapsed_seconds` ve `credited_minutes` ayrıca döner. Eski rapor tüketicilerinin doğru sayması için tamamlanmış kaydın DTO `duration_seconds` alanı gerçek saniyedir.
- Erken tamamlanan kayıt normal/Maraton başlangıcını planlanan180 dakikanın sonuna kadar engellemez. Çakışma kontrolü tamamlanmış kayıtta gerçek `finished_at` kullanır.
- Deneme puanı/kumu ayrı cüzdana gider; normal puan, normal kum, avatar satın alma ve normal lig değiştirilmez.

## Başlık, not, dört AYT testi

`save_exam_details(p_attempt_id uuid, p_details jsonb, p_subject_results jsonb DEFAULT NULL, p_expected_revision integer DEFAULT NULL)` yalnız sahibin tamamlanmış kaydını günceller.

- `title`: tüm denemelerde isteğe bağlı, baştaki/sondaki boşluklar temizlenir, en fazla120 Unicode karakter, tek satır; boş/null temizler.
- `note`: tüm denemelerde isteğe bağlı, en fazla2000 Unicode karakter; LF ve TAB izinli, diğer kontrol karakterleri yasak; boş/null temizler.
- `selected_module_ids`: yalnız AYT, belirtilirse1–4 benzersiz izinli ID. Eksik alan korunur; yeni istekte null geçersizdir. Eski kayıttaki null “bilinmiyor” demektir; bütün testler çözülmüş varsayılmaz.
- Eksik metadata alanı korunur. `p_subject_results=NULL` sonuçlara dokunmaz; verilen dizi yalnız gönderilen dersleri günceller. Metadata-only Save ve `{}`+sonuç kaydı geçerlidir.
- Neti kayıtlı dersi kapsayan modül çıkarılırsa `exam_scope_conflict`; sonuç sessizce silinmez. Eski `save_exam_results` de seçilmiş kapsamın dışına yazamaz.
- Aynı canonical patch/sonuç tekrarında, eski revision verilse bile duplicate yanıtı döner. Değişen içerikle eski revision `exam_details_conflict` verir. Gerçek net değişikliği de revision artırır. Metadata kaydı ekonomi veya lig olayı üretmez.
- Başlık/not sahip RLS'si ve sahip RPC'sinde kalır; sosyal/global payload'a eklenmez. İstemci bunları kategori, analitik veya hata breadcrumb içeriğine taşımamalıdır.

| ID | Test | Dersler / soru |
|---|---|---|
| `turkish_social_1` | Türk Dili ve Edebiyatı–Sosyal Bilimler-1 | Edebiyat24 + Tarih-1 10 + Coğrafya-1 6 |
| `social_2` | Sosyal Bilimler-2 | Tarih-2 11 + Coğrafya-2 11 + Felsefe Grubu12 + Din Kültürü / Ek Felsefe6 |
| `mathematics` | Matematik |40 |
| `science` | Fen Bilimleri | Fizik14 + Kimya13 + Biyoloji13 |

Dört testin her biri40 sorudur; toplam160 değişmez. Seçilen kapsam ayrıca gösterilir, rapordaki süre derslere dağıtılmaz. Mevcut katalogdaki “İlave Felsefe” aynı alternatif soru kotasıdır; yeni soru eklenmez.

Kaynaklar: [ÖSYM2026 YKS sonuç duyurusu](https://www.osym.gov.tr/2026-yks-sonuclari-aciklandi), [2026 YKS Başvuru Kılavuzu](https://dokuman.osym.gov.tr/pdfdokuman/2026/YKS/basvuru_kilavuz06022026.pdf). Resmî test/soru dağılımı doğrulanmıştır; bu paket sınav süresi veya soru sayısını değiştirmez.

## İstemci sözleşmesi

Başarılı yanıt `{server_time, duplicate, attempt}`. Yeni attempt alanları `planned_duration_seconds`, `elapsed_seconds`, `credited_minutes`, `completion_kind`, `title`, `note`, `selected_module_ids`, `details_revision`. Bilinen eski AYT tanımında modüller yanıt görünümüne eklenir; veritabanındaki eski snapshot değişmez.

`get_exam_config().capabilities`: `exam_details`, `ayt_modules_version`, `ayt_early_finish`. Kapı kapanınca geçmiş kayıtlar okunmaya devam eder. RPC yetkileri authenticated ile sınırlı; yeni özel yardımcılar/politika/yedek tabloları anon, authenticated ve service_role rollerine kapalıdır.

Yeni hata kodları: `exam_early_finish_too_soon`, `exam_early_finish_not_supported`, `exam_early_finish_unavailable`, `exam_definition_unsupported`, `exam_details_invalid`, `exam_scope_conflict`, `exam_details_conflict`. Mevcut `exam_not_found`, `exam_not_active`, `exam_result_invalid`, `exam_overlap`, `exam_not_elapsed` korunur.

Çevrimdışı erken bitiş kabul edilene kadar pending kalır. Süre istemci tıklama zamanından uydurulmaz; sunucunun kabul anı esas alınır. Deadline sonrası ulaşan istek tam tamamlanmaya dönüşebilir. Erken/normal/terk yarışı aynı profil→attempt kilit sırasını kullanır; ilk terminal sonuç kazanır. Modül/başlık/not taslağı, terminal isteğin makbuzu gelmeden kaydedilmiş gibi gösterilmez.

## Doğrulama ve çalıştırma sınırı

Dosyalar `\quit` ile korunur. `supabase db push/reset`, uzak bağlantı, ana yerel katalog değişikliği veya gerçek hesap silme yolu yoktur.

```sh
python3 -m unittest tool/local_supabase/test_isolated32_check.py -v
python3 tool/local_supabase/isolated32_check.py
# Yalnız yeni ve boş yerel klon oluşturarak davranış testleri:
python3 tool/local_supabase/isolated32_check.py --apply-tests
```

İlk komut ağsız altyapı testidir; ikinci komut yalnız plan ve kaynak hash'lerini yazar. `--apply-tests` açıkça seçildiğinde yerel davranış testlerini çalıştırır; varsayılan çağrı hiçbir bağlantı kurmaz. İzole runner boş `pomosprint_overnight_baseline` veritabanından yalnız yeni `pomosprint_review32_dus` oluşturur; var olan veritabanını değiştirmez veya silmez. Sentetik timestamp senaryoları doğal90 dakika/native test diye sunulmaz. Güncel DUS sonuç ve hash'leri `build/isolated32_dus/` altında kalır.

Boş tarihî template'te eksik olabilen iki mevcut avatar paketi de runner önkoşuludur: `20261009190000_special_avatar_catalog` ve `20261009233000_remove_unowned_ronin`. Aradaki sabit katalog tarihi mevcut `prepare_overnight_backend.py` ile aynıdır; Ronin'in sahipsiz olma ve katalog hash kontrolleri gevşetilmez. Bu adım yeni32 özelliği değildir.

DRYRUN, ileri gövdenin birebir kopyasını transaction içinde çalıştırır;15 yapısal kontrolü `DRYRUN_RESULT` hatasıyla bildirip tamamını geri alır. Gerçek davranış kontrolleri, ayrı klonda owner izolasyonu, eski/yeni snapshot,8 tam ödül, erken zaman/puan, tekrar/terk/deadline, metadata-only/partial net, Unicode, scope/revision, normal ekonomi ve rollback korumasını kapsamalıdır. Henüz tamamlanmamış testler başarı sayılmaz. İlk yedi sınavlı aday ve nihai turlar tarihsel kanıttır; DUS ekli yeni tur sekiz sınavı ve güncel tek ödül tablosunu kurar.

## Geri alma

`32_exam_details_early_finish_down.sql` önce fonksiyon/katalog parmak izlerini denetler. Erken tamamlanmış kayıt, başlık/not/seçim/revision veya yeni modüllü aktif AYT varsa **`exam32_rollback_would_lose_data` ile durur**. Bu veriler silinmez, eski projection'a dönülüp yanlış180 dakika gösterilmez.

Bu veriler yoksa eski beş fonksiyon ve katalog birebir geri yüklenir; kazanılmış cüzdan/attempt/net kayıtları geri alınmaz. Veri oluştuğunda operasyonel geri çekme için `early_enabled=false` kapısı kullanılabilir; geçmişi okuyan yeni kolon/projection korunur. Veri kaybettiren otomatik down veya cüzdandan kum geri alma yapılmaz.

## Güncel DUS ekli yerel sonuç

Yeni boş `pomosprint_review32_dus` üzerinde **128/128** kontrol geçti: `build/isolated32_dus/20261028T123844Z-5d4d6b09/results.json`.27/28/29/30 DRYRUN,27→32 bütün zincirin boş-veri down roundtrip’i,8 tam ödül,AYT90 dakika72 kum/18 puan,eski7 ve175kum snapshot koruması veDUS hedef geçişi doğrulandı.31 kurulmadı; eski veritabanlarının geçmişi ve ekonomisi değiştirilmedi. Yeni DUS kaynakları için36 ağsız güvenlik/JSON kontrolü de geçti.

DUS standart planı150 dakika/120 soru:8 temel bilim40 ve8 klinik bilim80 soru. [ÖSYM2026 DUS2 başvuru kılavuzu](https://dokuman.osym.gov.tr/web/2026/9/basvuru-kilavuzu-e1esxj-16163038.pdf), §1.3 ve basılı sayfa40 Tablo1. Kılavuz ders dağılımını yaklaşık olarak tanımlar; uygulama bu standart dağılımı sunar, her gerçek kitapçığın aynı dağılımı taşıdığını iddia etmez.

### DUS standart ders dağılımı

| Grup | Ders | Soru |
|---|---|---:|
| Temel | Anatomi | 6 |
| Temel | Histoloji ve Embriyoloji | 4 |
| Temel | Fizyoloji | 6 |
| Temel | Tıbbi Biyokimya | 6 |
| Temel | Tıbbi Mikrobiyoloji | 6 |
| Temel | Tıbbi Patoloji | 4 |
| Temel | Tıbbi Farmakoloji | 4 |
| Temel | Tıbbi Biyoloji ve Genetik | 4 |
| Klinik | Restoratif Diş Tedavisi | 10 |
| Klinik | Protetik Diş Tedavisi | 10 |
| Klinik | Ağız, Diş ve Çene Cerrahisi | 10 |
| Klinik | Ağız, Diş ve Çene Radyolojisi | 10 |
| Klinik | Periodontoloji | 10 |
| Klinik | Ortodonti | 10 |
| Klinik | Endodonti | 10 |
| Klinik | Çocuk Diş Hekimliği | 10 |

DUS'ta histoloji ve fizyoloji ayrı çalışma kategorileridir. TUS'un mevcut birleşik kategori eşlemesi değiştirilmez. Kimlikler, İngilizce adlar ve kategori anahtarları [exam_catalog_32.json](exam_catalog_32.json) içinde tanımlıdır.

## Önceki yedi sınavlı sonuçlar ve bağlantı düzeni

- Nihai kullanıcı onaylı orantılı politika: **104/104** izole SQL kontrolü, exit0. Kanıt: `build/isolated32/20261028T115853Z-ab6c5588/results.json`.
- İlk denemelerde iki harness varsayımı düzeltildi: void RPC yanıtının JSON sanılması ve yeni QA kullanıcılarının7 ücretsiz avatarının normal ekonomi değişikliği sanılması. Bir yeni SQL hatası da yakalandı: PL/pgSQL `sid` yerel değişkeniyle SQL alias çakışması. Düzeltilen sürüm tam turdan geçti. Eski başarısız kanıtlar saklandı.
- Sonradan avatar katalog hizalaması, yedi kullanıcı/veri tablosunun hash'i değişmeden tamamlandı: aynı kanıt klasöründe `catalog_alignment.json`. Ana27–30 paritesi ve ayrı32 paritesi temiz.
- Runner/gateway/parite/site bootstrap için toplam **33 ağsız güvenlik testi** geçti; yerel gateway'de5 salt okunur HTTP kontrolü ve tam katalog/kapı doğrulaması geçti. Bunlar native kullanıcı akışı yerine geçmez.

İzole Auth/REST bağlantısı:

```sh
python3 tool/local_supabase/parity_check_exam32.py
python3 tool/local_supabase/e2e/isolated32_stack.py start
python3 tool/local_supabase/e2e/isolated32_stack.py status
# Native/medya işi bittikten sonra yalnız kendi servislerini durdurur; DB kalır:
python3 tool/local_supabase/e2e/isolated32_stack.py stop
```

Gateway `127.0.0.1:54351`, REST `54352`, Auth `54353`; tamamı `pomosprint_review32_dus` veritabanına bağlıdır. Ana `54321` API kullanılmaz. Public Supabase yerel JWT fixture'ı kullanılır; auto-confirm açıktır, welcome trigger kapalıdır, yeni e-posta gönderilmez. Docker yalnız mevcut önbellekteki imajı ve yerel Unix context'i kullanır. Stop yalnız sahiplik etiketi doğrulanan container ve kendi gateway PID'sini sonlandırır; veritabanı silmez.

Site çekimlerinde SQL test hesaplarının sıralamada görünmemesi için ayrı, kullanıcı verisi içermeyen `pomosprint_site32_dus` oluşturulur. Kaynak yine kullanıcı/veri tabloları ve Auth'u boş olduğu doğrulanan `pomosprint_overnight_baseline`dır; review veritabanı kopyalanmaz. Aynı avatar +27–30+32 kaynakları kurulur ve aynı parite referansı doğrulanır. B için kurulum anında kullanıcı, profil, deneme ve çalışma kaydı sayıları0 olmalıdır; ardından yalnız kurmaca site hesapları oluşturulur.

```sh
# Varsayılan yalnız plan; --apply yeni DB oluşturur, var olanı ezmez.
python3 tool/local_supabase/prepare_site32_clone.py
python3 tool/local_supabase/prepare_site32_clone.py --apply
# Yalnız fixture hesapları oluşturulmadan önce, boş site kopyasını salt okunur doğrulama:
python3 tool/local_supabase/prepare_site32_clone.py --verify-existing
python3 tool/local_supabase/parity_check_exam32.py --profile site
python3 tool/local_supabase/e2e/isolated32_stack.py start --profile site
python3 tool/local_supabase/e2e/isolated32_stack.py stop --profile site
```

Site profili gateway `54361`, REST `54362`, Auth `54363` kullanır. Yalnız `review` ve `site` adları kabul edilir; serbest DB/URL seçimi yoktur. Review ve site stack'i aynı anda çalışabilir. Güncel site hazırlama kanıtları `build/site32_dus_bootstrap/`, stack durumu `build/verification_20261028/site32_dus_stack/` altındadır. İlk kurulumda son kanıt export'undaki Python varsayılan-DB bağlama hatası veri değiştirmeden reddedildi; hata düzeltilip boş kopya salt okunur yeniden doğrulandı.

### Eski servislerden DUS profillerine geçiş kanıtı

`build/verification_20261028/site_demo_site-oct28_cleanup.json`, eski site kopyasındaki tam7tag/UID/e-posta eşleşmeli hesap için iki aktifTYT'nin0ödüllü public abandon ve dört durumun public cancel ile kapandığını kaydeder. Eski altı observer geçmişi, puan/kum/süre/seri, arkadaşlık ve sonuç hash'leri korunmuştur. Auth girişlerinin oturum/audit değişikliği ekonomi değişikliği sayılmaz. Eski veritabanları silinmemiştir.

`build/verification_20261028/dus_stack_transition.json`, aynı portların yeni DUS DB'lerine yöneldiğini; iki HTTP katalog yanıtında8tür/teködültablosu/reward_policy_version2 veDUS150dk/120soru/16ders bulunduğunu gösterir. Review54351,site54361; mevcut PID'ler değişebilir, state dosyaları authoritative'dir.
