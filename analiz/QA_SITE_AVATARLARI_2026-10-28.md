# Site özel avatar görselleri — 28 Ekim 2026

**Düzeltme:** Uygulamadaki 21 özel avatarın statik WebP karşılığı sitede yoktu. `landing/js/main.js` doğru `/avatars/<id>.webp` yolunu üretmesine rağmen istek 404 olduğunda varsayılan Klasik avatar gösteriyordu. 21 eksik dosya mevcut PNG kaynağından eklendi; JS/CSS/HTML, canlı site ve veritabanı değiştirilmedi.

## Kaynak ve çıktı

- Kaynak: 21 adet 1024×1024 PNG, toplam 23.254.419 bayt. Bütün kaynaklar PNG renk türü 2 (RGB); kaynaklarda alfa/şeffaflık yok. Mevcut arka plan korundu, alfa eklenmedi/silinmedi.
- Çıktı: 21 adet 160×160 WebP, toplam 79.918 bayt (78,04 KiB); dosya başına 2.818–4.946 bayt. Mevcut web avatarları da 160×160.
- Komut: `cwebp -q 85 -alpha_q 100 -m 6 -resize 160 160 -metadata none <kaynak> -o <hedef>`; yalnız format/boyut optimizasyonu. Kare en-boy oranı korundu; kırpma veya yeniden çizim yok.
- Her PNG SHA-256 dönüşümden önce/sonra aynı; her çıktı ffprobe ile 160×160 olarak doğrulandı. Gold Miner kaynağı/çıktısı, Shadow Queen ve Samurai çıktıları gözle incelendi; merkezleme/arka plan korunmuş görünüyor. Bu gözlem Safari tarayıcı testi değildir.

## Katalog sayısı

Derlenmiş `AvatarCharacter.fallbackCatalog` ile yerel aktif katalog ID kümeleri birebir aynı 47 öğeyi verdi. Her 47 ID için hem uygulama PNG hem site WebP bulunuyor. Standart kullanıcı için 5 Premium çıkarılınca 42 kalır: 7 başlangıç + 4 normal (200 kum) + 21 özel (500 kum) + 10 lig ödülü. 47 aktif notu 42 ile çelişmez. Pasif `tomato_basic` ve kaldırılmış Ronin dahil değildir.

Yerel `competition_avatar_rewards` tablosunda study türündeki 15 derece yuvası 10 benzersiz görsele bağlı; exam türündeki 15 yuvanın tamamı NULL. Bu 15 boş Deneme yuvası görsel sayısına eklenmedi. Yalnız katalog/ödül eşlemesi okundu; kullanıcı tabloları okunmadı.

## Doğrulama

- Yeni Node regresyonları: dönüşümden önce 2 FAIL / 1 PASS; 21 dosya eklendikten sonra 3/3 PASS. 47 varlığın WebP bütünlüğü, özel avatarın podyum/liste yolu ve geçersiz/olmayan ID için yedek davranışı kapsandı.
- Derlenmiş Dart katalog probe: 1/1 PASS. Yerel DB ID eşitliği, 47/42/21/7/10/5 sayıları ve uygulama/site dosya varlığı doğrulandı.
- Kalıcı Node testi: `scripts/test/landing_avatar_assets.test.mjs`. Derlenmiş probe ve JSON kanıtı `build/overnight_backend/site_avatar_catalog_probe_test.dart`, `site_avatar_compiled_catalog.json`, `site_avatar_db_snapshot.json` altında.
- Yeni dosya + mevcut `landing_release_content` ve `landing_structure` paketleri birlikte 23/23 PASS. Bu sayı yeni 3 testi içerir; 3+23 diye toplanmaz. Çıktılar yerelde hazır, deploy yapılmadı.

## SHA-256 manifesti

Her satırdaki kaynak `assets/avatars/<id>.png`, çıktı `landing/avatars/<id>.webp` yolundadır.

