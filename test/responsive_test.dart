import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/utils/responsive.dart';

void main() {
  group('Responsive.fromSize', () {
    test('dikey telefon compact, alt gezinme', () {
      final r = Responsive.fromSize(const Size(390, 844));
      expect(r.screenClass, ScreenClass.compact);
      expect(r.useSideNavigation, isFalse);
      expect(r.isShortHeight, isFalse);
    });

    test('yatay telefon kısa yükseklik, yan gezinme', () {
      final r = Responsive.fromSize(const Size(844, 390));
      expect(r.screenClass, ScreenClass.expanded);
      expect(r.isLandscape, isTrue);
      expect(r.isShortHeight, isTrue);
      expect(r.useSideNavigation, isTrue);
    });

    test('küçük yatay telefon (568x320) de yan gezinme kullanır', () {
      final r = Responsive.fromSize(const Size(568, 320));
      expect(r.screenClass, ScreenClass.compact);
      expect(r.useSideNavigation, isTrue);
    });

    test('tablet dikey medium, tablet yatay expanded', () {
      expect(Responsive.fromSize(const Size(820, 1180)).screenClass, ScreenClass.medium);
      expect(Responsive.fromSize(const Size(1180, 820)).screenClass, ScreenClass.expanded);
    });

    test('sütun sayısı sınıfa göre', () {
      expect(Responsive.fromSize(const Size(390, 844)).columns(), 1);
      expect(Responsive.fromSize(const Size(820, 1180)).columns(), 2);
      expect(Responsive.fromSize(const Size(1180, 820)).columns(), 3);
    });
  });
}
