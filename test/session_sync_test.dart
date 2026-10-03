import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isPermanentSessionError', () {
    test('RPC doğrulama hatası (P0001) kalıcıdır', () {
      const e = PostgrestException(message: 'session_overlap', code: 'P0001');
      expect(SupabaseService.isPermanentSessionError(e), isTrue);
    });

    test('geçersiz veri (22P02) ve kısıt ihlali (23505) kalıcıdır', () {
      expect(SupabaseService.isPermanentSessionError(
          const PostgrestException(message: 'invalid uuid', code: '22P02')), isTrue);
      expect(SupabaseService.isPermanentSessionError(
          const PostgrestException(message: 'duplicate', code: '23505')), isTrue);
    });

    test('süresi dolmuş oturum (PGRST301) geçicidir, seans kuyrukta kalmalı', () {
      const e = PostgrestException(message: 'JWT expired', code: 'PGRST301');
      expect(SupabaseService.isPermanentSessionError(e), isFalse);
    });

    test('ağ hataları geçicidir', () {
      expect(SupabaseService.isPermanentSessionError(Exception('SocketException')), isFalse);
    });
  });

  group('isServerCategoryId', () {
    test('UUID kabul edilir', () {
      expect(SupabaseService.isServerCategoryId('0f8fad5b-d9cb-469f-a165-70867728950e'), isTrue);
    });

    test('yer tutucu ve zaman damgası ID\'leri reddedilir', () {
      expect(SupabaseService.isServerCategoryId('1'), isFalse);
      expect(SupabaseService.isServerCategoryId('1727543210123'), isFalse);
    });
  });

  group('CourseCategory', () {
    test('yer tutucu kategoriler sahte istatistik içermez', () {
      for (final c in CourseCategory.initialCategories()) {
        expect(c.sessionsCount, 0, reason: c.name);
        expect(c.totalMinutes, 0, reason: c.name);
        expect(SupabaseService.isServerCategoryId(c.id), isFalse);
      }
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
  });
}
