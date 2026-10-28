# 32 SQL ve izole sunucu kanıt arşivi — 28 Ekim 2026

Bu klasör taşınabilir JSON/log özetlerini içerir. `<REPO>` proje köküdür. Orijinal `build/` veya `/tmp/` dosyaları taşınmasa da özetler okunabilir. Manifest her çıktı için kaynak yolu, kaynak/çıktı SHA-256, boyut ve dönüşümü kaydeder. `source_hashes_at_archive.json` arşivleme anındaki kodu tanımlar; her koşunun `plan.json` dosyası o koşuda kullanılan SQL hash'lerini ayrı korur. Önceki Python runner sürümleri eksiksiz kaynak anlık görüntüsü olarak saklanmamıştır.

## Sonuçların kapsamı

| Koşu | Gerçek sonuç | Açıklama |
|---|---|---|
| candidate_v1 | 45 başarılı kontrol sonrası hata | Void start_study_session yanıtını JSON sanan harness hatası; genel koşu FAIL. |
| candidate_v2 | 57 başarılı kontrol sonrası hata | Yeni32 SQL'inde PL/pgSQL sid/alias çakışması; düzeltildi. Genel koşu FAIL. |
| candidate_v3 | 90/91 ve hata | QA hesabına verilen ücretsiz avatarlar yanlışlıkla normal ekonomi değişimi sayıldı. Harness düzeltildi; genel koşu FAIL. |
| candidate_v4 | 105/105, exit0 | Kullanıcı kararı beklerken proportional ve full aday dalları yalnız izole fixture'da denendi. Nihai politika diye sunulmaz. |
| final_proportional | 104/104, exit0 | Kullanıcı onaylı geçen süreyle orantılı kum;90 dk yeni AYT 87, eski 7 kum snapshot 3; tam 175. |
| DRYRUN / down | 14 DRYRUN maddesi true; exact roundtrip |104 toplam kontrol içinde doğrulandı. Özel kayıt oluşunca down reddi de doğrulandı. |
| Güvenlik | 33/33 | Ağsız runner/gateway/parite/site bootstrap kontrolleri; `verification/security.log`. |
| HTTP | 5 kontrol | Review gateway sağlık/erişim koruması/Auth health ve gerçek katalog; yalnız salt okuma. Site dosyası iki gateway'in farklı DB'ye bağlı olduğunu ek doğrular. |
| Parite | Review 5/5, site 5/5, ana 27–30 PASS | Aynı32referansı; ana DB değiştirilmedi. |
| Site hazırlama ilk koşu | 23 başarılı kontrol sonrası hata | Son snapshot export'u eski Python varsayılan DB değerine yönelmeyi reddetti. DB kurulumu/paritesi geçmişti; genel koşu yine FAIL. |
| Site salt okuma devamları | 12/12 | Boş users/profiles/attempts/studies ve aynı parite yeniden doğrulandı; hesap kopyalanmadı. |

104 SQL kontrolü ile 33 güvenlik testini tek bir doğal kullanıcı senaryosu saymayın. SQL süreleri kontrollü geçmiş fixture'ıdır; doğal 90 dakika veya native kullanıcı akışı kanıtı değildir. Fiziksel cihaz, prod, e-posta teslimi ve native ekranlar bu arşivin kapsamı dışındadır. Root native kanıtlarını ayrıca ekleyecektir.

`catalog_alignment.json` tarihî iki avatar paketinin yalnız final review klonuna, mevcut bootstrap guard/tarihiyle eklendiğini ve yedi kullanıcı/veri tablosunun hash'inin değişmediğini gösterir. Site DB bu katalogları boş baseline üstüne kaynaklardan kurdu; review QA kullanıcıları aktarılmadı.

## Servis anlık bilgileri

- Review: `pomosprint_review32_final`, gateway 54351 / REST 54352 / Auth 54353; başlangıç PID 41506.
- Site: `pomosprint_site32_final`, gateway 54361 / REST 54362 / Auth 54363; başlangıç PID 44634.
- Bunlar tarihli başlangıç kanıtıdır; süreçlerin hâlen açık olduğunu yalnız bu dosyadan çıkarmayın. Arşivleme sırasında servislere müdahale edilmedi.

## Dosya bütünlüğü

Kaynak SHA orijinal dosyanındır; çıktı SHA taşınabilir arşiv kopyasınındır. JSON biçimleme ve `<REPO>` dönüşümü nedeniyle farklı olabilir. Türetilen özetlerin kaynak dosya SHA'sı ayrıca kaydedildi. Manifest/INDEX kendi hash'ini içermez; bununla döngüsel hash iddiası yapılmaz.

