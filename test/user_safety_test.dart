import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/hidden_users.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:pomodoro/widgets/social/user_safety.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Tekil servisler (ve içlerindeki AsyncLock zincirleri) widget testlerinin
  // sahte zamanlı zone'unda değil, gerçek zone'da kurulmalı; yoksa sonraki
  // düz testte kilit hiç açılmaz.
  setUpAll(() {
    expect(SupabaseService.instance, isNotNull);
    expect(TimerPersistence.instance, isNotNull);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HiddenUsersStore.instance.resetForTest();
  });

  group('HiddenUserList eşleme kuralı', () {
    const fromLive = HiddenUser(id: 'u-1', name: 'Ahmet');
    const fromLeague = HiddenUser(name: '  Kötü   Ad ');

    test('kimlik iki tarafta da varsa yalnızca kimlikle eşlenir', () {
      const list = HiddenUserList([fromLive]);
      expect(list.isHidden(id: 'u-1', name: 'Başka Ad'), isTrue, reason: 'ad değişse de gizli');
      expect(list.isHidden(id: 'u-2', name: 'Ahmet'), isFalse, reason: 'aynı adlı başka biri gizlenmez');
    });

    test('kimliksiz satır (Lig/Aylık) adla eşlenir', () {
      const list = HiddenUserList([fromLive]);
      expect(list.isHidden(name: 'Ahmet'), isTrue);
      expect(list.isHidden(name: 'ahmet '), isTrue);
      expect(list.isHidden(name: 'Mehmet'), isFalse);
    });

    test('kimliksiz gizlenen kayıt her satırda adla eşlenir (boşluk/büyük harf farkı yok)', () {
      const list = HiddenUserList([fromLeague]);
      expect(list.isHidden(name: 'kötü ad'), isTrue);
      expect(list.isHidden(id: 'u-9', name: 'Kötü Ad'), isTrue);
      expect(list.isHidden(id: 'u-9', name: 'Kötü'), isFalse);
      expect(list.isHidden(name: ''), isFalse);
      expect(list.isHidden(), isFalse);
    });

    test('ekleme tekrar etmez, çıkarma yalnızca o kaydı siler, JSON gidiş-dönüş', () {
      var list = HiddenUserList.empty.adding(fromLive).adding(fromLive).adding(fromLeague);
      expect(list.length, 2);
      final decoded = HiddenUserList.decode(list.encode());
      expect(decoded.isHidden(id: 'u-1'), isTrue);
      expect(decoded.isHidden(name: 'kötü ad'), isTrue);
      list = list.removing(fromLive);
      expect(list.isHidden(id: 'u-1'), isFalse);
      expect(list.length, 1);
      expect(HiddenUserList.decode('bozuk{').isEmpty, isTrue);
      expect(HiddenUserList.decode('[{"name":""},{"id":"x","name":"Y"}]').length, 1);
    });
  });

  group('HiddenUsersStore (hesaba bağlı, cihazda)', () {
    test(
      'çıkış sırasında bekleyen eski okuma gizli listeyi yeniden yayınlamaz',
      () async {
        SharedPreferences.setMockInitialValues({
          HiddenUsersStore.keyFor('old'): '[{"id":"x","name":"Eski"}]',
        });
        final store = HiddenUsersStore.instance;
        final loading = store.load('old');
        await store.load(null);
        await loading;
        expect(store.hidden.value.isEmpty, isTrue);
      },
    );

    test(
      'hesap silme bekleyen gizli liste okumasını da geçersiz kılar',
      () async {
        SharedPreferences.setMockInitialValues({
          HiddenUsersStore.keyFor('deleted'): '[{"id":"x","name":"Silinen"}]',
        });
        final store = HiddenUsersStore.instance;
        final loading = store.load('deleted');
        await store.forget('deleted');
        await loading;
        expect(store.hidden.value.isEmpty, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(HiddenUsersStore.keyFor('deleted')), isFalse);
      },
    );

    test(
      'eşzamanlı hesap okumalarında son seçilen hesabın listesi kalır',
      () async {
        SharedPreferences.setMockInitialValues({
          HiddenUsersStore.keyFor('a'): '[{"id":"a-hidden","name":"A"}]',
          HiddenUsersStore.keyFor('b'): '[{"id":"b-hidden","name":"B"}]',
        });
        final store = HiddenUsersStore.instance;
        await store.load('a');
        final first = store.load('b');
        final last = store.load('a');
        await Future.wait([first, last]);
        expect(store.hidden.value.isHidden(id: 'a-hidden'), isTrue);
        expect(store.hidden.value.isHidden(id: 'b-hidden'), isFalse);
      },
    );


    test('gizle, sıfırla ve hesaplar birbirinden ayrı', () async {
      final store = HiddenUsersStore.instance;
      await store.hide('me-1', const HiddenUser(id: 'x', name: 'X'));
      expect(store.hidden.value.isHidden(id: 'x'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(HiddenUsersStore.keyFor('me-1')), isNotNull);

      await store.load('me-2');
      expect(store.hidden.value.isEmpty, isTrue, reason: 'başka hesap ilkini görmez');
      await store.load('me-1');
      expect(store.hidden.value.length, 1);

      await store.clear('me-1');
      expect(store.hidden.value.isEmpty, isTrue);
      expect(prefs.getString(HiddenUsersStore.keyFor('me-1')), isNull);

      await store.load(null);
      expect(store.hidden.value.isEmpty, isTrue);
    });

    test('canlı akıştan gizlenenler çıkarılır', () {
      final rows = [
        {'id': 'a', 'name': 'Ayşe'},
        {'id': 'b', 'name': 'Kötü Ad'},
        {'id': 'c', 'name': 'Kötü Ad'},
        {'name': 'Kimliksiz'},
      ];
      const hidden = HiddenUserList([HiddenUser(id: 'b', name: 'Kötü Ad'), HiddenUser(name: 'Kimliksiz')]);
      final visible = SocialScreen.withoutHidden(rows, hidden);
      expect(visible.map((r) => r['id'] ?? r['name']), ['a', 'c']);
      expect(SocialScreen.withoutHidden(rows, HiddenUserList.empty), same(rows));
    });
  });

  group('Sıralamada gizleme', () {
    test('satırdan kimlik okunur; gizli hali sıra/puanı korur, adı ve avatarı atar', () {
      final entry = RankingEntry.fromRow(
        {'id': 'f1', 'name': 'Arkadaş', 'avatar_id': 'avatar_2_glasses', 'lifetime_points': 40, 'total_minutes': 300},
        pointsKey: 'lifetime_points',
      );
      expect(entry.userId, 'f1');
      final hidden = entry.asHidden();
      expect(hidden.hidden, isTrue);
      expect(hidden.name, isNull);
      expect(hidden.avatarId, isNull);
      expect(hidden.userId, isNull);
      expect(hidden.points, 40);
      expect(hidden.minutes, 300);
      expect(RankingEntry.fromRow({'name': 'Lig'}, pointsKey: 'weekly_points').userId, isNull);
    });

    Future<AppLocalizations> pumpStandings(WidgetTester tester, List<RankingEntry> entries, ValueChanged<RankingEntry> onActions,
        {Size size = const Size(390, 844), double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RankingStandings(entries: entries, onEntryActions: onActions),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(RankingStandings)))!;
    }

    List<RankingEntry> entries() => [
          for (var i = 0; i < 8; i++)
            RankingEntry(
              name: i == 4 ? 'Çok uzun isimli bir çalışkan kum saati kullanıcısı' : 'Kullanıcı ${i + 1}',
              points: 1000 - i * 50,
              minutes: 600 - i * 20,
              isMe: i == 5,
            ),
        ]
          ..[6] = const RankingEntry(name: 'Gizli', points: 700, minutes: 480).asHidden();

    testWidgets('menü yalnızca başkalarının satırında; kendi ve gizli satırda yok', (tester) async {
      final opened = <String?>[];
      final l10n = await pumpStandings(tester, entries(), (e) => opened.add(e.name));
      // Liste satırları 4..8: 4, 5 (uzun ad), 6 (ben), 7 (gizli), 8 → 3 düğme.
      expect(find.byType(UserActionsButton), findsNWidgets(3));
      expect(find.text(l10n.hiddenUserLabel), findsOneWidget);
      expect(find.text('Gizli'), findsNothing);

      await tester.tap(find.byType(UserActionsButton).first);
      expect(opened, ['Kullanıcı 4']);

      // Uzun basma: liste satırı ve podyum koltuğu.
      await tester.longPress(find.text('Kullanıcı 8'));
      await tester.longPress(find.text('Kullanıcı 1'));
      expect(opened, ['Kullanıcı 4', 'Kullanıcı 8', 'Kullanıcı 1']);

      // Kendi satırında uzun basma bir şey açmaz.
      await tester.longPress(find.textContaining('Kullanıcı 6'));
      expect(opened.length, 3);
    });

    testWidgets('menü düğmesi büyük metinde ve dar ekranda taşma yaratmaz', (tester) async {
      for (final size in const [Size(390, 844), Size(568, 320), Size(320, 640)]) {
        for (final scale in const [1.0, 2.0]) {
          await pumpStandings(tester, entries(), (_) {}, size: size, textScale: scale);
          expect(tester.takeException(), isNull, reason: '$size x$scale');
        }
      }
    });
  });

  group('Güvenlik menüsü (sheet)', () {
    tearDown(() => SupabaseService.instance.currentUser.value = null);

    Future<AppLocalizations> pumpHost(WidgetTester tester, Size size, double scale, {required bool allowHide}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
        locale: const Locale('tr'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showUserSafetySheet(
                  context,
                  target: const UserSafetyTarget(name: 'Kötü Ad', userId: 'bad-1'),
                  place: UserReportPlace.liveFeed,
                  allowHide: allowHide,
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.text('Kötü Ad')))!;
    }

    testWidgets('dar ve kısa ekranda, büyük metinde taşmaz; arkadaş listesinde yalnızca bildir', (tester) async {
      SupabaseService.instance.currentUser.value = UserModel(id: 'me-1', name: 'Ben', email: 'ben@example.com');
      for (final size in const [Size(390, 844), Size(568, 320), Size(1180, 820)]) {
        for (final scale in const [1.0, 2.0]) {
          final l10n = await pumpHost(tester, size, scale, allowHide: true);
          expect(tester.takeException(), isNull, reason: '$size x$scale');
          expect(find.text(l10n.reportUserAction), findsOneWidget);
          expect(find.text(l10n.hideUserAction), findsOneWidget);
        }
      }
      final l10n = await pumpHost(tester, const Size(390, 844), 1, allowHide: false);
      expect(find.text(l10n.reportUserAction), findsOneWidget);
      expect(find.text(l10n.hideUserAction), findsNothing);
    });

    testWidgets('gizle → listeye eklenir, Geri al → çıkar', (tester) async {
      SupabaseService.instance.currentUser.value = UserModel(id: 'me-1', name: 'Ben', email: 'ben@example.com');
      final l10n = await pumpHost(tester, const Size(390, 844), 1, allowHide: true);
      await tester.tap(find.text(l10n.hideUserAction));
      await tester.pumpAndSettle();
      final store = HiddenUsersStore.instance;
      expect(store.hidden.value.isHidden(id: 'bad-1'), isTrue);
      expect(find.text(l10n.userHiddenMsg('Kötü Ad')), findsOneWidget);
      await tester.tap(find.text(l10n.undoAction));
      await tester.pumpAndSettle();
      expect(store.hidden.value.isHidden(id: 'bad-1'), isFalse);
    });

    testWidgets('oturum yoksa gizleme seçeneği gösterilmez', (tester) async {
      final l10n = await pumpHost(tester, const Size(390, 844), 1, allowHide: true);
      expect(find.text(l10n.hideUserAction), findsNothing);
    });
  });

  group('Hesap silme: cihazdaki kullanıcı verisi', () {
    test('silinen hesabın anahtarları temizlenir, diğerleri kalır; sayaç yeniden yazılmaz', () async {
      const uid = 'deleted-uid';
      const email = 'Silinen@Example.com';
      SharedPreferences.setMockInitialValues({
        'pending_sessions_uid_$uid': '[]',
        'rejected_sessions_uid_$uid': '[]',
        'rejected_sessions_unseen_uid_$uid': 2,
        'pending_sessions_silinen@example.com': '[]',
        'active_session_uid_$uid': '{}',
        'active_session_uid_silinen@example.com': '{}',
        'hidden_users_uid_$uid': '[{"name":"X"}]',
        'onboarding_draft_uid_$uid': '{"step":1}',
        'league_info_shown_$uid': true,
        'league_info_shown_$email': true,
        'daily_goal_migrated_$uid': true,
        'saved_categories_$email': '[]',
        'saved_categories_uid_$uid': '[]',
        // Başka hesap ve cihaz tercihleri korunur.
        'pending_sessions_uid_other': '[]',
        'hidden_users_uid_other': '[{"name":"Y"}]',
        'active_session_uid_other': '{}',
        'theme_mode': 'dark',
        'app_language_code': 'tr',
        'notifications_enabled': true,
      });

      await SupabaseService.instance.clearDeletedAccountLocalData(uid, email: email);

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      expect(keys.where((k) => k.contains(uid) || k.toLowerCase().contains('silinen@example.com')), isEmpty,
          reason: keys.toString());
      expect(
        keys,
        containsAll(<String>[
          'pending_sessions_uid_other',
          'hidden_users_uid_other',
          'active_session_uid_other',
          'theme_mode',
          'app_language_code',
          'notifications_enabled',
        ]),
      );

      // Shell kapanırken sayaç ekranı dispose'da seansı yeniden yazmaya çalışır.
      final session = ActiveTimerSession.start(
        clientUuid: 'c-1',
        categoryId: 'k',
        categoryName: 'Matematik',
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: DateTime(2026, 10, 3, 10),
      );
      await TimerPersistence.instance.save(uid, session);
      expect(prefs.getString(TimerPersistence.keyFor(uid)), isNull);
      // Başka sahipler etkilenmez.
      await TimerPersistence.instance.save('other-owner', session);
      expect(prefs.getString(TimerPersistence.keyFor('other-owner')), isNotNull);
    });
  });
}
