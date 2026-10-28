# DUS sunucu ve bağımsız doğrulama kanıtları —28 Ekim2026

Bu arşiv taşınabilir JSON/log özetidir; `<REPO>` proje kökünü gösterir. `manifest.json` her çıktı için kaynak/çıktı SHA-256 ve dönüşüm bilgisini tutar. Parola, token, container environment veya canlı veri yoktur. Native fotoğraf/video sonucu bu arşivden çıkarılmaz.

## Doğrulananlar

| Alan | Gerçek sonuç | Sınır |
|---|---|---|
| Temiz DUS SQL zinciri |128/128, exit0 | 27→28→29→30→32; 31 yok. Kontrollü zamanlar doğal bekleme değildir. |
| DRYRUN ve down |27,28,29,30 ayrı;32 15 madde | Her DRYRUN rollback ve bütün boş zincir down sonrası schema/row hash eşitliği. |
| Ödül ve süre |8 tür tek tablo;AYT90 dk72 kum/18 puan | Eski7 ve175 kum snapshot korundu;normal ekonomi değişmedi. |
| Altyapı/JSON güvenliği |36/36 | Yalnız fixed review/site profilleri;uzak DSN yok. |
| Oracle regresyonu |34/34 | Eski19 test korundu,yeni15 test eklendi. |
| Gerçek kontrollü SQL hesapları |17 hesap,712/712 | Salt okuma;warnings boş. Doğal veya native süre kanıtı değildir. |
| RLS |3/3 | Net satırı bulunan kaynak hesabı başka QA hesabından0 görünür. |
| Review/site parite |5/5 +5/5 | Aynı DUS schema/catalog/policy,31 yok. |
| Site boş kurulum | Kaynak/targetAuth0;profil/attempt/study0 | Yalnız kaynak SQL kuruldu;reviewQA verisi kopyalanmadı. |
| Eski site temizliği |2 TYT0 ödülleabandon;4 presencekapandı |7 tamtag/UID/e-posta sahibi;bakiyeler,seri,süre,eski6 observerhistory korundu. |
| Stack geçişi | Review54351/site54361 yeniDUSDB'ler | Eski DB'ler silinmedi;yalnız ownedcontainer/PID durduruldu. |

Yeni DUS128 SQL koşusunda FAIL yoktur. Önceki yedi-sınavlı aday/harness/SQL hata geçmişi `../kanit_exam32_2026-10-28/INDEX.md` içinde ayrı tutulur; eski PASS yeni DUS sonucu yerine kullanılmadı. İlk32-aware oracle geliştirmesinde mevcut19 test ve yeni regresyonlar birlikte çalıştırıldı; nihai34 test temizdir.

## Oracle sözleşmesi

Varsayılan `main` eski27–30 kopyasına bağlı kalır. Yalnız açık `review` / `site` seçimi DUS DB'lerini kullanır; şema32 yokken erken tamamlama kabul edilmez.32'de gerçek bitiş/elapsed,snapshot ödülü,payload gerçek/planlanan süre,0 dakika tamamlanma sayısı ve0 seri/olay ayrımı denetlenir. Çalışma günü profil IANA 04:00;lig ayı gerçek bitişin İstanbul00:00 sınırıdır. Özel başlık/not içerikleri beklenen/gerçek tanılama alanlarına aktarılmaz.

Kaynak güncellemesi sonrası `source_hashes.json` yeniden üretilmedikçe bu dosya sonraki kodun doğrulandığı anlamına gelmez. Aynı şekilde startup-state PID/portları tarihî bir anı gösterir; servislerin sonsuza kadar açık kaldığı iddia edilmez.

## Dosya bütünlüğü

