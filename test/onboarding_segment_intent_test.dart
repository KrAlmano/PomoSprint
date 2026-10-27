import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/onboarding_segment_intent.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const unsupported = PostgrestException(
  message: 'violates check constraint profiles_user_segment_check',
  code: '23514',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OnboardingSegmentIntentStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = OnboardingSegmentIntentStore();
  });

  test(
    'explicit TUS fallback persists selection before null profile write',
    () async {
      final writes = <String?>[];
      final result =
          await SupabaseService.writeOnboardingProfileWithSegmentFallback(
            {'user_segment': 'tus', 'show_in_social_feed': false},
            (values) async {
              writes.add(values['user_segment'] as String?);
              if (values['user_segment'] == 'tus') throw unsupported;
              expect(await store.read('owner-a'), 'tus');
            },
            onUnsupportedSegment: (segment) async {
              expect(
                await store.remember('owner-a', segment, isCurrent: () => true),
                isTrue,
              );
            },
          );
      expect(writes, ['tus', null]);
      expect(result['show_in_social_feed'], isFalse);
      expect(await store.read('owner-a'), 'tus');
    },
  );

  test('accepted onboarding never invents a pending segment', () async {
    var fallbackCalls = 0;
    await SupabaseService.writeOnboardingProfileWithSegmentFallback(
      {'user_segment': 'tus'},
      (_) async {},
      onUnsupportedSegment: (_) async {
        fallbackCalls++;
      },
    );
    expect(fallbackCalls, 0);
    expect(await store.read('owner-a'), isNull);
  });

  test(
    'storage failure aborts before the null fallback can lose intent',
    () async {
      final writes = <Object?>[];
      await expectLater(
        SupabaseService.writeOnboardingProfileWithSegmentFallback(
          {'user_segment': 'tus'},
          (values) async {
            writes.add(values['user_segment']);
            throw unsupported;
          },
          onUnsupportedSegment: (_) async {
            throw StateError('storage unavailable');
          },
        ),
        throwsStateError,
      );
      expect(writes, ['tus']);
    },
  );

  test(
    'compatible later profile load retries once and clears the intent',
    () async {
      await store.remember('owner-a', 'tus', isCurrent: () => true);
      var writes = 0;
      final result = await store.replay(
        'owner-a',
        serverSegment: null,
        isCurrent: () => true,
        writeIfStillNull: (segment) async {
          writes++;
          return segment == 'tus';
        },
      );
      expect(result, 'tus');
      expect(await store.read('owner-a'), isNull);
      await store.replay(
        'owner-a',
        serverSegment: 'tus',
        isCurrent: () => true,
        writeIfStillNull: (_) async {
          writes++;
          return true;
        },
      );
      expect(writes, 1);
    },
  );

  test('unsupported or offline retry keeps the selected target', () async {
    await store.remember('owner-a', 'tus', isCurrent: () => true);
    final result = await store.replay(
      'owner-a',
      serverSegment: null,
      isCurrent: () => true,
      writeIfStillNull: (_) async {
        throw unsupported;
      },
    );
    expect(result, isNull);
    expect(await store.read('owner-a'), 'tus');
    await store.replay(
      'owner-a',
      serverSegment: null,
      isCurrent: () => true,
      writeIfStillNull: (_) async => false,
    );
    expect(await store.read('owner-a'), 'tus');
  });

  test('a different existing server target is never overwritten', () async {
    await store.remember('owner-a', 'tus', isCurrent: () => true);
    var wrote = false;
    final result = await store.replay(
      'owner-a',
      serverSegment: 'lgs',
      isCurrent: () => true,
      writeIfStillNull: (_) async {
        wrote = true;
        return true;
      },
    );
    expect(result, 'lgs');
    expect(wrote, isFalse);
    expect(await store.read('owner-a'), isNull);
  });

  test('new owner never receives another owner pending target', () async {
    await store.remember('owner-a', 'tus', isCurrent: () => true);
    var wrote = false;
    final result = await store.replay(
      'owner-b',
      serverSegment: null,
      isCurrent: () => true,
      writeIfStillNull: (_) async {
        wrote = true;
        return true;
      },
    );
    expect(result, isNull);
    expect(wrote, isFalse);
    expect(await store.read('owner-a'), 'tus');
    expect(await store.read('owner-b'), isNull);
  });

  test(
    'late old-owner response cannot clear or publish into the new owner',
    () async {
      await store.remember('owner-a', 'tus', isCurrent: () => true);
      var current = true;
      final entered = Completer<void>();
      final reply = Completer<bool>();
      final pending = store.replay(
        'owner-a',
        serverSegment: null,
        isCurrent: () => current,
        writeIfStillNull: (_) {
          entered.complete();
          return reply.future;
        },
      );
      await entered.future;
      current = false;
      reply.complete(true);
      expect(await pending, isNull);
      expect(await store.read('owner-a'), 'tus');
      expect(await store.read('owner-b'), isNull);
    },
  );

  test(
    'account deletion retires pending data while a retry is in flight',
    () async {
      await store.remember('owner-a', 'tus', isCurrent: () => true);
      final entered = Completer<void>();
      final reply = Completer<bool>();
      final pending = store.replay(
        'owner-a',
        serverSegment: null,
        isCurrent: () => true,
        writeIfStillNull: (_) {
          entered.complete();
          return reply.future;
        },
      );
      await entered.future;
      final deletion = store.retireOwner('owner-a');
      reply.complete(true);
      expect(await pending, isNull);
      await deletion;
      expect(await store.read('owner-a'), isNull);
      expect(
        await store.remember('owner-a', 'tus', isCurrent: () => true),
        isFalse,
      );
    },
  );

  test('unknown and obsolete owner intents are not written', () async {
    expect(
      await store.remember('owner-a', 'unknown', isCurrent: () => true),
      isFalse,
    );
    expect(
      await store.remember('owner-a', 'tus', isCurrent: () => false),
      isFalse,
    );
    expect(await store.read('owner-a'), isNull);
  });
}
