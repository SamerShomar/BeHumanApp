import 'package:flutter/material.dart';

/// The app's primary "add" button.
///
/// An extended FAB sizes itself to its label, and the same label is much
/// longer in Dutch and Arabic than in English — "Add financial movement"
/// already overflowed the bar by a few pixels. Capping the label and letting
/// it ellipsize means no language can break the layout.
///
/// How much room the floating navigation bar needs beneath a screen's content.
///
/// Published by the shell rather than worked out where it is used. A screen
/// inside the shell sits in the shell Scaffold's body, and that Scaffold
/// consumes the bottom inset — both `padding` and `viewPadding` read as zero
/// from a widget in the body, so the number simply is not available there.
/// Guessing it is what put the add button behind the bar.
class NavBarInset extends InheritedWidget {
  const NavBarInset({required this.height, required super.child, super.key});

  /// The bar's full height, system inset included.
  final double height;

  /// The bar's height alone, excluding the system inset beneath it. It is
  /// built from padding and text rather than given a fixed height, so this is
  /// measured and held in place by a test.
  static const double barHeight = 73;

  /// Falls back to the bar alone for anything rendered outside the shell — a
  /// full-screen route has no bar under it, so nothing is lost by being
  /// slightly generous there.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarInset>()?.height ??
      barHeight;

  @override
  bool updateShouldNotify(NavBarInset oldWidget) => height != oldWidget.height;
}

/// It also carries the bottom inset for the floating navigation bar the shell
/// extends content behind, so no screen has to remember that number.
class AppFab extends StatelessWidget {
  const AppFab({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Taken from the shell, which is the only place the real number exists.
    // A flat 72 was used here before, which is roughly the bar's own height
    // and ignores the system inset under it — so on a phone with a gesture bar
    // the button sat nineteen points behind it and could not be tapped.
    return Padding(
      padding: EdgeInsets.only(bottom: NavBarInset.of(context)),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 168),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
