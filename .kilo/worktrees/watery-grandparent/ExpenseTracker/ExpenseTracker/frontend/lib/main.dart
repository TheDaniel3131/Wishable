import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/add_transaction/add_transaction_screen.dart';
import 'screens/scanner/qr_scanner_screen.dart';
import 'screens/scanner/receipt_scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarBrightness:      Brightness.dark,
    statusBarIconBrightness:  Brightness.light,
    systemNavigationBarColor: AppColors.background,
  ));
  runApp(const ProviderScope(child: MoneyTrackerApp()));
}

// ── Router ────────────────────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/',             builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/analytics',    builder: (_, __) => const AnalyticsScreen()),
        GoRoute(path: '/budget',       builder: (_, __) => const BudgetScreen()),
      ],
    ),
    GoRoute(path: '/add',     builder: (_, __) => const AddTransactionScreen()),
    GoRoute(path: '/scan/qr', builder: (_, __) => const QRScannerScreen()),
    GoRoute(
      path: '/scan/receipt',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ReceiptScannerScreen(onResult: extra?['onResult']);
      },
    ),
  ],
);

// ── Root App ──────────────────────────────────────────────────────────────────
class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:            'MoneyTracker',
      theme:            AppTheme.dark,
      routerConfig:     _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ── App Shell (bottom nav) ────────────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _locationIndex(String location) {
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/analytics'))   return 2;
    if (location.startsWith('/budget'))      return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _locationIndex(location);

    return Scaffold(
      body: child,
      floatingActionButton: _AddFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _AppBottomBar(currentIndex: idx),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _AppBottomBar extends StatelessWidget {
  final int currentIndex;
  const _AppBottomBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded,        label: 'Home',     index: 0, route: '/',             current: currentIndex),
              _NavItem(icon: Icons.receipt_long_rounded, label: 'History',  index: 1, route: '/transactions', current: currentIndex),
              const SizedBox(width: 72), // FAB gap
              _NavItem(icon: Icons.analytics_rounded,   label: 'Analytics',index: 2, route: '/analytics',    current: currentIndex),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Budget', index: 3, route: '/budget', current: currentIndex),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      index;
  final String   route;
  final int      current;
  const _NavItem({required this.icon, required this.label, required this.index, required this.route, required this.current});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(route),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active ? AppColors.violet.withOpacity(.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: active ? AppColors.violet : AppColors.textMuted, size: 22),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: active ? AppColors.violet : AppColors.textMuted,
            )),
          ],
        ),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
class _AddFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/add'),
      child: Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.violet, AppColors.violetLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x557C6EF7), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
