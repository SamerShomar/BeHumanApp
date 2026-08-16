@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_folder_screen.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_screen.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/presentation/screens/login_screen.dart';
import 'package:be_human_app/features/finance/domain/statement_filter.dart';
import 'package:be_human_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:be_human_app/features/finance/presentation/widgets/statement_filter_sheet.dart';
import 'package:be_human_app/features/home/presentation/screens/home_screen.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:be_human_app/features/projects/domain/project.dart';
import 'package:be_human_app/features/projects/presentation/providers/project_providers.dart';
import 'package:be_human_app/features/proposals/presentation/screens/proposals_list_screen.dart';
import 'package:be_human_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';

/// Renders every screen at phone size, in both themes, so a design change can
/// be reviewed as images rather than read as code. Regenerate on Linux with:
///
///   flutter test --update-goldens test/preview_all_screens_test.dart
void main() {
  setUpAll(() async {
    Future<void> load(String family, List<String> paths) async {
      final loader = FontLoader(family);
      var found = false;
      for (final path in paths) {
        final file = File(path);
        if (file.existsSync()) {
          loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
          found = true;
        }
      }
      if (found) await loader.load();
    }

    await load('Roboto', [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]);
    await load('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
          '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  void mockConnectivity({required bool online}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>[online ? 'wifi' : 'none'],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (arguments, sink) {}),
    );
  }

  const admin = AppUser(
    uid: 'admin',
    email: 'samer@behuman.org',
    name: 'Samer Shomar',
    role: UserRole.admin,
    team: UserTeam.netherlands,
  );

  const gaza = AppUser(
    uid: 'gaza-1',
    email: 'mahmoud@behuman.org',
    name: 'Mahmoud Abu Eisha',
    role: UserRole.member,
    team: UserTeam.gaza,
  );

  final proposals = [
    {
      'id': 'p1',
      'title': 'Sheikh Radwan water project.pdf',
      'status': 'pending',
      'date': '2026-08-12T09:00:00.000',
      'amount': 12500.0,
      'submittedBy': 'gaza-1',
      'submittedByName': 'Mahmoud Abu Eisha',
    },
    {
      'id': 'p2',
      'title': 'Winter blankets distribution.pdf',
      'status': 'accepted',
      'date': '2026-08-04T09:00:00.000',
      'amount': 4200.0,
      'submittedBy': 'gaza-2',
      'submittedByName': 'Rana Saleh',
    },
    {
      'id': 'p3',
      'title': 'School rehabilitation phase two.pdf',
      'status': 'rejected',
      'date': '2026-07-28T09:00:00.000',
      'amount': 31000.0,
      'submittedBy': 'gaza-1',
      'submittedByName': 'Mahmoud Abu Eisha',
    },
  ];

  final transactions = [
    {'id': 't1', 'type': 'income', 'amount': 6000.0, 'currency': 'EUR', 'ilsPerEur': 4.1, 'description': 'Donation — Rotterdam campaign', 'date': '2026-08-10T09:00:00.000', 'filePath': 'invoices/t1.pdf', 'fileName': 'transfer.pdf'},
    {'id': 't2', 'type': 'expense', 'amount': 8400.0, 'currency': 'ILS', 'ilsPerEur': 4.1, 'description': 'Water tanks purchase', 'date': '2026-08-08T09:00:00.000', 'filePath': 'invoices/t2.pdf', 'fileName': 'receipt.pdf'},
    // Written before a rate was asked for: shows how an old row now reads.
    {'id': 't3', 'type': 'expense', 'amount': 1250.5, 'description': 'Transport', 'date': '2026-08-06T09:00:00.000'},
  ];

  final notifications = [
    AppNotification(
      id: 'n1',
      type: NotificationType.proposal,
      titleKey: 'notification_proposal_title',
      bodyKey: 'notification_proposal_body',
      params: const {'name': 'Mahmoud Abu Eisha', 'title': 'Sheikh Radwan water project.pdf'},
      audience: NotificationAudience.reviewers,
      actorUid: 'gaza-1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
      route: '/proposals',
    ),
    AppNotification(
      id: 'n2',
      type: NotificationType.transaction,
      titleKey: 'notification_income_title',
      bodyKey: 'notification_transaction_body',
      params: const {'name': 'Foekje de Vries', 'amount': '25000.00'},
      audience: NotificationAudience.all,
      actorUid: 'nl-1',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      route: '/financial',
      readBy: const ['admin'],
    ),
    AppNotification(
      id: 'n3',
      type: NotificationType.transaction,
      titleKey: 'notification_expense_title',
      bodyKey: 'notification_transaction_body',
      params: const {'name': 'Foekje de Vries', 'amount': '840.50'},
      audience: NotificationAudience.all,
      actorUid: 'nl-1',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      route: '/financial',
      readBy: const ['admin'],
    ),
  ];

  final projects = [
    Project(
      id: 'j1',
      title: 'Sheikh Radwan water network',
      description: 'Repairing the main line and installing six storage tanks so '
          'households in the north have drinking water through the winter.',
      date: DateTime(2026, 8, 9),
      beneficiaries: 2400,
      location: 'Gaza — Sheikh Radwan',
    ),
    Project(
      id: 'j2',
      title: 'Winter blankets distribution',
      description: 'Thermal blankets and mattresses handed out to displaced '
          'families across three shelters.',
      date: DateTime(2026, 7, 22),
      beneficiaries: 860,
      location: 'Rafah',
    ),
    Project(
      id: 'j3',
      title: 'Psychosocial support for children',
      description: 'Weekly sessions run with local counsellors.',
      date: DateTime(2026, 6, 30),
      beneficiaries: 310,
      location: 'Khan Younis',
    ),
  ];

  final folders = [
    const ArchiveFolder(id: 'f1', name: 'Contracts', isSystem: false),
    const ArchiveFolder(id: 'f2', name: 'Partner reports', isSystem: false),
  ];

  Widget wrap(
    Widget screen, {
    required bool dark,
    AppUser user = admin,
    String? shellLocation,
  }) {
    final content = shellLocation == null
        ? screen
        : MainShell(location: shellLocation, child: screen);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => content),
        // Stubs, not the screen again: the splash navigates on a timer, and
        // returning it here would restart that timer forever.
        for (final path in ['/home', '/proposals', '/financial', '/archive',
                            '/settings', '/notifications', '/dashboard', '/login'])
          GoRoute(path: path, builder: (_, __) => const SizedBox.shrink()),
      ],
    );

    return ProviderScope(
      overrides: [
        isSignedInProvider.overrideWithValue(false),
        currentUserStreamProvider.overrideWith((ref) => Stream.value(user)),
        proposalsProvider.overrideWith((ref) => Stream.value(proposals)),
        transactionsProvider.overrideWith((ref) => Stream.value(transactions)),
        usersProvider.overrideWith((ref) => Stream.value([admin, gaza])),
        notificationFeedProvider.overrideWith((ref) => Stream.value(notifications)),
        archiveFoldersProvider.overrideWith((ref) => Stream.value(folders)),
        archiveDocumentsProvider.overrideWith((ref, folderId) => Stream.value([
              {
                'id': 'd1',
                'folderId': folderId,
                'fileName': 'Distribution list March.pdf',
                'storagePath': 'archive/$folderId/d1.pdf',
                'uploadedByName': 'Samer Shomar',
                'date': '2026-08-10T09:00:00.000',
              },
              {
                'id': 'd2',
                'folderId': folderId,
                // A photographed receipt, which the archive used to refuse.
                'fileName': 'IMG_0431.jpg',
                'storagePath': 'archive/$folderId/d2.jpg',
                'uploadedByName': 'Mahmoud Abu Eisha',
                'date': '2026-08-02T09:00:00.000',
              },
            ])),
        projectsProvider.overrideWith((ref) => Stream.value(projects)),
        siteContentProvider.overrideWith((ref) => Stream.value(const {
              'mission': 'Be Human is a civil society organisation delivering '
                  'emergency relief, development programmes and psychosocial '
                  'support to affected communities.',
            })),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme(context) : AppTheme.lightTheme(context),
          routerConfig: router,
          builder: (context, child) =>
              AppBackground(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }

  void useDeviceViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  final cases = <String, ({Widget screen, String? shell, AppUser user})>{
    'splash': (screen: const SplashScreen(), shell: null, user: admin),
    'login': (screen: const LoginScreen(), shell: null, user: admin),
    'home': (screen: const HomeScreen(), shell: '/home', user: admin),
    'proposals': (screen: const ProposalsListScreen(), shell: '/proposals', user: gaza),
    'finance': (screen: const FinanceScreen(), shell: '/financial', user: admin),
    'archive': (screen: const ArchiveScreen(), shell: '/archive', user: admin),
    'notifications': (screen: const NotificationsScreen(), shell: '/notifications', user: admin),
    'settings': (screen: const SettingsScreen(), shell: '/settings', user: admin),
    'dashboard': (screen: const AdminDashboardScreen(), shell: '/dashboard', user: admin),
  };

  for (final entry in cases.entries) {
    for (final dark in [false, true]) {
      testWidgets('${entry.key} ${dark ? 'dark' : 'light'}', (tester) async {
        useDeviceViewport(tester);
        mockConnectivity(online: true);

        await tester.pumpWidget(wrap(
          entry.value.screen,
          dark: dark,
          user: entry.value.user,
          shellLocation: entry.value.shell,
        ));
        await tester.pump(const Duration(milliseconds: 400));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ui_${entry.key}_${dark ? 'dark' : 'light'}.png'),
        );

        // The splash navigates on a timer; let it fire so the test does not
        // end with one still pending.
        await tester.pump(const Duration(seconds: 3));
        // Golden images are rasterised with the fonts of the machine that made
        // them. These were generated on Linux, so they skip elsewhere rather
        // than failing on font differences that say nothing about the app.
      }, skip: !Platform.isLinux);
    }
  }

  // The filter panel, which is where a payment statement is now produced from.
  for (final dark in [false, true]) {
    testWidgets('statement filter ${dark ? 'dark' : 'light'}', (tester) async {
      useDeviceViewport(tester);
      mockConnectivity(online: true);

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: ElevatedButton(
                onPressed: () => StatementFilterSheet.show(
                  context,
                  StatementFilter(from: DateTime(2026, 6, 1), minAmount: 250),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        dark: dark,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ui_filter_${dark ? 'dark' : 'light'}.png'),
      );
    }, skip: !Platform.isLinux);
  }

  // A folder's contents, which open above the shell rather than inside it.
  // Rendered with no shell here for the same reason: pushed on the shell's
  // navigator, the floating bar sat on top of this screen's upload button.
  for (final dark in [false, true]) {
    testWidgets('archive folder ${dark ? 'dark' : 'light'}', (tester) async {
      useDeviceViewport(tester);
      mockConnectivity(online: true);

      await tester.pumpWidget(wrap(
        const ArchiveFolderScreen(
          folder: ArchiveFolder(id: 'f1', name: 'Field reports', isSystem: false),
        ),
        dark: dark,
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ui_archive_folder_${dark ? 'dark' : 'light'}.png'),
      );
    }, skip: !Platform.isLinux);
  }

  // The home screen's foot — the team and board list — sits well below the
  // first screenful, so the golden above never shows it. Scrolled to the
  // bottom here, because a section nobody's test ever looks at is a section
  // that quietly rots.
  for (final dark in [false, true]) {
    testWidgets('home bottom ${dark ? 'dark' : 'light'}', (tester) async {
      useDeviceViewport(tester);
      mockConnectivity(online: true);

      await tester.pumpWidget(wrap(const HomeScreen(), dark: dark, shellLocation: '/home'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ui_home_bottom_${dark ? 'dark' : 'light'}.png'),
      );
    }, skip: !Platform.isLinux);
  }
}
