import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/category_cache.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// KVKK-16: kullanıcıya bağlı SharedPreferences anahtar adlarında e-posta
// tutulmaz (iOS'ta NSUserDefaults düz plist ve yedeğe girer). Eski e-postalı
// anahtarlar geriye uyumlu okunur ve uid anahtarına taşınır.

const _uid = 'user-uid-1';
const _email = 'ogrenci@example.com';

String _encoded(List<CourseCategory> categories) => jsonEncode(categories.map((c) => c.toJson()).toList());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final categories = CourseCategory.initialCategories().take(2).toList();

  group('CategoryCache', () {
    test('eski e-postalı önbellek okunur ve uid anahtarına taşınır', () async {
      SharedPreferences.setMockInitialValues({'saved_categories_$_email': _encoded(categories)});

      final read = await CategoryCache.read(_email, uid: _uid);

      expect(read?.map((c) => c.name), categories.map((c) => c.name));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_categories_uid_$_uid'), _encoded(categories));
      expect(prefs.containsKey('saved_categories_$_email'), isFalse);
      expect(prefs.getKeys().where((k) => k.contains(_email)), isEmpty);
    });

    test('uid anahtarı varsa o okunur', () async {
      final newer = [categories.first];
      SharedPreferences.setMockInitialValues({
        'saved_categories_uid_$_uid': _encoded(newer),
        'saved_categories_$_email': _encoded(categories),
      });

      final read = await CategoryCache.read(_email, uid: _uid);

      expect(read?.map((c) => c.name), newer.map((c) => c.name));
    });

    test('yazma uid anahtarına gider ve eski e-postalı anahtarı siler', () async {
      SharedPreferences.setMockInitialValues({'saved_categories_$_email': '[]'});

      await CategoryCache.write(_email, categories, uid: _uid);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CategoryCache.keyForUid(_uid)), _encoded(categories));
      expect(prefs.getKeys().where((k) => k.contains(_email)), isEmpty);
    });

    test('kimliği olmayan eski önbellek eski anahtarla çalışmaya devam eder', () async {
      SharedPreferences.setMockInitialValues({});

      await CategoryCache.write(_email, categories);
      final read = await CategoryCache.read(_email);

      expect(read?.map((c) => c.name), categories.map((c) => c.name));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(CategoryCache.keyFor(_email)), isTrue);
    });

    test('bozuk eski kayıt taşınmaz, null döner', () async {
      SharedPreferences.setMockInitialValues({'saved_categories_$_email': 'bozuk{'});

      expect(await CategoryCache.read(_email, uid: _uid), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_categories_uid_$_uid'), isFalse);
    });
  });

  group('SupabaseService', () {
    final user = UserModel(id: _uid, name: 'Öğrenci', email: _email);

    test('lig bilgi anahtarı e-postadan uid anahtarına taşınır', () async {
      SharedPreferences.setMockInitialValues({'league_info_shown_$_email': true});

      await SupabaseService.instance.migrateLegacyEmailKeys(user);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('league_info_shown_$_uid'), isTrue);
      expect(prefs.getKeys().where((k) => k.contains(_email)), isEmpty);
    });

    test('eski anahtar yoksa hiçbir şey yazılmaz', () async {
      SharedPreferences.setMockInitialValues({});

      await SupabaseService.instance.migrateLegacyEmailKeys(user);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('çıkışta uid ve e-posta anahtarlı kategori önbelleği silinir', () async {
      SharedPreferences.setMockInitialValues({
        'saved_categories_uid_$_uid': _encoded(categories),
        'saved_categories_$_email': _encoded(categories),
        'saved_categories_uid_other': _encoded(categories),
      });
      SupabaseService.instance.currentUser.value = user;

      await SupabaseService.instance.signOutFully();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_categories_uid_$_uid'), isFalse);
      expect(prefs.containsKey('saved_categories_$_email'), isFalse);
      expect(prefs.containsKey('saved_categories_uid_other'), isTrue);
      expect(SupabaseService.instance.currentUser.value, isNull);
    });
  });
}
