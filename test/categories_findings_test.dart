// Kategori yaşam döngüsü bulgularının (CAT-*) yeniden üretimi.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/category_cache.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/categories_management_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/session_queue.dart' show CategoryRef, resolveCategoryId;
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

CourseCategory _cat(String id, String name, {String hex = '#EF4444', bool archived = false}) =>
    CourseCategory.fromServerRow({'id': id, 'name': name, 'color_hex': hex, 'icon_name': 'book', 'is_archived': archived});

late AppLocalizations l10n;

Future<void> _pumpManagement(WidgetTester tester, FakeSupabaseService service) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CategoriesManagementScreen(service: service),
  ));
  await tester.pumpAndSettle();
}

Iterable<String> _callsStartingWith(FakeSupabaseService s, String prefix) => s.calls.where((c) => c.startsWith(prefix));

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageService.instance.setLanguage(AppLanguage.tr);
  });

  group('CAT-01: son aktif kategori ve kabuğun tohumlaması', () {
    testWidgets('son aktif kategori arşivlenemez, nedeni söylenir', (tester) async {
      final service = FakeSupabaseService()..allCategories = [_cat('a', 'Fizik'), _cat('b', 'Matematik', archived: true)];
      await _pumpManagement(tester, service);

      await tester.tap(find.byIcon(Icons.archive));
      await tester.pumpAndSettle();
      expect(_callsStartingWith(service, 'archive'), isEmpty);
      expect(find.text(l10n.categoryLastActiveRequired), findsOneWidget);
    });

    testWidgets('iki aktif kategoriden biri arşivlenebilir', (tester) async {
      final service = FakeSupabaseService()..allCategories = [_cat('a', 'Fizik'), _cat('b', 'Matematik')];
      await _pumpManagement(tester, service);

      await tester.tap(find.byIcon(Icons.archive).first);
      await tester.pumpAndSettle();
      expect(service.calls, contains('archive(a)'));
    });

    test('bulutta yalnız arşivlenmiş kategori varken kopya oluşturulmaz, arşivlenen geri gelmez', () async {
      const email = 'deneme@example.com';
      // Önbellek, B arşivlenmeden önceki hâli tutuyor.
      await CategoryCache.write(email, [_cat('b', 'Matematik')]);
      final service = FakeSupabaseService()..allCategories = [_cat('a', 'Fizik', archived: true), _cat('b', 'Matematik', archived: true)];

      final first = await loadShellCategories(service, email: email, seedAttempted: false);
      expect(_callsStartingWith(service, 'ensureServerCategories'), isEmpty);
      expect(service.allCategories, hasLength(2), reason: 'sunucuda yeni kategori açılmadı');
      expect(first.categories.where((c) => c.id == 'b'), isEmpty);

      // Tohumlama denendikten sonra da boş bulut yanıtı önbelleğe düşmez.
      final second = await loadShellCategories(service, email: email, seedAttempted: true);
      expect(second.categories.where((c) => c.id == 'b'), isEmpty);
    });

    test('hiç kategorisi olmayan hesapta bir kez varsayılanlar oluşturulur', () async {
      final service = FakeSupabaseService();
      final result = await loadShellCategories(service, email: 'x@example.com', seedAttempted: false);
      expect(_callsStartingWith(service, 'ensureServerCategories'), hasLength(1));
      expect(result.seedAttempted, isTrue);
      expect(result.categories.map((c) => c.name), CourseCategory.initialCategories().map((c) => c.name));
    });

    test('bulut erişilemezse önbellek kullanılır', () async {
      const email = 'deneme@example.com';
      await CategoryCache.write(email, [_cat('a', 'Fizik')]);
      final service = FakeSupabaseService()
        ..categoriesFetchErrorOnce = const ServiceException(ServiceErrorCode.network);
      final result = await loadShellCategories(service, email: email, seedAttempted: false);
      expect(result.categories.single.id, 'a');
    });
  });

  testWidgets('CAT-02: yalnız büyük/küçük harf değişen ad kaydedilir', (tester) async {
    final service = FakeSupabaseService()..allCategories = [_cat('k', 'kimya ödevi'), _cat('m', 'Matematik')];
    await _pumpManagement(tester, service);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kimya Ödevi');
    await tester.pump();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(service.calls, contains('update(k, Kimya Ödevi, #EF4444, book)'));
  });

  testWidgets('CAT-02: dokunulmamış çeviri sunucudaki adı korur', (tester) async {
    await LanguageService.instance.setLanguage(AppLanguage.en);
    final service = FakeSupabaseService()..allCategories = [_cat('m', 'Matematik'), _cat('f', 'Fizik')];
    await _pumpManagement(tester, service);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Mathematics'), findsOneWidget);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(service.calls, contains('update(m, Matematik, #EF4444, book)'));
    await LanguageService.instance.setLanguage(AppLanguage.tr);
  });

  testWidgets('CAT-03: kaydedilemeyen sıralama geri alınır, "kaydedilemedi" görünür', (tester) async {
    final service = FakeSupabaseService()..allCategories = [_cat('a', 'Birinci'), _cat('b', 'İkinci')];
    await _pumpManagement(tester, service);
    service
      ..mutationError = const ServiceException(ServiceErrorCode.network)
      ..categoriesFetchErrorOnce = const ServiceException(ServiceErrorCode.network);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Birinci')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(service.calls, contains('order(b,a)'), reason: 'sürükleme sıralamayı denedi');
    expect(
      tester.getTopLeft(find.text('Birinci')).dy,
      lessThan(tester.getTopLeft(find.text('İkinci')).dy),
      reason: 'iyimser sıra geri alındı',
    );
    expect(find.text(l10n.categorySaveError), findsOneWidget);
    expect(find.text(l10n.categoriesLoadError), findsNothing);
  });

  testWidgets('CAT-06: yeni kategorinin varsayılan rengi kullanılmayan ilk palet rengi', (tester) async {
    final service = FakeSupabaseService()..allCategories = [_cat('a', 'Fizik', hex: '#EF4444')];
    await _pumpManagement(tester, service);

    await tester.tap(find.text(l10n.addCategoryTitle));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yeni');
    await tester.pump();
    await tester.tap(find.text(l10n.addBtn));
    await tester.pumpAndSettle();
    expect(service.calls, contains('create(Yeni, #3B82F6, book)'));
  });

  test('CAT-08: yer tutucu seans İngilizce saklanan kategoriye eşlenir', () {
    final categories = <CategoryRef>[
      (id: 'm', name: 'Mathematics', isArchived: false),
      (id: 'p', name: 'Physics', isArchived: false),
    ];
    expect(resolveCategoryId('Fizik', categories), 'p');
    expect(resolveCategoryId('İngilizce', [...categories, (id: 'e', name: 'English', isArchived: false)]), 'e');
    expect(resolveCategoryId('Physics', [(id: 'f', name: 'Fizik', isArchived: false)]), 'f');
  });
}