| Çıktı | Bayt | Kaynak SHA-256 | Çıktı SHA-256 |
|---|---:|---|---|
| `candidate_v1_harness_fail/results.json` | 5373 | `8c7da4a05f13d9b6c8c6e5728652c08e3defd9f7edf199be05b6b8b993aafeca` | `8c7da4a05f13d9b6c8c6e5728652c08e3defd9f7edf199be05b6b8b993aafeca` |
| `candidate_v1_harness_fail/plan.json` | 2321 | `df2d095f213000160955347e635e2580395c90757f35354e3711d9c1f3f9951b` | `469444bc2c2b001eb46f1596a6c0500312eb6a52c99c36e94f726fe1559db4d9` |
| `candidate_v1_harness_fail/run.log` | 1631 | `5c4364b1ea3cf8755f3118a877437ca7a93e8f7fcc964fe4fd4071109e2c56da` | `5c4364b1ea3cf8755f3118a877437ca7a93e8f7fcc964fe4fd4071109e2c56da` |
| `candidate_v2_sql_fail/results.json` | 7335 | `dc395da3bbb540391a269c0e19119a2366c8e39055c39dabc7c020dacd1afa68` | `dc395da3bbb540391a269c0e19119a2366c8e39055c39dabc7c020dacd1afa68` |
| `candidate_v2_sql_fail/plan.json` | 2327 | `363aa2f34966e4f9e9e550ca0d372aab27ab312e14da860688fd450e1be6a701` | `b9be8d44139f9728435051a92945509ed42ec6d8b6f6eac808d0812728f4eaf4` |
| `candidate_v2_sql_fail/run.log` | 2813 | `30ee224f9f09ebfabc4ecd2a0deda90404365b95d5eb9af8e8f6debb86aef4bd` | `30ee224f9f09ebfabc4ecd2a0deda90404365b95d5eb9af8e8f6debb86aef4bd` |
| `candidate_v3_harness_fail/results.json` | 10359 | `6cb8c00e04b29e6f98624200d697dd91af70ef4a0aadd081ca5ae10fcb4708be` | `6cb8c00e04b29e6f98624200d697dd91af70ef4a0aadd081ca5ae10fcb4708be` |
| `candidate_v3_harness_fail/plan.json` | 2327 | `a8bcdfa07b0d7b72290e75a50aac6d6d4e1ecb4874cf2549f11641be0527bd09` | `53ed60cd2fdd571b2fb1d1985b68c6ba321fcb1e496a0b64a0b890fcfe597f8c` |
| `candidate_v3_harness_fail/run.log` | 3669 | `a8fd6694972fbd19250eb6f256a51140bea07a2502bae4f2af055bb067364000` | `a8fd6694972fbd19250eb6f256a51140bea07a2502bae4f2af055bb067364000` |
| `candidate_v4_pass/results.json` | 11841 | `244ed23d78bc4bc369afebcad7be42f554ebc5c4da6aeebf97b5a66c3c952b67` | `244ed23d78bc4bc369afebcad7be42f554ebc5c4da6aeebf97b5a66c3c952b67` |
| `candidate_v4_pass/plan.json` | 2327 | `8388dab4fe9b4d1744b087d2c8f08ad9816aab7210f5ab69ad5ce0248bbf38ee` | `91bb6fa532817715a7d931d143536bebf292b2dcd15e3c1634cee6c1ab7e4fc3` |
| `candidate_v4_pass/run.log` | 4247 | `6af0fbe479d56622d80d388aaf8f4a866c58cd0e5a0e03d6b92f2aa74b3e941a` | `6af0fbe479d56622d80d388aaf8f4a866c58cd0e5a0e03d6b92f2aa74b3e941a` |
| `candidate_v4_pass/fixture_summary.json` | 430 | `66394a781ebe55e7bfab56c10eb9386f07e8f7ace82a2e6fed10b4df5f483ffa` | `66394a781ebe55e7bfab56c10eb9386f07e8f7ace82a2e6fed10b4df5f483ffa` |
| `final_proportional_pass/results.json` | 11750 | `90537fa6da2cca741313ecf1b4335c4e63db54224181aa2fe86bfe092018efd1` | `90537fa6da2cca741313ecf1b4335c4e63db54224181aa2fe86bfe092018efd1` |
| `final_proportional_pass/plan.json` | 2239 | `428b57ae22776ef56e4abf05595ab738debae014f03d3e024b5e4a733119e9e1` | `391211f36aed19600c49482c1566e679d04d6315b0747b6701e2a5b4a09d134b` |
| `final_proportional_pass/run.log` | 4217 | `a25fc8192411f0fb3dbde6bdb01c5107b48424d873726f196df68096d0b6e907` | `a25fc8192411f0fb3dbde6bdb01c5107b48424d873726f196df68096d0b6e907` |
| `final_proportional_pass/fixture_summary.json` | 405 | `69d94124a4c40a75361231280085facb030408bbd479b88e78346bec6f71b082` | `69d94124a4c40a75361231280085facb030408bbd479b88e78346bec6f71b082` |
| `final_proportional_pass/catalog_alignment.json` | 1214 | `38302a0488e51fde74a9fffff6dfadd6402043327d73106d082ef1430a82931f` | `38302a0488e51fde74a9fffff6dfadd6402043327d73106d082ef1430a82931f` |
| `final_proportional_pass/snapshot_comparisons.json` | 1069 | `f5dde54db7aba52c01a438363f06e84f3523ace8044589b75d3a4d85b490f7ae` | `15683c780ad2910ed8cec89fb9d151d6810c0f0ced6de138bc45fd9d099570e1` |
| `verification/security.log` | 4816 | `faebbe48bb47344a84460eb0d86ebe3761b5487176908ec9782ea2dedbf62bce` | `faebbe48bb47344a84460eb0d86ebe3761b5487176908ec9782ea2dedbf62bce` |
| `verification/review_parity.log` | 126 | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` |
| `verification/site_parity.log` | 126 | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` |
| `verification/main_parity.log` | 222 | `82d732ba47cead7d635774f9a3d7c040c4c4a177e65732eac22e65ef4830743e` | `82d732ba47cead7d635774f9a3d7c040c4c4a177e65732eac22e65ef4830743e` |
| `stacks/isolated32_stack_state.json` | 1082 | `9bfefb1f0e94a87717c2a0a95deb80a6b9245dacab51c701c1bf1b4c71f65cd0` | `9bfefb1f0e94a87717c2a0a95deb80a6b9245dacab51c701c1bf1b4c71f65cd0` |
| `stacks/isolated32_stack_http_smoke.json` | 917 | `a258a1fd83e470faef1af5778f92bf2d5c66d223b06333ea38c9b9d1b9c3cade` | `a258a1fd83e470faef1af5778f92bf2d5c66d223b06333ea38c9b9d1b9c3cade` |
| `stacks/site32_stack_state.json` | 1089 | `832aa7cee7e0573216dc19dd850687ac210ea568d15b4f2b2c03e3912378fbb0` | `832aa7cee7e0573216dc19dd850687ac210ea568d15b4f2b2c03e3912378fbb0` |
| `stacks/site32_stack_http_smoke.json` | 274 | `5b660e3df3e5002c138bd9572e21aa00dbb1b19d67f4f2ac2dbb82d02ddc9bbc` | `5b660e3df3e5002c138bd9572e21aa00dbb1b19d67f4f2ac2dbb82d02ddc9bbc` |
| `site_bootstrap/20261028T120541Z-001694ae_results.json` | 2835 | `ad55861133ad7c9bc816ca126d1c4a6c7f0d01be6fe43ff407be82af47cac6fc` | `ad55861133ad7c9bc816ca126d1c4a6c7f0d01be6fe43ff407be82af47cac6fc` |
| `site_bootstrap/20261028T120541Z-001694ae_plan.json` | 1069 | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` |
| `site_bootstrap/20261028T120557Z-9d3f20c4_results.json` | 1655 | `2d642fa4ca15c0e4d51efe15b4b85aa6baf188ddc3e399b9553909998f7fdd3a` | `2d642fa4ca15c0e4d51efe15b4b85aa6baf188ddc3e399b9553909998f7fdd3a` |
| `site_bootstrap/20261028T120557Z-9d3f20c4_plan.json` | 1069 | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` |
| `site_bootstrap/20261028T120633Z-d0b8c93b_results.json` | 1655 | `2d642fa4ca15c0e4d51efe15b4b85aa6baf188ddc3e399b9553909998f7fdd3a` | `2d642fa4ca15c0e4d51efe15b4b85aa6baf188ddc3e399b9553909998f7fdd3a` |
| `site_bootstrap/20261028T120633Z-d0b8c93b_plan.json` | 1069 | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` | `901545053dd6254024582336b6b2b6b3e7323ce3a3d26554e5d1dd656ec0b1e8` |
| `source_hashes_at_archive.json` | 2036 | `derived` | `2aecb46c786ba2f7a691d470c8a4a3ede7bd709d42962b7ac12c90a494e812ae` |
