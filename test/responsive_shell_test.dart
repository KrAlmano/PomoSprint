import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/screens/splash_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/responsive.dart';
import 'package:pomodoro/widgets/auth/auth_error_banner.dart';
import 'package:pomodoro/widgets/auth/category_name_dialog.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:pomodoro/widgets/shell_app_bar.dart';
import 'package:pomodoro/widgets/shell_navigation.dart';
import 'package:pomodoro/widgets/shell_pending_banner.dart';
import 'package:pomodoro/widgets/shell_stat_pill.dart';
import 'package:pomodoro/widgets/snackbar_width_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kabuk, sayaç ve giriş akışının hedef ekran boyutlarında taşmadığını
// (RenderFlex overflow ya da başka bir yerleşim hatası olmadığını) doğrular.

const _phonePortrait = Size(390, 844);
const _phoneLandscape = Size(844, 390);
const _smallPhoneLandscape = Size(568, 320);
// iPhone SE (1. nesil) / iPod touch dikey: iOS 15'te desteklenen en küçük ekran.
const _smallPhonePortrait = Size(320, 568);

const _targetSizes = <Size>[
  _phonePortrait,
  _phoneLandscape,
  _smallPhoneLandscape,
  _smallPhonePortrait,
  // iPad çoklu pencere: Slide Over / Split View 1/3 (320 pt) ve 1/2 (~507 pt).
  Size(320, 1000),
  Size(507, 1024),
  Size(820, 1180),
  Size(1180, 820),
  Size(1366, 1024),
];

bool _isLandscape(Size size) => size.width > size.height;

void _setView(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {double textScale = 1}) {
  return MaterialApp(
    locale: const Locale('tr'),
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget home, {
  double textScale = 1,
  double keyboard = 0,
  bool settle = true,
}) async {
  _setView(tester, size, keyboard: keyboard);
  await tester.pumpWidget(_app(home, textScale: textScale));
  // Sürekli dönen yükleniyor göstergesi olan ekranlar yerleşmeyi beklemez.
  settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 100));
}

void _expectNoLayoutError(WidgetTester tester, String context) {
  expect(tester.takeException(), isNull, reason: context);
}

const _destinations = [
  ShellDestination(icon: Icons.timer_outlined, selectedIcon: Icons.timer, label: 'Pomo'),
  ShellDestination(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Raporlar'),
  ShellDestination(icon: Icons.leaderboard_outlined, selectedIcon: Icons.leaderboard, label: 'Sıralama'),
  ShellDestination(icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Sosyal'),
];

/// Ana kabuktaki gibi: üst çubuk + gezinme + gövde (Supabase olmadan).
Widget _shell({required Widget body, int selectedIndex = 0, ValueChanged<int>? onSelect, bool showNavigation = true}) {
  return Builder(
    builder: (context) => ShellNavigationScaffold(
      showNavigation: showNavigation,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect ?? (_) {},
      destinations: _destinations,
      appBar: showNavigation
          ? buildShellAppBar(
              context,
              streakDays: 12,
              points: 1234567,
              coins: 98765,
              onStatsTap: () {},
              onFriendsTap: () {},
              onProfileTap: () {},
              avatarBuilder: (size) => AvatarWidget(avatar: AvatarCharacter.byId(null), size: size),
            )
          : null,
      body: body,
    ),
  );
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('sayac $_count'),
      ),
    );
  }
}

