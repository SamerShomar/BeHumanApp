import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/services/file_storage_service.dart';

/// Signed URL for an avatar stored in the private bucket.
///
/// Keyed by object path and kept alive briefly so revisiting a screen does not
/// mint a fresh link on every rebuild. Signed links expire, so this must not be
/// cached longer than they last.
final avatarUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, path) async {
  if (path == null || path.isEmpty) return null;

  final link = ref.keepAlive();
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  timer = Timer(const Duration(minutes: 3), link.close);

  try {
    return await ref.read(fileStorageServiceProvider).createSignedUrl(path);
  } on FileStorageException {
    // A missing or unreadable avatar should fall back to initials, not break
    // the screen it sits on.
    return null;
  }
});

/// Circular profile picture, falling back to the user's initials.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.photoPath,
    required this.name,
    this.radius = 44,
  });

  final String? photoPath;
  final String name;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref.watch(avatarUrlProvider(photoPath));

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withOpacity(0.15),
      foregroundImage: url.valueOrNull != null
          ? NetworkImage(url.valueOrNull!)
          : null,
      child: url.isLoading && photoPath != null
          ? SizedBox(
              width: radius * 0.5,
              height: radius * 0.5,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _initials,
              style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
    );
  }
}
