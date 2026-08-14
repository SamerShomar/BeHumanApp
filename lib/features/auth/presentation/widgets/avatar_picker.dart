import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/presentation/widgets/user_avatar.dart';

/// Profile picture with an edit affordance.
///
/// Uploads to the same private bucket as the documents and stores only the
/// object path on the user's Firestore document.
class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({super.key, required this.user, this.radius = 44});

  final AppUser user;
  final double radius;

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _isBusy = false;

  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final updatedMessage = AppLocalizations.of(context, 'photo_updated');

    // The picker resizes and recompresses before returning, which keeps
    // avatars small without needing an image library here.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isBusy = true);
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final path = await ref.read(fileStorageServiceProvider).uploadAvatar(
            uid: widget.user.uid,
            bytes: bytes,
            contentType: picked.mimeType ?? 'image/jpeg',
          );

      await ref.read(profileServiceProvider).updatePhotoPath(widget.user.uid, path);

      // The stored path is unchanged across uploads, so the cached signed URL
      // would keep showing the previous picture without this.
      ref.invalidate(avatarUrlProvider(path));

      messenger.showSnackBar(SnackBar(content: Text(updatedMessage)));
    } on FileStorageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localized(context))));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final removedMessage = AppLocalizations.of(context, 'photo_removed');
    final path = widget.user.photoPath;

    setState(() => _isBusy = true);
    try {
      await ref.read(profileServiceProvider).updatePhotoPath(widget.user.uid, null);
      if (path != null) {
        try {
          await ref.read(fileStorageServiceProvider).deleteFile(path);
        } on FileStorageException {
          // The document no longer points at it; a leftover object in the
          // bucket is not worth failing the action for.
        }
        ref.invalidate(avatarUrlProvider(path));
      }
      messenger.showSnackBar(SnackBar(content: Text(removedMessage)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(context, 'choose_from_gallery')),
              onTap: () {
                Navigator.of(sheet).pop();
                _pick(ImageSource.gallery);
              },
            ),
            // Not offered on desktop, where there is usually no camera bound
            // to the platform picker.
            if (Platform.isAndroid || Platform.isIOS)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(AppLocalizations.of(context, 'take_photo')),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _pick(ImageSource.camera);
                },
              ),
            if (widget.user.photoPath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(
                  AppLocalizations.of(context, 'remove_photo'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _remove();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: AppLocalizations.of(context, 'change_photo'),
      child: GestureDetector(
        onTap: _isBusy ? null : _showOptions,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            UserAvatar(
              photoPath: widget.user.photoPath,
              name: widget.user.name,
              radius: widget.radius,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: _isBusy
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                      ),
                    )
                  : Icon(Icons.camera_alt, size: 14, color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
