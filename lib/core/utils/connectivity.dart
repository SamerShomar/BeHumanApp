import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns whether the device currently reports any network connection.
///
/// `checkConnectivity()` returns a *list* since connectivity_plus 6.x (a device
/// can be on Wi-Fi and mobile at once). Comparing that list directly against
/// `ConnectivityResult.none` is always true, which silently reported "online"
/// even in airplane mode.
Future<bool> hasNetworkConnection() async {
  final results = await Connectivity().checkConnectivity();
  return _isOnline(results);
}

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// Whether the device is on a network, updated as that changes.
///
/// Starts optimistic. Being briefly wrong about having a connection costs a
/// request that fails and retries; being briefly wrong about *not* having one
/// puts a warning on screen every time the app opens, which teaches people to
/// ignore it.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  late final StreamController<bool> controller;
  StreamSubscription<List<ConnectivityResult>>? subscription;

  controller = StreamController<bool>(
    onListen: () async {
      // The stream only reports *changes*, so the current state has to be
      // asked for separately or a device that is offline before the app opens
      // is never reported as such.
      try {
        controller.add(await hasNetworkConnection());
      } catch (_) {
        controller.add(true);
      }
      subscription = connectivity.onConnectivityChanged
          .listen((results) => controller.add(_isOnline(results)));
    },
    onCancel: () async => subscription?.cancel(),
  );

  ref.onDispose(controller.close);
  return controller.stream;
});
