import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/pv_colors.dart';

/// Five-tab bottom navigation shell for the PROVENANCE VERIFIED customer app.
///
/// Tab order:
///   0 Home   — /home
///   1 Verify — /verify
///   2 My PV  — /my-pv
///   3 Submit — /submit
///   4 Activity — /activity
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to its initial location (branch root).
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PvColors.background,
      body: navigationShell,
      bottomNavigationBar: _PvNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

class _PvNavigationBar extends StatelessWidget {
  const _PvNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // Apply a branded NavigationBarTheme so selected icons use Protocol Cyan
    // and the bar sits on the carbon background regardless of system theme.
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: PvColors.surface,
          indicatorColor: PvColors.cyan.withOpacity(0.18),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: PvColors.cyan, size: 24);
            }
            return const IconThemeData(color: PvColors.muted, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: PvColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: PvColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            );
          }),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 200),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Verify',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'My PV',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Submit',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Activity',
          ),
        ],
      ),
    );
  }
}
