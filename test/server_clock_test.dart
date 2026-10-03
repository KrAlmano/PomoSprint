import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/service_errors.dart';
import 'package:pomodoro/utils/async_lock.dart';
import 'package:pomodoro/utils/color_hex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('parseHttpDate', () {
    test('IMF-fixdate okunur', () {
      expect(parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT'), DateTime.utc(1994, 11, 6, 8, 49, 37));
      expect(parseHttpDate('Sat, 03 Oct 2026 23:05:00 GMT'), DateTime.utc(2026, 10, 3, 23, 5));
    });

    test('geçersiz değerler null', () {
      expect(parseHttpDate(null), isNull);
      expect(parseHttpDate(''), isNull);
      expect(parseHttpDate('yesterday'), isNull);
      expect(parseHttpDate('Sun, 06 Foo 1994 08:49:37 GMT'), isNull);
    });
  });

  group('ServerClock', () {
    test('ilk ölçüme kadar fark bilinmez, düzeltme uygulanmaz', () {
      final clock = ServerClock();
      expect(clock.offset, isNull);
      expect(ServerClock.correctionFor(clock.offset), Duration.zero);
    });

    test('date başlığından fark tahmin edilir', () {
      final clock = ServerClock();
      final sent = DateTime(2026, 10, 3, 12, 0, 0);
      final received = sent.add(const Duration(milliseconds: 400));
      // Sunucu 5 dk geride (cihaz ileri).
      final server = sent.add(const Duration(milliseconds: 200)).subtract(const Duration(minutes: 5));
      clock.recordSample(serverTime: server.toUtc(), sentAt: sent, receivedAt: received);
      expect(clock.offset!.inSeconds, inInclusiveRange(-300, -299));
      expect(ServerClock.correctionFor(clock.offset), clock.offset);
    });

    test('bilinen fark eşiksiz uygulanır (eşiğin iki yanında tutarlı)', () {
      expect(ServerClock.correctionFor(const Duration(seconds: 20)), const Duration(seconds: 20));
      expect(ServerClock.correctionFor(const Duration(seconds: -59)), const Duration(seconds: -59));
      expect(ServerClock.correctionFor(const Duration(seconds: 61)), const Duration(seconds: 61));
      expect(ServerClock.correctionFor(null), Duration.zero);
    });

    test('gürültü bandındaki yeni ölçüm farkı değiştirmez; büyük değişim günceller', () {
      final clock = ServerClock();
      final t = DateTime(2026, 10, 3, 12);
      clock.recordSample(serverTime: t.toUtc(), sentAt: t, receivedAt: t);
      final first = clock.offset;
      clock.recordSample(
          serverTime: t.toUtc().add(const Duration(seconds: 1)), sentAt: t, receivedAt: t);
      expect(clock.offset, first);
      clock.recordSample(serverTime: t.toUtc().add(const Duration(minutes: 3)), sentAt: t, receivedAt: t);
      expect(clock.offset!.inSeconds, inInclusiveRange(180, 181));
    });

    test('gidiş-dönüşü çok uzun ölçüm yok sayılır', () {
      final clock = ServerClock();
      final sent = DateTime(2026, 10, 3, 12);
      clock.recordSample(serverTime: sent.toUtc(), sentAt: sent, receivedAt: sent.add(const Duration(seconds: 30)));
      expect(clock.offset, isNull);
    });
  });

  group('AsyncLock', () {
    test('işlemler sırayla ve tek tek çalışır; hata kilidi kilitli bırakmaz', () async {
      final lock = AsyncLock();
      final log = <String>[];
      final gate = Completer<void>();
      final a = lock.synchronized(() async {
        log.add('a-start');
        await gate.future;
        log.add('a-end');
      });
      final b = lock.synchronized(() async {
        log.add('b');
        throw StateError('x');
      });
      final c = lock.synchronized(() async => log.add('c'));
      await Future<void>.delayed(Duration.zero);
      expect(log, ['a-start']);
      expect(lock.isLocked, isTrue);
      gate.complete();
      await a;
      await expectLater(b, throwsStateError);
      await c;
      expect(log, ['a-start', 'a-end', 'b', 'c']);
      expect(lock.isLocked, isFalse);
    });
  });

  group('colorFromHex', () {
    test('biçimler ve yedek', () {
      expect(colorFromHex('#3B82F6').toARGB32(), 0xFF3B82F6);
      expect(colorFromHex('3b82f6').toARGB32(), 0xFF3B82F6);
      expect(colorFromHex('#803B82F6').toARGB32(), 0x803B82F6);
      expect(colorFromHex('zzz').toARGB32(), 0xFF9E9E9E);
      expect(colorToHex(colorFromHex('#10b981')), '#10B981');
    });
  });

  group('hata kodları', () {
    test('auth hataları koda çevrilir', () {
      expect(authErrorCodeOf(const AuthException('Invalid login credentials')), AuthErrorCode.invalidCredentials);
      expect(authErrorCodeOf(const AuthException('Email not confirmed')), AuthErrorCode.emailNotConfirmed);
      expect(authErrorCodeOf(const AuthException('User already registered')), AuthErrorCode.emailAlreadyRegistered);
      expect(authErrorCodeOf(const AuthException('over_email_send_rate_limit')), AuthErrorCode.rateLimited);
      expect(authErrorCodeOf(const AuthFailure(AuthErrorCode.profileLoadFailed)), AuthErrorCode.profileLoadFailed);
      expect(authErrorCodeOf(TimeoutException('x')), AuthErrorCode.network);
      expect(authErrorCodeOf(Exception('SocketException: Failed host lookup')), AuthErrorCode.network);
      expect(authErrorCodeOf(Exception('???')), AuthErrorCode.unknown);
    });

    test('servis hataları koda çevrilir', () {
      expect(
          serviceErrorCodeOf(const PostgrestException(
              message: 'Ücretsiz planda en fazla 8 kategori aktif olabilir.', code: 'P0001')),
          ServiceErrorCode.categoryLimitReached);
      expect(serviceErrorCodeOf(const PostgrestException(message: 'Bu isimde aktif bir kategori zaten var.')),
          ServiceErrorCode.categoryNameExists);
      expect(serviceErrorCodeOf(const PostgrestException(message: 'Yetersiz bakiye. ...', code: 'P0001')),
          ServiceErrorCode.insufficientCoins);
      expect(serviceErrorCodeOf(const PostgrestException(message: 'Bu avatar kilitli.', code: 'P0001')),
          ServiceErrorCode.avatarLocked);
      expect(serviceErrorCodeOf(const ServiceException(ServiceErrorCode.nameTooShort)), ServiceErrorCode.nameTooShort);
      expect(serviceErrorCodeOf(TimeoutException('x')), ServiceErrorCode.timeout);
      expect(ServiceException.wrap(Exception('ClientException: Connection closed')).code, ServiceErrorCode.network);
    });
  });
}
