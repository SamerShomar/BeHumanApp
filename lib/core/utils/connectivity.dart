import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns whether the device currently reports any network connection.
///
/// `checkConnectivity()` returns a *list* since connectivity_plus 6.x (a device
/// can be on Wi-Fi and mobile at once). Comparing that list directly against
/// `ConnectivityResult.none` is always true, which silently reported "online"
/// even in airplane mode.
Future<bool> hasNetworkConnection() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((result) => result != ConnectivityResult.none);
}