void main() {
  group('Kabuk', () {
    testWidgets('üst çubuk ve Puan/Kum rozetleri taşmaz', (tester) async {
      for (final size in _targetSizes) {
        for (final scale in [1.0, 2.0]) {
          await _pumpAt(tester, size, _shell(body: const SizedBox.expand()), textScale: scale);
          _expectNoLayoutError(tester, '$size x$scale');

          final appBar = tester.getRect(find.byType(AppBar));
          // Yatay telefonda üst çubuk alçalır; dikey telefonda bugünkü 76.
          expect(appBar.height, size.height < 500 ? 56 : 76, reason: '$size');
          for (final pill in tester.widgetList<ShellStatPill>(find.byType(ShellStatPill))) {
            final rect = tester.getRect(find.byWidget(pill));
            expect(rect.top, greaterThanOrEqualTo(appBar.top), reason: '$size x$scale');
            expect(rect.bottom, lessThanOrEqualTo(appBar.bottom), reason: '$size x$scale');
          }
        }
      }
    });

    testWidgets('rozet çok alçak bir kutuda bile orantılı küçülür', (tester) async {
      await _pumpAt(
        tester,
        _smallPhoneLandscape,
        Material(
          child: Center(
            child: SizedBox(
              height: 24,
              child: ShellStatPill(
                label: 'PUAN',
                value: 123456789,
                background: AppColors.primaryFixed,
                foreground: AppColors.onPrimaryFixed,
                onTap: () {},
              ),
            ),
          ),
        ),
        textScale: 2,
      );
      _expectNoLayoutError(tester, 'alçak rozet');
      expect(tester.getSize(find.byType(ShellStatPill)).height, lessThanOrEqualTo(24));
    });

    testWidgets('bekleyen seans bandı taşmaz', (tester) async {
      for (final size in _targetSizes) {
        for (final scale in [1.0, 2.0]) {
          await _pumpAt(
            tester,
            size,
            _shell(
              body: Column(
                children: [
                  ShellPendingBanner(count: 12, onTap: () {}),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
            textScale: scale,
          );
          _expectNoLayoutError(tester, '$size x$scale');
          expect(find.byType(ShellPendingBanner), findsOneWidget);
        }
      }
    });

    testWidgets('dikey telefonda alt çubuk, tablette ve yatay telefonda yan ray', (tester) async {
      for (final size in _targetSizes) {
        for (final scale in [1.0, 1.5]) {
          await _pumpAt(tester, size, _shell(body: const SizedBox.expand()), textScale: scale);
          _expectNoLayoutError(tester, '$size x$scale');
          final sideNav = Responsive.fromSize(size).useSideNavigation;
          expect(find.byType(NavigationRail), sideNav ? findsOneWidget : findsNothing, reason: '$size');
          expect(find.byType(NavigationBar), sideNav ? findsNothing : findsOneWidget, reason: '$size');
          // Dört sekmenin etiketi de görünür (ray gerekirse kendi içinde kayar).
          for (final d in _destinations) {
            expect(find.text(d.label), findsOneWidget, reason: '$size ${d.label}');
          }
        }
      }
    });

    testWidgets('raydaki sekmeye dokunmak sekmeyi seçer', (tester) async {
      var selected = 0;
      _setView(tester, _phoneLandscape);
      await tester.pumpWidget(
        _app(StatefulBuilder(
          builder: (context, setState) => _shell(
            body: const SizedBox.expand(),
            selectedIndex: selected,
            onSelect: (i) => setState(() => selected = i),
          ),
        )),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Raporlar'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
    });

    testWidgets('döndürme ve odak modu sekmenin durumunu korur', (tester) async {
      var showNavigation = true;
      late StateSetter rebuild;
      _setView(tester, _phonePortrait);
      await tester.pumpWidget(
        _app(StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _shell(body: const _Counter(), showNavigation: showNavigation);
          },
        )),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('sayac 0'));
      await tester.pump();
      expect(find.text('sayac 1'), findsOneWidget);

      // Alt çubuktan yan raya geçiş.
      _setView(tester, _phoneLandscape);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('sayac 1'), findsOneWidget);

      // Odak modu: gezinme gizlenir, gövde aynı kalır.
      rebuild(() => showNavigation = false);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('sayac 1'), findsOneWidget);

      rebuild(() => showNavigation = true);
      _setView(tester, _phonePortrait);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('sayac 1'), findsOneWidget);
    });

    testWidgets('SnackBar geniş ekranda form genişliğinde ortalı, dikey telefonda bugünkü gibi', (tester) async {
      // Ana uygulamadaki gibi MaterialApp.builder'da; kabuk içinden gösterilir.
      Future<Rect> showAt(Size size, {required bool scoped}) async {
        _setView(tester, size);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('tr'),
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: scoped ? (context, child) => SnackBarWidthScope(child: child!) : null,
          home: _shell(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('mesaj'), behavior: SnackBarBehavior.floating),
                  ),
                  child: const Text('göster'),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('göster'));
        await tester.pumpAndSettle();
        _expectNoLayoutError(tester, '$size snackbar');
        final rect = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
        // Sonraki boyut temiz bir ağaçla başlasın (SnackBar zamanlayıcısı da iptal olur).
        await tester.pumpWidget(const SizedBox());
        return rect;
      }

      for (final size in _targetSizes) {
        final rect = await showAt(size, scoped: true);
        if (Responsive.fromSize(size).isCompact) {
          // Dar pencerede (dikey telefon, küçük yatay telefon) bugünkü SnackBar.
          final baseline = await showAt(size, scoped: false);
          expect(rect, baseline, reason: '$size: dar ekranda SnackBar değişmemeli');
        } else {
          expect(rect.width, SnackBarWidthScope.wideWidth, reason: '$size');
          expect(rect.center.dx, closeTo(size.width / 2, 1), reason: '$size');
        }
      }
    });
  });

  group('Kum saati', () {
    testWidgets('hedef boyutlarda taşmaz', (tester) async {
      for (final size in _targetSizes) {
        final hourglass = (size.shortestSide * 0.5).clamp(120.0, 300.0);
        await _pumpAt(
          tester,
          size,
          Scaffold(
            body: Center(child: HourglassWidget(isRunning: false, size: hourglass)),
          ),
        );
        _expectNoLayoutError(tester, '$size');
        expect(tester.getSize(find.byType(HourglassWidget)), Size(hourglass, hourglass * 1.05));
      }
    });
  });

  group('Sayaç ekranı', () {
    // Tek test: TimerPersistence tekil ve kilidinin Future zinciri onu ilk
    // kullanan testin fake async bölgesine bağlı kalır (bkz. timer_screen_test).
    testWidgets('hedef boyutlarda taşmaz; yatayda kum saati solda', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const owner = 'responsive-owner';
      final categories = CourseCategory.initialCategories();

      Widget timer() => TimerScreen(
            key: UniqueKey(),
            categories: categories,
            sessionOwnerKey: owner,
            onOpenSettings: () {},
            onSessionCompleted: (_) async => null,
          );

      Future<void> unmount() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      Future<void> savePausedSession() async {
        final now = DateTime.now();
        final paused = ActiveTimerSession.start(
          clientUuid: 'paused-responsive',
          categoryId: categories.first.id,
          categoryName: categories.first.name,
          durationMinutes: 25,
          totalSeconds: 25 * 60,
          now: now.subtract(const Duration(minutes: 5)),
        ).pauseAt(now.subtract(const Duration(seconds: 10)));
        await TimerPersistence.instance.save(owner, paused);
      }

      for (final paused in [false, true]) {
        for (final inShell in [true, false]) {
          for (final scale in [1.0, 1.3]) {
            for (final size in _targetSizes) {
              final label = '$size shell=$inShell paused=$paused x$scale';
              if (paused) await savePausedSession();
              _setView(tester, size);
              await tester.pumpWidget(_app(inShell ? _shell(body: timer()) : timer(), textScale: scale));
              // Cihazdaki seans (varsa) geri yüklenir.
              await tester.pump();
              await tester.pumpAndSettle();
              _expectNoLayoutError(tester, label);
              final l10n = AppLocalizations.of(tester.element(find.byType(TimerScreen)))!;
              expect(find.text(l10n.timerResetBtn), paused ? findsOneWidget : findsNothing, reason: label);

              final hourglass = tester.getRect(find.byType(HourglassWidget));
              final time = tester.getRect(find.textContaining(':').first);
              final startButton = tester.getRect(find.byType(ElevatedButton));
              if (_isLandscape(size)) {
                // Kum saati solda, süre ve kontroller sağda.
                expect(hourglass.right, lessThanOrEqualTo(time.left), reason: label);
                expect(hourglass.right, lessThanOrEqualTo(startButton.left), reason: label);
              } else {
                expect(hourglass.bottom, lessThanOrEqualTo(time.top), reason: label);
              }
              // Kum saati taşmadan ekranda, abartılı büyümeden.
              expect(hourglass.width, lessThanOrEqualTo(300), reason: label);
              expect(hourglass.top, greaterThanOrEqualTo(0), reason: label);
              expect(hourglass.bottom, lessThanOrEqualTo(size.height), reason: label);
              // 320x568'de kabuksuz tam ekran düzen gerçekte yok (dikeyde sayaç
              // hep kabukta); orada ana düğmeye aşağıdaki gibi kaydırarak ulaşılır.
              final fullScreenSmallPortrait = size == _smallPhonePortrait && !inShell;
              if (!paused && scale == 1.0 && size != _smallPhoneLandscape && !fullScreenSmallPortrait) {
                // Ana düğme kaydırmadan görünür.
                expect(startButton.bottom, lessThanOrEqualTo(size.height), reason: label);
              }
              // Her durumda ana düğmeye (gerekirse sağ sütun kaydırılarak) ulaşılır.
              await tester.ensureVisible(find.byType(ElevatedButton));
              await tester.pumpAndSettle();
              final reachable = tester.getRect(find.byType(ElevatedButton));
              expect(reachable.bottom, lessThanOrEqualTo(size.height), reason: label);
              expect(reachable.top, greaterThanOrEqualTo(0), reason: label);
              if (size == _phonePortrait && inShell && scale == 1.0) {
                // Dikey telefonda bugünkü yerleşim: 220 genişlikte, ortada.
                expect(hourglass.width, 220, reason: label);
                expect(hourglass.center.dx, closeTo(size.width / 2, 0.5), reason: label);
              }
              await unmount();
            }
          }
        }
      }

      // Klavye açıkken (başka sekmede) gövde çok alçalsa da sayaç taşmaz.
      for (final size in const [Size(390, 120), Size(844, 60), Size(1180, 200)]) {
        _setView(tester, size);
        await tester.pumpWidget(_app(timer()));
        await tester.pump();
        await tester.pumpAndSettle();
        _expectNoLayoutError(tester, 'alçak gövde $size');
        await unmount();
      }
    });
  });

  group('Sayaç diyalogları', () {
    Widget opener(Widget Function() dialog) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDialog<void>(context: context, builder: (_) => dialog()),
                child: const Text('aç'),
              ),
            ),
          ),
        );

    testWidgets('tebrik diyaloğu taşmaz ve geniş ekranda dar kalır', (tester) async {
      // Sonuçsuz, en kalabalık başarı (puan, kum, seri, bonus dökümü) ve ret.
      final variants = <String, Widget Function()>{
        'sonuçsuz': () => const SessionCompletedDialog(minutes: 25),
        'başarı': () => SessionCompletedDialog(
              minutes: 50,
              result: Future.value(const SessionSubmitSuccess(
                minutes: 50,
                basePoints: 12,
                bonusPoints: 4,
                bonusPct: 30,
                totalPoints: 16,
                coinsEarned: 20,
                streak: 14,
              )),
            ),
        'ret': () => SessionCompletedDialog(
              minutes: 25,
              result: Future.value(const SessionSubmitRejected(SessionReason.overlap)),
            ),
      };
      for (final MapEntry(key: variant, value: dialog) in variants.entries) {
        for (final size in _targetSizes) {
          for (final scale in [1.0, 2.0]) {
            final label = '$variant $size x$scale';
            await _pumpAt(tester, size, opener(dialog), textScale: scale);
            await tester.tap(find.text('aç'));
            await tester.pumpAndSettle();
            _expectNoLayoutError(tester, label);
            final surface = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first;
            final rect = tester.getRect(surface);
            expect(rect.width, lessThanOrEqualTo(kTimerDialogConstraints.maxWidth), reason: label);
            expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
            // Kapatma düğmesine her boyutta ulaşılır.
            await tester.tap(find.byType(ElevatedButton));
            await tester.pumpAndSettle();
            expect(find.byType(SessionCompletedDialog), findsNothing, reason: label);
          }
        }
      }
    });

    testWidgets('3-2-1 geri sayımı taşmaz ve ekrana sığar', (tester) async {
      for (final size in _targetSizes) {
        for (final scale in [1.0, 2.0]) {
          final label = '$size x$scale';
          var completed = false;
          late BuildContext dialogContext;
          await _pumpAt(
            tester,
            size,
            opener(() => Builder(builder: (context) {
                  dialogContext = context;
                  return TimerCountdownDialog(onComplete: () {
                    completed = true;
                    Navigator.of(dialogContext).pop();
                  });
                })),
            textScale: scale,
          );
          await tester.tap(find.text('aç'));
          await tester.pump(const Duration(milliseconds: 400));
          _expectNoLayoutError(tester, label);
          final number = tester.getRect(find.text('3'));
          expect(number.top, greaterThanOrEqualTo(0), reason: label);
          expect(number.bottom, lessThanOrEqualTo(size.height), reason: label);
          // Geri sayım biter ve diyalog kapanır (bekleyen zamanlayıcı kalmaz).
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(completed, isTrue, reason: label);
          expect(find.byType(TimerCountdownDialog), findsNothing, reason: label);
        }
      }
    });
  });

  group('Giriş bileşenleri', () {
    testWidgets('hata kutusu ve yasal metin taşmaz', (tester) async {
      const longMessage = 'E-posta ya da şifre hatalı. Lütfen bilgilerini kontrol edip tekrar dene; '
          'sorun sürerse şifreni sıfırlayabilirsin.';
      for (final size in _targetSizes) {
        for (final scale in [1.0, 2.0]) {
          await _pumpAt(
            tester,
            size,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const AuthErrorBanner(message: longMessage),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return LegalConsentText(
                          prefix: l10n.authSocialConsentPrefix,
                          suffix: l10n.authSocialConsentSuffix,
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            textScale: scale,
          );
          _expectNoLayoutError(tester, '$size x$scale');
          expect(find.byType(AuthErrorBanner), findsOneWidget);
          expect(find.byType(LegalConsentText), findsOneWidget);
        }
      }
    });

    testWidgets('kategori adı diyaloğu taşmaz (klavye açıkken de) ve dar kalır', (tester) async {
      for (final size in _targetSizes) {
        final keyboards = _isLandscape(size) && size.height < 500 ? [0.0, 160.0] : [0.0];
        for (final keyboard in keyboards) {
          for (final scale in [1.0, 1.3]) {
            final label = '$size klavye=$keyboard x$scale';
            await _pumpAt(
              tester,
              size,
              Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => CategoryNameDialog.show(
                        context,
                        title: 'Yeni Kategori',
                        confirmLabel: 'Ekle',
                        hintText: 'Kategori adı',
                        initialName: 'Matematik',
                      ),
                      child: const Text('aç'),
                    ),
                  ),
                ),
              ),
              textScale: scale,
              keyboard: keyboard,
            );
            await tester.tap(find.text('aç'));
            await tester.pumpAndSettle();
            _expectNoLayoutError(tester, label);
            expect(find.byType(CategoryNameDialog), findsOneWidget, reason: label);
            // Geniş ekranda diyalog tam genişliğe yayılmaz.
            final surface = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first;
            expect(tester.getSize(surface).width, lessThanOrEqualTo(440), reason: label);
            await tester.tap(find.text(AppLocalizations.of(tester.element(find.byType(AlertDialog)))!.cancel));
            await tester.pumpAndSettle();
          }
        }
      }
    });
  });

  group('Açılış, giriş, kayıt ve onboarding ekranları', () {
    testWidgets('açılış ekranı ortalı ve taşmasız; logo göstergeyle çakışmaz', (tester) async {
      for (final size in _targetSizes) {
        for (final scale in [1.0, 2.0]) {
          final label = '$size x$scale';
          await _pumpAt(tester, size, const SplashView(), textScale: scale, settle: false);
          _expectNoLayoutError(tester, label);
          final title = tester.getRect(find.text('PomoSprint'));
          final spinner = tester.getRect(find.byType(CircularProgressIndicator));
          expect(title.center.dx, closeTo(size.width / 2, 1), reason: label);
          expect(title.bottom, lessThan(spinner.top), reason: label);
          expect(spinner.bottom, lessThanOrEqualTo(size.height), reason: label);
        }
      }
    });

    testWidgets('giriş ekranı taşmaz, formu ortalanmış form genişliğinde', (tester) async {
      for (final size in _targetSizes) {
        final keyboards = _isLandscape(size) && size.height < 500 ? [0.0, 160.0] : [0.0];
        for (final keyboard in keyboards) {
          await _pumpAt(tester, size, LoginScreen(onLoginSuccess: (_) {}), keyboard: keyboard);
          _expectNoLayoutError(tester, '$size klavye=$keyboard');
          final field = tester.getRect(find.byType(TextField).first);
          expect(field.width, lessThanOrEqualTo(480), reason: '$size');
          expect(field.center.dx, closeTo(size.width / 2, 1), reason: '$size');
        }
      }
    });

    testWidgets('kayıt ekranı taşmaz', (tester) async {
      for (final size in _targetSizes) {
        final keyboards = _isLandscape(size) && size.height < 500 ? [0.0, 160.0] : [0.0];
        for (final keyboard in keyboards) {
          await _pumpAt(tester, size, const RegisterScreen(), keyboard: keyboard);
          _expectNoLayoutError(tester, '$size klavye=$keyboard');
          expect(tester.getRect(find.byType(TextField).first).width, lessThanOrEqualTo(480), reason: '$size');
        }
      }
    });

    testWidgets('onboarding adımları kısa yükseklikte de taşmaz', (tester) async {
      for (final size in _targetSizes) {
        // Her boyutta ilk adımdan başlanır (yeni durum).
        await _pumpAt(tester, size, PostAuthOnboardingScreen(key: UniqueKey(), onCompleted: () {}));
        final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;
        _expectNoLayoutError(tester, '$size adım 1');
        final title = tester.getRect(find.text(l10n.onboardingWelcomeTitle));
        final picker = tester.getRect(find.byType(CupertinoPicker));
        if (size.height < 500) {
          // Yatay telefon: başlık solda, yıl seçici sağda ve sığıyor.
          expect(title.right, lessThanOrEqualTo(picker.left), reason: '$size');
          expect(picker.bottom, lessThanOrEqualTo(size.height), reason: '$size');
        } else {
          expect(title.bottom, lessThanOrEqualTo(picker.top), reason: '$size');
        }

        Future<void> next(String step) async {
          await tester.tap(find.text(l10n.continueBtn));
          await tester.pumpAndSettle();
          _expectNoLayoutError(tester, '$size $step');
        }

        // Küçük ekranda seçenekler kaydırılarak görünür olur.
        Future<void> choose(Finder option) async {
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          await tester.tap(option);
          await tester.pump();
        }

        // Yaş sorusu nötr: yıl seçilmeden ilerlenmez; tekerlek çevrilir.
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
        await tester.pumpAndSettle();
        await next('adım 2');
        await choose(find.text(l10n.onboardingSegmentYks));
        await next('adım 3');
        await choose(find.text('Matematik'));
        await next('adım 4 (görünürlük)');
        await choose(find.text(l10n.onboardingVisibilityNo));
        await next('adım 5 (kurallar)');
        expect(find.text(l10n.gameRulesTitle), findsOneWidget, reason: '$size');
        await next('adım 6 (hedef)');
        expect(find.text(l10n.onboardingFinishBtn), findsOneWidget, reason: '$size');
        // Seçenekler tablette form genişliğini aşmaz.
        expect(tester.getSize(find.text(l10n.onboardingGoal1h)).width, lessThanOrEqualTo(480), reason: '$size');
      }
    });
  });
}