| Çıktı | Bayt | Kaynak SHA-256 | Çıktı SHA-256 |
|---|---:|---|---|
| `sql/results.json` | 14573 | `1e46e7eeb5f8950e29801e1fc8e4be64ed40b2ea023a0288d45caa99735920ff` | `1e46e7eeb5f8950e29801e1fc8e4be64ed40b2ea023a0288d45caa99735920ff` |
| `sql/plan.json` | 2543 | `2580f8145c77859075c442664102cdff1f297d8ff5892fbc3d58c295a200ba25` | `7c1a25d8ceee5a4de33b93f60da6dbd145f0c67ffa803e63a44d8785ee350cab` |
| `sql/completed_fixture_summary.json` | 405 | `93dab15314febafeadb91618260dc99a93a7e960ac1e26c168224d5f9ec92fc0` | `93dab15314febafeadb91618260dc99a93a7e960ac1e26c168224d5f9ec92fc0` |
| `sql/run.log` | 5270 | `998b400b45a5d054c761df54dfda5e9aded03d665aaf980444c0b6ed864df8b7` | `998b400b45a5d054c761df54dfda5e9aded03d665aaf980444c0b6ed864df8b7` |
| `sql/snapshot_comparisons.json` | 2483 | `c33fadb8060dbc51e19bb91169bd46fac989734374f0314ab33ced9c93dfa984` | `17924e8d7a3480523dbd9005b07967dadd76155ea32624c1a2c139b7018999e8` |
| `site_empty_bootstrap/results.json` | 2821 | `5cc79e015544411b534a9acb587006f6f6971e01949457dd9e8270ef9ba2e4fe` | `5cc79e015544411b534a9acb587006f6f6971e01949457dd9e8270ef9ba2e4fe` |
| `site_empty_bootstrap/plan.json` | 1067 | `e09ef9a3e2f07c255d5b0d753a7954cc7b2fb28f94d59070a03f2336ab44ee43` | `e09ef9a3e2f07c255d5b0d753a7954cc7b2fb28f94d59070a03f2336ab44ee43` |
| `site_empty_bootstrap/run.log` | 1068 | `70e23498ad9734c2e9b19493d2d54cb68eec509be204dd87bf0e7ff8c822fc23` | `a5af79053d05961ab4cdbdf17f0289ff63ef12fdbffc3b27c555b7d42795dfa2` |
| `checks/infrastructure36.log` | 5342 | `7cef658ae7b7ed539baa6d0759b6958ccfeae9e6ea294825607c74b771aa82ba` | `7cef658ae7b7ed539baa6d0759b6958ccfeae9e6ea294825607c74b771aa82ba` |
| `checks/oracle34.log` | 6503 | `e89a16cd87f88d88e850d270d148584367cc1e349f1144288a9420c594e4aa1f` | `e89a16cd87f88d88e850d270d148584367cc1e349f1144288a9420c594e4aa1f` |
| `checks/review_parity.log` | 126 | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` |
| `checks/site_parity.log` | 126 | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` | `9846ca0309cf084100fa78369e9e7b3d1a1432db412cd7f9404ac63a66b60562` |
| `oracle_actual/00405be5-c06b-45c5-8827-49c13027a256.json` | 15809 | `baa1da3403db12674c23e48e097a343e7c4682742f8ff87070793a6b75446359` | `baa1da3403db12674c23e48e097a343e7c4682742f8ff87070793a6b75446359` |
| `oracle_actual/26d414b2-ea62-4920-bc97-e44249b57e31.json` | 15799 | `32b4b76511b39f8f496f9f46e3fc189c42f9c171ea75431f60d8eb564cf4b023` | `32b4b76511b39f8f496f9f46e3fc189c42f9c171ea75431f60d8eb564cf4b023` |
| `oracle_actual/334ea36e-b88d-4ef3-a69c-0e6797ddeb76.json` | 13590 | `15018512a0cd30ddf56bddafe8e0ca3cfa57cb497e8a1cca8b23a76017c51c45` | `15018512a0cd30ddf56bddafe8e0ca3cfa57cb497e8a1cca8b23a76017c51c45` |
| `oracle_actual/35cb1de7-99dc-4ca9-b797-6859f4b64cf2.json` | 15831 | `33fdfa3803ddc8d7fb9fcba5d0038067c5e07719a5fba864cd648bdc5839a426` | `33fdfa3803ddc8d7fb9fcba5d0038067c5e07719a5fba864cd648bdc5839a426` |
| `oracle_actual/5e842475-ab0b-43d1-b5a6-3272a827169e.json` | 14969 | `0245ac98ad2968a3d6ca1e286da6e283fb83e1081ab348026650bd8d9d02b87f` | `0245ac98ad2968a3d6ca1e286da6e283fb83e1081ab348026650bd8d9d02b87f` |
| `oracle_actual/601e099c-cd0b-44c7-8775-885382cc6490.json` | 15853 | `8dc6c6fedd8f2dee1cb501f46669a644143f387a0cbb07f0606f5b1dc0437120` | `8dc6c6fedd8f2dee1cb501f46669a644143f387a0cbb07f0606f5b1dc0437120` |
| `oracle_actual/76493d9c-db55-4d2c-8e20-5900601e1fc4.json` | 17922 | `a701949913cc4210162b9e189333243aa03c7561c2a0e2c5ef5ab7dfe5d9cabb` | `a701949913cc4210162b9e189333243aa03c7561c2a0e2c5ef5ab7dfe5d9cabb` |
| `oracle_actual/77fd5dbe-199a-4626-aed1-ee6b3aa463d6.json` | 13584 | `3c01e6d27bac83baaa8bf7bab3411214d5387eb4b98bb9f93a1e8a6a46837c4d` | `3c01e6d27bac83baaa8bf7bab3411214d5387eb4b98bb9f93a1e8a6a46837c4d` |
| `oracle_actual/7984d0da-59a3-4818-9466-af30b87e0b88.json` | 15811 | `0e6e07237eeb777bd608850d285793c266a7a6e54be27728aa10ab870432b5e0` | `0e6e07237eeb777bd608850d285793c266a7a6e54be27728aa10ab870432b5e0` |
| `oracle_actual/8eb15e59-4190-49ea-8717-cd36ce27941f.json` | 15821 | `85d194b837c84be4610514e01dcd6401deeb673fa1b0d4f80e6b22d3c291a3c1` | `85d194b837c84be4610514e01dcd6401deeb673fa1b0d4f80e6b22d3c291a3c1` |
| `oracle_actual/bca0077d-8420-4d1b-b3da-23dab212eedb.json` | 15829 | `354b60bf4047ca2efce1ddff74ecb81416b19ea72f5cc5cd0e43cc510fb6588f` | `354b60bf4047ca2efce1ddff74ecb81416b19ea72f5cc5cd0e43cc510fb6588f` |
| `oracle_actual/c2fb167e-1fd0-4b8c-ba7d-1d514459b20f.json` | 15878 | `8d71fcba00f40fb3c4da7c1ca85bd6e9d3265df8f4eadffcdcb4670407f75ff2` | `8d71fcba00f40fb3c4da7c1ca85bd6e9d3265df8f4eadffcdcb4670407f75ff2` |
| `oracle_actual/d19bf680-3ae0-4104-9277-803c7f1b7190.json` | 15821 | `1ab4ae02651477eb79ded2b9d346be318a99738efdce4c456a5342f62806500a` | `1ab4ae02651477eb79ded2b9d346be318a99738efdce4c456a5342f62806500a` |
| `oracle_actual/e263ede9-6940-4077-ab67-138faa6a08ce.json` | 15815 | `5749369edc6bf3a88b7c875bea6ba9f9755dffd88eab3314b9cb167c53202b41` | `5749369edc6bf3a88b7c875bea6ba9f9755dffd88eab3314b9cb167c53202b41` |
| `oracle_actual/e44e2c6f-daf3-4c50-9e5d-f7c6b02a7b63.json` | 15868 | `81ebe9a6099d2c60b8fa735f61fa7a98aaf3c75e774e43db6abb310e6d8993d7` | `81ebe9a6099d2c60b8fa735f61fa7a98aaf3c75e774e43db6abb310e6d8993d7` |
| `oracle_actual/e9f79645-c9bd-4b62-8dd4-b7c762017a45.json` | 15831 | `5d835c84c5c905e269d09c72f9683283c08a3791c3bf3d41c6ec90c3a23d3d8a` | `5d835c84c5c905e269d09c72f9683283c08a3791c3bf3d41c6ec90c3a23d3d8a` |
| `oracle_actual/ffa14bbe-9b9e-46ab-8201-cff898f46ee4.json` | 15835 | `0b0dd335bc602b18d6d1bedd3c78b4321466645a82437b7b13e5d77c40a4d63c` | `0b0dd335bc602b18d6d1bedd3c78b4321466645a82437b7b13e5d77c40a4d63c` |
| `oracle_actual/peer_rls.json` | 18293 | `75a3b4d5a5393399cb0c3edb08abacf8b345cdecabe7e49df6ed4da9e74674e1` | `75a3b4d5a5393399cb0c3edb08abacf8b345cdecabe7e49df6ed4da9e74674e1` |
| `oracle_actual/summary.json` | 4195 | `02bebd0e822475b424eb045f38056a187b2226fcdb965a34b1718a90d3682c58` | `02bebd0e822475b424eb045f38056a187b2226fcdb965a34b1718a90d3682c58` |
| `transition/old_site_cleanup.json` | 6323 | `5969bb22e02337425c5dd9057e55f787dbcf58b3bbb656585ec25477a4e64db2` | `5969bb22e02337425c5dd9057e55f787dbcf58b3bbb656585ec25477a4e64db2` |
| `transition/dus_stack_transition.json` | 1532 | `00ee497b6bff90f49551110a2ab233a6d628d6c87e7d9acc227a462d500c6096` | `00ee497b6bff90f49551110a2ab233a6d628d6c87e7d9acc227a462d500c6096` |
| `transition/isolated32_dus_stack_startup_state.json` | 1119 | `87148db0244c7953cf25d01478775855ca4fb52da99ba2b52985792552cbb66f` | `87148db0244c7953cf25d01478775855ca4fb52da99ba2b52985792552cbb66f` |
| `transition/site32_dus_stack_startup_state.json` | 1103 | `e90e89543766fceaa12790a6f1f765d9a9bd8f2eddcdb2aabc1b8ebc2466107a` | `e90e89543766fceaa12790a6f1f765d9a9bd8f2eddcdb2aabc1b8ebc2466107a` |
| `catalog/exam_catalog_32.json` | 16765 | `568e2aacc003405f8116874c7210b01a7ab8227e03f1906ddac15acc23a38cc2` | `568e2aacc003405f8116874c7210b01a7ab8227e03f1906ddac15acc23a38cc2` |
| `source_hashes.json` | 2862 | `derived` | `6318ea88c7327e865c56c63b878e24072acd7a7219b32b7f66c1dc73cdd2c16e` |
| `official_source.json` | 486 | `derived` | `35826d476c8b47caa2a3ad0851664e85991ed49f200831de6d4218fb1658fc65` |
