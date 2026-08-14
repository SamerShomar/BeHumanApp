import 'package:flutter/material.dart';

/// The app's primary "add" button.
///
/// An extended FAB sizes itself to its label, and the same label is much
/// longer in Dutch and Arabic than in English — "Add financial movement"
/// already overflowed the bar by a few pixels. Capping the label and letting
/// it ellipsize means no language can break the layout.
///
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
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
