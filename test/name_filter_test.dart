import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/name_filter.dart';

void main() {
  group('NameFilter.isOffensive: engellenenler', () {
    const offensive = [
      'orospu',
      'Orospu Çocuğu',
      'OROSPU',
      '0r0spu',
      'siktir git',
      'S1KT1R',
      'Siktirgit',
      'amk',
      'A M K',
      'Piç',
      'amcık',
      '@mcık',
      'ŞEREFSİZ',
      'şerefsizler',
      'Yavşak',
      'İbne',
      'pezevenk',
      'yarrak',
      'yarrrrak',
      'fuck',
      'f u c k',
      'F.U.C.K',
      'fuuuuck you',
      'Motherfucker',
      'BITCH please',
      'bitches',
      'Hitler',
      'shit',
      'sh1t',
      'Ali​orospu', // sıfır genişlikli boşlukla birleştirilmiş
      'orospú', // aksan
    ];
    for (final name in offensive) {
      test('"$name"', () => expect(NameFilter.isOffensive(name), isTrue, reason: name));
    }
  });

  group('NameFilter.isOffensive: yanlış pozitif yok', () {
    const clean = [
      'Ayşe Yılmaz',
      'Şikayetçi Ali',
      'Sıkı Çalışan',
      'Sıkışık Takvim',
      'Sık Sık Pomodoro',
      'Sikke Koleksiyoncusu',
      'Adamcık',
      'Amasya',
      'Amina',
      'Ibn Sina',
      'Göktürk',
      'Gotham',
      'Tasarımcı Ece',
      'Pusula',
      'Teşekkürler',
      'Scunthorpe',
      'Cocktail Lover',
      'Classic Hourglass',
      'Assassin',
      'Hassan',
      'Bassist',
      'Shiitake',
      'Shitake Fan',
      'Slutsky',
      'Pickle Rick',
      'Epic Gamer',
      'Picasso',
      'Dick Grayson',
      'Ahmet 1453',
      'Kaan',
      'İsmail',
      'Işıl',
      'Matematik Canavarı',
      'Klasik Kum Saati',
      'Ali K.',
    ];
    for (final name in clean) {
      test('"$name"', () => expect(NameFilter.isOffensive(name), isFalse, reason: name));
    }
  });

  group('NameFilter.tokens normalizasyonu', () {
    test('Türkçe büyük/küçük harf ve aksanlar ASCII\'ye katlanır', () {
      expect(NameFilter.tokens('İSMAİL Işıl ÇĞÖŞÜ'), ['ismail', 'isil', 'cgosu']);
    });

    test('leet yalnızca harf içeren parçada çevrilir; yalnızca rakam atılır', () {
      expect(NameFilter.tokens('s1k 1453'), ['sik']);
      expect(NameFilter.tokens('h3ll0 w0rld'), ['hello', 'world']);
    });

    test('harf harf yazım birleştirilir', () {
      expect(NameFilter.tokens('f u c k'), ['fuck']);
      expect(NameFilter.tokens('Ali K. P'), ['ali', 'kp']);
    });
  });

  group('Sağlayıcı adı (Google/Apple) da denetlenir', () {
    test('küfürlü ilk ad profile yazılmaz', () {
      final update = SupabaseService.providerFirstNameUpdate(
        currentName: 'ornek',
        email: 'ornek@example.com',
        provider: 'google',
        metadata: const {'full_name': 'Siktir Git', 'given_name': 'Siktir'},
        onboardingCompleted: false,
        givenName: 'Siktir',
        userId: '0b7c9e2a-1111-4222-8333-944455556666',
      );
      // Küfürlü ad yazılmaz; e-postadan türetilen ad da herkese açık
      // kalmasın diye nötr ada çekilir (t3-EM1).
      expect(update, 'Pomo 0b7c');
    });

    test('normal ilk ad yazılır', () {
      final update = SupabaseService.providerFirstNameUpdate(
        currentName: 'ornek',
        email: 'ornek@example.com',
        provider: 'google',
        metadata: const {'full_name': 'Ayşe Yılmaz', 'given_name': 'Ayşe'},
        onboardingCompleted: false,
        givenName: 'Ayşe',
      );
      expect(update, 'Ayşe');
    });
  });
}
