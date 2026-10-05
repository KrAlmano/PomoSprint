import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('classifySessionError', () {
    PostgrestException p0001(String message) => PostgrestException(message: message, code: 'P0001');

    // Canlı complete_study_session'ın (3 Ekim 2026) P0001 metinleri.
    test('canlı: gerçek çakışma hata değil yanıt; eski session_overlap metni de çakışma', () {
      expect(classifySessionResponse({'error': 'overlap'})!.kind, SessionFailureKind.overlap);
      final f = classifySessionError(p0001('session_overlap: bu zaman aralığında başka bir seans var'));
      expect(f.kind, SessionFailureKind.overlap);
      expect(f.reasonCode, SessionReason.overlap);
    });

    test('canlı: 24 saatten eski ve geçersiz süre kalıcıdır', () {
      expect(classifySessionError(p0001('started_at is older than 24 hours')).kind, SessionFailureKind.permanent);
      expect(classifySessionError(p0001('started_at is older than 24 hours')).reasonCode, SessionReason.tooOld);
      expect(classifySessionError(p0001('invalid duration: only 25 or 50 allowed')).kind,
          SessionFailureKind.permanent);
      expect(classifySessionError(p0001('invalid duration: only 25 or 50 allowed')).reasonCode,
          SessionReason.invalidDuration);
    });

    test("canlı: 'not authenticated' geçicidir ve turu durdurur", () {
      expect(classifySessionError(p0001('not authenticated')).kind, SessionFailureKind.offline);
      expect(classifySessionError(p0001('not authenticated')).reasonCode, SessionReason.auth);
    });

    test('canlı: kategori hatası yeniden eşleme ister', () {
      expect(classifySessionError(p0001('category does not belong to this user')).kind,
          SessionFailureKind.categoryInvalid);
      expect(classifySessionError(p0001('category does not belong to this user')).reasonCode,
          SessionReason.categoryInvalid);
      expect(
          classifySessionError(const PostgrestException(
                  message: 'invalid input syntax for type uuid: "1"', code: '22P02'))
              .kind,
          SessionFailureKind.categoryInvalid);
    });

    test('canlı session_not_finished: saat farkı bilinmiyorsa geçici, ama neden saat değil', () {
      // Yeniden denenir (clockSkew türü), ama fark ölçülmediği için
      // kullanıcıya "cihazının saati ileri" denmez: neden not_elapsed.
      final f = classifySessionError(p0001('session_not_finished'));
      expect(f.kind, SessionFailureKind.clockSkew);
      expect(f.reasonCode, SessionReason.notElapsed);
    });

    test('canlı session_not_finished: ölçülen büyük fark clock_skew nedeni taşır', () {
      final f = classifySessionError(
        p0001('session_not_finished'),
        offsetNow: ServerClock.significantSkew + const Duration(seconds: 1),
      );
      expect(f.kind, SessionFailureKind.clockSkew);
      expect(f.reasonCode, SessionReason.clockSkew);
      // Eşiğin hemen altı saat sapması sayılmaz.
      final below = classifySessionError(
        p0001('session_not_finished'),
        offsetNow: ServerClock.significantSkew - const Duration(seconds: 1),
      );
      expect(below.kind, SessionFailureKind.permanent);
      expect(below.reasonCode, SessionReason.notElapsed);
    });

    test('canlı session_not_finished: saat doğruysa kalıcı (ör. debug kısa seans)', () {
      final f = classifySessionError(
        p0001('session_not_finished'),
        offsetNow: const Duration(seconds: 2),
      );
      expect(f.kind, SessionFailureKind.permanent);
      expect(f.reasonCode, SessionReason.notElapsed);
    });

    test('canlı session_not_finished: düzeltme uygulanmamış büyük fark clock_skew', () {
      final f = classifySessionError(
        p0001('session_not_finished'),
        offsetNow: const Duration(minutes: -10),
      );
      expect(f.kind, SessionFailureKind.clockSkew);
      expect(f.reasonCode, SessionReason.clockSkew);
    });

    test('canlı session_not_finished: fark zaten düzeltilmişse kalıcı', () {
      final f = classifySessionError(
        p0001('session_not_finished'),
        offsetNow: const Duration(minutes: -10),
        appliedCorrection: const Duration(minutes: -10),
      );
      expect(f.kind, SessionFailureKind.permanent);
      expect(f.reasonCode, SessionReason.notElapsed);
    });

    test("canlı 'started_at cannot be in the future': saat sapması sınıfı", () {
      expect(classifySessionError(p0001('started_at cannot be in the future')).kind, SessionFailureKind.clockSkew);
      expect(classifySessionError(p0001('started_at cannot be in the future')).reasonCode, SessionReason.futureStart);
      expect(
        classifySessionError(
          p0001('started_at cannot be in the future'),
          offsetNow: const Duration(minutes: -30),
        ).kind,
        SessionFailureKind.clockSkew,
      );
      final f = classifySessionError(
        p0001('started_at cannot be in the future'),
        offsetNow: const Duration(seconds: 1),
      );
      expect(f.kind, SessionFailureKind.permanent);
      expect(f.reasonCode, SessionReason.futureStart);
    });

    test("canlıda olmayan eski 'session_not_elapsed' metni de aynı sınıfa düşer", () {
      expect(classifySessionError(p0001('session_not_elapsed: seans süresi henüz dolmadı')).kind,
          SessionFailureKind.clockSkew);
      expect(
        classifySessionError(p0001('session_not_elapsed'), offsetNow: Duration.zero).reasonCode,
        SessionReason.notElapsed,
      );
    });

    test('süresi dolmuş oturum (PGRST301) geçicidir', () {
      expect(classifySessionError(const PostgrestException(message: 'JWT expired', code: 'PGRST301')).kind,
          SessionFailureKind.offline);
    });

    test('ağ hataları ve zaman aşımı geçicidir', () {
      expect(classifySessionError(Exception('SocketException: Failed host lookup')).kind, SessionFailureKind.offline);
      expect(classifySessionError(TimeoutException('rpc')).reasonCode, SessionReason.timeout);
    });

    test('23505 (yarış) geçicidir; sonraki deneme duplicate döner', () {
      expect(classifySessionError(const PostgrestException(message: 'duplicate', code: '23505')).kind,
          SessionFailureKind.transient);
    });

    test('diğer veri hataları kalıcıdır', () {
      expect(classifySessionError(const PostgrestException(message: 'bad', code: '22003')).kind,
          SessionFailureKind.permanent);
    });

    test('ServiceException içindeki asıl hata sınıflandırılır', () {
      expect(classifySessionError(ServiceException.wrap(TimeoutException('x'))).reasonCode, SessionReason.timeout);
      expect(classifySessionError(const ServiceException(ServiceErrorCode.network)).kind, SessionFailureKind.offline);
      expect(
          classifySessionError(ServiceException.wrap(const PostgrestException(message: 'session_overlap', code: 'P0001')))
              .kind,
          SessionFailureKind.overlap);
    });

    test('bilinmeyen sunucu hatası geçicidir', () {
      expect(classifySessionError(const PostgrestException(message: 'boom', code: 'XX000')).kind,
          SessionFailureKind.transient);
    });
  });

  group('classifySessionResponse', () {
    test('normal yanıt kabul edilmiştir', () {
      expect(classifySessionResponse({'total_points': 5}), isNull);
      expect(classifySessionResponse(null), isNull);
    });

    test("{'error': 'overlap'} sessizce silinmez, çakışma sayılır", () {
      expect(classifySessionResponse({'error': 'overlap'})!.kind, SessionFailureKind.overlap);
    });

    test('diğer {error} yanıtları kalıcı ve kodlu', () {
      final f = classifySessionResponse({'error': 'hourly_limit'})!;
      expect(f.kind, SessionFailureKind.permanent);
      expect(f.reasonCode, 'hourly_limit');
    });
  });

  group('SessionSubmitSuccess.fromResponse', () {
    test('coins_earned varsa onu, yoksa puanı kullanır', () {
      final a = SessionSubmitSuccess.fromResponse(
          {'total_points': 6, 'coins_earned': 3, 'streak': 4, 'duplicate': false}, minutes: 25);
      expect(a.coinsEarned, 3);
      expect(a.streak, 4);
      final b = SessionSubmitSuccess.fromResponse({'total_points': 6}, minutes: 25);
      expect(b.coinsEarned, 6);
      expect(b.streak, isNull);
    });
  });

  group('isServerCategoryId', () {
    test('UUID kabul edilir', () {
      expect(SupabaseService.isServerCategoryId('0f8fad5b-d9cb-469f-a165-70867728950e'), isTrue);
    });

    test("yer tutucu ve zaman damgası ID'leri reddedilir", () {
      expect(SupabaseService.isServerCategoryId('1'), isFalse);
      expect(SupabaseService.isServerCategoryId('1727543210123'), isFalse);
    });
  });

  group('resolveCategoryId', () {
    const cats = <CategoryRef>[
      (id: 'a', name: 'Fizik', isArchived: true),
      (id: 'b', name: 'Matematik', isArchived: false),
      (id: 'c', name: 'fizik ', isArchived: false),
    ];

    test('isimle eşler (büyük/küçük harf ve boşluk duyarsız, aktif öncelikli)', () {
      expect(resolveCategoryId('FİZİK'.toLowerCase(), cats), isNotNull);
      expect(resolveCategoryId('Fizik', cats), 'c');
      expect(resolveCategoryId(' matematik ', cats), 'b');
    });

    test('yalnızca arşivlenmişte eşleşme varsa onu kullanır', () {
      const onlyArchived = <CategoryRef>[
        (id: 'a', name: 'Kimya', isArchived: true),
        (id: 'b', name: 'Matematik', isArchived: false),
      ];
      expect(resolveCategoryId('Kimya', onlyArchived), 'a');
    });

    test('eşleşme yoksa ilk aktif kategori, hiç yoksa null', () {
      expect(resolveCategoryId('Tarih', cats), 'b');
      expect(resolveCategoryId('', cats), 'b');
      expect(resolveCategoryId('Tarih', const []), isNull);
    });
  });

  group('CourseCategory', () {
    test('yer tutucu kategoriler sahte istatistik içermez ve UUID değildir', () {
      for (final c in CourseCategory.initialCategories()) {
        expect(c.sessionsCount, 0, reason: c.name);
        expect(c.totalMinutes, 0, reason: c.name);
        expect(SupabaseService.isServerCategoryId(c.id), isFalse);
        expect(c.colorHex, matches(RegExp(r'^#[0-9A-F]{6}$')));
      }
    });

    test('colorHex verilmezse renkten türetilir', () {
      final c = CourseCategory(id: 'x', name: 'X', color: const Color(0xFF3B82F6), icon: Icons.book_outlined);
      expect(c.colorHex, '#3B82F6');
    });

    test('sunucu satırından kurulur; ikon isimden çözülür', () {
      final c = CourseCategory.fromServerRow({
        'id': '0f8fad5b-d9cb-469f-a165-70867728950e',
        'name': 'Fizik',
        'color_hex': '#3b82f6',
        'icon_name': 'science',
        'is_archived': false,
      });
      expect(c.color.toARGB32(), 0xFF3B82F6);
      expect(c.colorHex, '#3B82F6');
      expect(c.icon, Icons.science_outlined);
      expect(CourseCategory.iconForName('bilinmeyen'), Icons.book_outlined);
    });

    test('JSON gidiş-dönüşü alanları korur', () {
      final original = CourseCategory(
        id: '0f8fad5b-d9cb-469f-a165-70867728950e',
        name: 'Fizik',
        color: const Color(0xFF3B82F6),
        icon: Icons.science_outlined,
        sessionsCount: 3,
        totalMinutes: 75,
        isArchived: true,
        colorHex: '#3B82F6',
        iconName: 'science',
      );
      final copy = CourseCategory.fromJson(original.toJson());
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.color.toARGB32(), original.color.toARGB32());
      expect(copy.icon, original.icon);
      expect(copy.sessionsCount, 3);
      expect(copy.totalMinutes, 75);
      expect(copy.isArchived, isTrue);
      expect(copy.colorHex, '#3B82F6');
      expect(copy.iconName, 'science');
    });

    test('kategori limitleri tek yerden', () {
      expect(categoryLimitFor(isPremium: false), kFreeCategoryLimit);
      expect(categoryLimitFor(isPremium: true), kPremiumCategoryLimit);
    });
  });

  group('providerFirstNameUpdate (Google/Apple ilk ad)', () {
    const testUid = '9f3a51c2-7d4e-4b8a-9c11-2b3d4e5f6a7b';
    String? update({
      required String current,
      String? email = 'q8x7zz2bnd@privaterelay.appleid.com',
      String provider = 'apple',
      Map<String, dynamic> metadata = const {},
      bool onboardingCompleted = false,
      String? givenName,
      String? userId = testUid,
    }) =>
        SupabaseService.providerFirstNameUpdate(
          currentName: current,
          email: email,
          provider: provider,
          metadata: metadata,
          onboardingCompleted: onboardingCompleted,
          givenName: givenName,
          userId: userId,
        );

    test("Apple: trigger'ın yazdığı gizli röle adı, Apple'ın verdiği ilk adla değişir", () {
      expect(update(current: 'q8x7zz2bnd', givenName: 'Ayşe'), 'Ayşe');
      // Onboarding bitmiş olsa bile ad hâlâ e-posta yerel kısmıysa düzeltilir.
      expect(update(current: 'q8x7zz2bnd', givenName: 'Ayşe', onboardingCompleted: true), 'Ayşe');
    });

    // t3-EM1: ad bilgisi olmayan Apple girişinde (ad yalnızca ilk
    // yetkilendirmede gelir; "E-postamı paylaş" seçiliyse yerel kısım gerçek
    // adresin parçası) e-postadan türetilen ad herkese açık listelerde
    // maskelenmeden görünüyordu. Nötr ada çekilir.
    test('Apple ad vermediyse e-postadan türetilen ad nötr adla değişir', () {
      expect(SupabaseService.neutralProfileName(testUid), 'Pomo 9f3a');
      expect(
        update(current: 'erdal.yilmaz.1987', email: 'erdal.yilmaz.1987@icloud.com'),
        'Pomo 9f3a',
      );
      expect(update(current: 'q8x7zz2bnd'), 'Pomo 9f3a');
      // Sonraki girişlerde nötr ad korunur.
      expect(update(current: 'Pomo 9f3a', email: 'erdal.yilmaz.1987@icloud.com'), isNull);
    });

    test('nötr ad (sunucu tohumu) sağlayıcının ilk adıyla değişir', () {
      expect(update(current: 'Pomo 9f3a', givenName: 'Ayşe'), 'Ayşe');
    });

    // proposed/14: handle_new_user'ın nötr adı 'Pomo ' + rastgele 4 rakam.
    // Apple adı yalnızca ilk yetkilendirmede verir; o an yazılmazsa kaybolur.
    test("sunucunun nötr adı ('Pomo 1234') onboarding bitmeden ilk adla değişir", () {
      expect(update(current: 'Pomo 0427', givenName: 'Ayşe'), 'Ayşe');
      expect(update(current: 'Pomo 0427'), isNull, reason: 'ad yoksa nötr ad kalır');
      expect(
        update(current: 'Pomo 0427', givenName: 'Ayşe', onboardingCompleted: true),
        isNull,
        reason: 'onboarding sonrası (ör. moderasyonla sıfırlanmış ad) dokunulmaz',
      );
      expect(update(current: 'Pomo 04271', givenName: 'Ayşe'), isNull);
    });

    test('ilk ad e-postanın yerel kısmıyla aynıysa gerçek addır, dokunulmaz', () {
      expect(
        update(
          current: 'erdal',
          email: 'erdal@gmail.com',
          provider: 'google',
          metadata: const {'full_name': 'erdal Yılmaz', 'given_name': 'erdal'},
          onboardingCompleted: true,
        ),
        isNull,
      );
    });

    test('Google: onboarding bitmeden tam ad ilk ada iner', () {
      const meta = {'full_name': 'Ahmet Yılmaz', 'name': 'Ahmet Yılmaz'};
      expect(update(current: 'Ahmet Yılmaz', email: 'ahmet@gmail.com', provider: 'google', metadata: meta), 'Ahmet');
      expect(
        update(current: 'Ahmet Yılmaz', email: 'ahmet@gmail.com', provider: 'google', metadata: meta, onboardingCompleted: true),
        isNull,
        reason: 'onboarding sonrası (kullanıcı tam adı kendisi seçmiş olabilir) dokunulmaz',
      );
    });

    test('kullanıcının kendi seçtiği ada dokunulmaz', () {
      expect(update(current: 'Kaptan', givenName: 'Ayşe'), isNull);
      expect(
        update(current: 'Mehmet', email: 'm@gmail.com', provider: 'google', metadata: const {'full_name': 'Ahmet Yılmaz'}),
        isNull,
      );
    });

    test('tek harfli ilk ad yazılmaz (sunucu/uygulama alt sınırı); e-posta adı yerine nötr ad', () {
      expect(update(current: 'q8x7zz2bnd', givenName: 'J'), 'Pomo 9f3a');
      expect(update(current: 'Kaptan', givenName: 'J'), isNull);
    });
  });
}
