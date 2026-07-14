import 'package:flutter/material.dart';
import 'pos_view.dart';

/// Desktop-specific layout for POS.
/// For now, this simply wraps or directs to the main POS view,
/// which handles its own responsiveness, but can be expanded for
/// a unique dual-pane layout in the future.
class POSDesktopView extends StatelessWidget {
  const POSDesktopView({super.key});

  @override
  Widget build(BuildContext context) {
    // Return the standard POS view which should already be responsive,
    // or provide a customized desktop layout here if needed.
    return const POSView();
  }
}