| ID | Kaynak SHA-256 | WebP SHA-256 | WebP bayt |
|---|---|---|---:|
| `special_archaeologist` | `99f8cf187cd3900d852ca670a6c776a9f7b331f07df43b0194035e9d43920187` | `e6e9e406618804a441b5753972685838ad5e0d082dec2575fc365545d004825e` | 3278 |
| `special_astronaut` | `cf7d98ad67ab591cbd8b3c29a6c2f0c4da960d71d82b6bb78f381fb8653fb932` | `3226cf3a259238058df3c367c2c5a9f2312f838751315f3a3d1bf1fc05f3e4de` | 3118 |
| `special_celestial_king` | `fa10254d9b12c69ad25be171a275f1251a9d7c8fa0d2378210cb5260181643e9` | `872a2095bd6d55589a1a950ff39e817a6b2a0c23aacb6d44da911a0bac678dca` | 4880 |
| `special_cowboy` | `14b4549008ba668012c59b8dd1a56701744f247de1d7e91179386577b2831226` | `cbca1ae1705724c5230496ffaa893bdb51a84e52d1101bcd7b89f8316d2140b4` | 4128 |
| `special_crystal_princess` | `c803a35136f7f6e07cfd17230a4b25c928f2ac22c71ceec57deac5e2c47a3842` | `f875671b9783b142e0236f1b21d7f7368c0a1bab4671e895391b66341575052f` | 2818 |
| `special_cyber_robot` | `b5c24f0ef6facf26684c39cabab5b7ba0ca73c0c46ef40eb7f98deff0cff2432` | `26a08a235616bb4f97a545df4a0b7f5c71371b6d11be7141e48771d278a81662` | 4534 |
| `special_desert_princess` | `76d3e725f8fadd12d9cb6aeafa6c0224a08257ca80deaa264224c6fae88bc833` | `28b7038996290fe1006c3b8d633d5c6befd9e62e9dd1046745cd863ec2b05730` | 4374 |
| `special_detective` | `12b217a648036c26a88ab6268d94ab08698b06655667bd1e08ab9221ccfc6a03` | `3780ca45834d6348e0ea670586157fb3d72a4e5cb9ecd7591d601e0806423d67` | 3514 |
| `special_flame_spirit` | `8b677b7dd365dfc1a0f49d26db7957a5a3d4022cc636c879a54b05112ac10ed4` | `0811d8a22e361081998fe4bdda20250a130cb34705170328acaa5c2801886e53` | 4236 |
| `special_forest_fairy` | `34e12423781dc0e5189033993078fc82d43bd39cc3655be1950e0a23832d445e` | `e03708735bc790cdf70f9d09cdf0608a3a5644af4cb733f3244b6175dd2dae5d` | 3380 |
| `special_gold_miner` | `c83654971654ec8b58d6b05f32316230e39b21bcd84924825d8195667cb964aa` | `ded8b6ed9a07b38bbc2a721c4a4eb89025441aeb291f3f0eac5ce3f155763d19` | 3310 |
| `special_light_knight` | `f3fe6d92c583674066eed0f46bc5490881740273e702930db2fc474e6bee59b6` | `4f45023dc2d82215b745b277e2b36b76bc4fc5608f013b459448b7d7553fca35` | 3590 |
| `special_pharaoh` | `6c6bf04fc354ca99fc2f6c3ad1acbc69bbe603fa46d1810a327664fe96d2f809` | `c2dbc0871883cb8ac0d8fa34e6b4d0c50e594297ad7e694238a2010e235c60db` | 4946 |
| `special_pirate_captain` | `0217edb0d98af068cc239cb4ec68f081578a6120fba21e1902c7d5eff8e71e84` | `56a1a959197048f81eae024118cd1ee73ffe2bae9ee596460c653cfa1b191848` | 3812 |
| `special_potion_master` | `8af0da08134692bca705951bea0885191e61a052283512bc44a550cbc7102bea` | `568af0a82a641022ce0c297b26e3e0036f5f0f0442bc3a9e71cab26e730605d5` | 3174 |
| `special_samurai` | `90624886672e43dc2e21c0da6a5055e9ecb844812d7e88ef84ce38b57bfa4933` | `5a949b29d23de42a31128212789df173cf6acf930b1671fdb7dab9c72bf26b89` | 3600 |
| `special_shadow_queen` | `be730e4581cda58499a57d2987d33d1eb32acda1db512633d1ccee52c3ad188e` | `9cf05804d86261bd616fb851aabbf2e804a6b4530522937523241fbbaab50e07` | 4080 |
| `special_star_wizard` | `0d275c79446d21ae86d3d09ee45f2c5f48c0b999b7d27769d56e8f67c5931314` | `aab79bd6bf806e46fea821c1475442f45c6d329189349aa47e398bd69568a3ee` | 3454 |
| `special_steampunk_pilot` | `659bc235cd66528f5773abfec94a2effc8cd6a06af5053d09c8abb3ef9159fec` | `1182313b89390df8cdbe28bcdae8547d89384fa07b6841eefaa663607e2c240a` | 3870 |
| `special_vampire_lord` | `9ad0b9ecb119910ec71ff3f5c056c89a714e34e52638e0d7079d75d6d4613760` | `1c1aa95151d36df7b88f22f5b80dac4e1a9b8b0374693c07704668fe9b7aecd3` | 4646 |
| `special_zen_master` | `c86e240b1506756236b054c01a33f07b74957f072c9d47b6d51d1bfb444391c9` | `8889ea3192a7ef69d557075c8501a1ca327da8ba0159dfde08f38adb8feb1407` | 3176 |

Derlenmiş katalog kanıtının SHA-256: `6ce8a6faae1c3dc8ec238a6c06e1ad5e458eadb7b6e260fe4c613d1667ee71c1`.
