import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/projects/presentation/providers/project_providers.dart';

/// Signing out of one account and into another made every screen report "the
/// caller does not have permission to execute the specified operation".
///
/// The data providers stopped being `autoDispose` so that switching tabs would
/// not re-download everything. The cost, unnoticed at the time, was that a
/// Firestore listener opened during one session outlived that session: on
/// sign-out Firestore failed it with permission-denied, the provider latched
/// into an error, and nothing ever rebuilt it — so the error greeted the next
/// person to sign in.
///
/// Each query watches the signed-in uid now, which ties it to a session.
void main() {
  /// Firebase is not initialised in a test, so touching Firestore throws.
  /// That makes this a real assertion: these providers resolve without going
  /// near it, which is only possible if the signed-out guard runs first.
  ProviderContainer signedOut() {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('no query is opened while signed out', () async {
    final container = signedOut();
    // Let the auth stream deliver its null before the queries are read.
    await container.read(authStateProvider.future);

    expect(await container.read(proposalsProvider.future), isEmpty);
    expect(await container.read(transactionsProvider.future), isEmpty);
    expect(await container.read(usersProvider.future), isEmpty);
    expect(await container.read(projectsProvider.future), isEmpty);
    expect(await container.read(siteContentProvider.future), isEmpty);
    expect(await container.read(notificationFeedProvider.future), isEmpty);
    expect(await container.read(archiveFoldersProvider.future), isEmpty);
  });

  test('a signed-out session shows no unread notifications', () async {
    final container = signedOut();
    await container.read(authStateProvider.future);

    expect(container.read(unreadNotificationCountProvider), 0);
    expect(container.read(myNotificationsProvider), isEmpty);
  });
}
