// Loads every library in the app graph so a broken import or a signature
// change in an unwired screen fails here instead of at runtime.
import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/main.dart';
import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_screen.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_folder_screen.dart';
import 'package:be_human_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:be_human_app/features/auth/presentation/screens/login_screen.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:be_human_app/features/no_internet/presentation/screens/no_internet_screen.dart';
import 'package:be_human_app/features/proposals/presentation/screens/proposals_list_screen.dart';
import 'package:be_human_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/home/presentation/screens/home_screen.dart';
import 'package:be_human_app/core/utils/connectivity.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';
import 'package:be_human_app/features/about/data/website_scraper.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';

void main() {
  test('every library compiles and its widgets are constructible', () {
    expect(const BeHumanApp(), isNotNull);
    expect(const AdminDashboardScreen(), isNotNull);
    expect(const ArchiveScreen(), isNotNull);
    expect(
      const ArchiveFolderScreen(
        folder: ArchiveFolder(id: ArchiveFolder.proposalsId, name: 'p', isSystem: true),
      ),
      isNotNull,
    );
    expect(const SettingsScreen(), isNotNull);
    expect(const LoginScreen(), isNotNull);
    expect(const SplashScreen(), isNotNull);
    expect(const NoInternetScreen(), isNotNull);
    expect(const ProposalsListScreen(), isNotNull);
    expect(const FinanceScreen(), isNotNull);
    expect(const HomeScreen(), isNotNull);
    expect(routerProvider, isNotNull);
    expect(hasNetworkConnection, isNotNull);
    expect(WebsiteScraper(), isNotNull);
    expect(fileStorageServiceProvider, isNotNull);
    expect(const PdfViewerWidget(storagePath: 'p1.pdf'), isNotNull);
    expect(usersProvider, isNotNull);
    // Money is always two decimals with separators; the same figure used to
    // print three different ways across the app.
    expect(Formatters.amount(1234.5), '1,234.50\$');
    expect(Formatters.amount(null), '—');
    expect(Formatters.signedAmount(840.5, isIncome: false), '−840.50\$');
    // Stored timestamps must never reach a user as-is.
    expect(Formatters.date('2026-08-10T09:00:00.000'), '2026-08-10');
  });

  test('both teams may record a financial movement', () {
    // Money is received in the Netherlands and spent in Gaza; a ledger only
    // one end can write to is always out of date.
    for (final team in UserTeam.values) {
      for (final role in UserRole.values) {
        final user = AppUser(
          uid: 'u', email: 'u@behuman.org', name: 'U', role: role, team: team,
        );
        expect(user.hasFinancialAccess, isTrue,
            reason: '${role.name} on ${team.name} cannot record a movement');
      }
    }
  });
}
