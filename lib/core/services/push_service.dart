import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Registers this device so a notification can reach it while the app is
/// closed.
///
/// The device's FCM token is stored on the signed-in user's own profile
/// document. The Edge Function that actually sends the notification reads them
/// from there — the app never sees another user's token, and never holds the
/// credential that authorises sending.
///
/// Everything here is best-effort. A phone with notifications denied, an
/// emulator without Google Play services, or an iPhone with no APNs key
/// configured yet must not break sign-in, so every failure is swallowed and
/// the app continues with in-app notifications only.
class PushService {
  PushService(this._firestore, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _refreshSubscription;

  /// Asks for permission and records this device against [uid].
  ///
  /// Android 13 and every iOS version require the user to agree first; on
  /// older Android this returns granted without prompting.
  Future<void> register(String uid) async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _store(uid, token);

      // A token can be replaced by the OS at any time — after a reinstall, a
      // restore, or a long idle period. Without this the device silently
      // stops receiving anything.
      await _refreshSubscription?.cancel();
      _refreshSubscription =
          _messaging.onTokenRefresh.listen((next) => _store(uid, next));
    } catch (_) {
      // See the note on the class.
    }
  }

  /// Removes this device from [uid]'s profile on sign-out, so the next person
  /// to use the phone does not receive the previous user's notifications.
  Future<void> unregister(String uid) async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).set(
          {'fcmTokens': FieldValue.arrayRemove([token])},
          SetOptions(merge: true),
        );
      }
      await _messaging.deleteToken();
    } catch (_) {
      // See the note on the class.
    }
  }

  Future<void> _store(String uid, String token) async {
    // `arrayUnion` because one person may sign in on a phone and a tablet,
    // and both should ring.
    await _firestore.collection('users').doc(uid).set(
      {'fcmTokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(
    ref.watch(firebaseFirestoreProvider),
    FirebaseMessaging.instance,
  ),
);
