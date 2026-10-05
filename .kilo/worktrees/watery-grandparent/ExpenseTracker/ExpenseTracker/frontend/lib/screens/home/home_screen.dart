import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/transaction.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(balanceSummaryProvider);
    final recent  = ref.watch(recentTransactionsProvider);
    final fmt     = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Good morning', style: Theme.of(context).textTheme.bodyMedium),
                      Text('My Wallet', style: Theme.of(context).textTheme.headlineMedium),
                    ]),
                    Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.violet, AppColors.violetLight]),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hero Balance Card ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _BalanceCard(summary: summary, fmt: fmt)
                .animate().fadeIn(duration: 400.ms).slideY(begin: .08, end: 0),
            ),
          ),

          // ── Quick Actions ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickActions()
                .animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),
          ),

          // ── Recent Transactions ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent', style: Theme.of(context).textTheme.headlineSmall),
                  TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('See all', style: TextStyle(color: AppColors.violet, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionTile(tx: recent[i])
                    .animate().fadeIn(delay: Duration(milliseconds: 150 + i * 60)).slideX(begin: .05, end: 0),
                ),
                childCount: recent.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Balance Hero Card ─────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final ({double income, double expense, double balance}) summary;
  final NumberFormat fmt;
  const _BalanceCard({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A40C4), AppColors.violet, AppColors.violetLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [const BoxShadow(color: Color(0x407C6EF7), blurRadius: 32, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL BALANCE', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w500)),
          const Gap(8),
          Text(fmt.format(summary.balance), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
          const Gap(4),
          Text('Updated just now', style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12)),
          const Gap(20),
          Row(children: [
            _BalancePill(label: '▲', value: fmt.format(summary.income),  color: Colors.white.withOpacity(.2)),
            const Gap(10),
            _BalancePill(label: '▼', value: fmt.format(summary.expense), color: Colors.white.withOpacity(.2)),
          ]),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalancePill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        const Gap(6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QAction(icon: Icons.add_circle_outline_rounded, label: 'Add',      color: AppColors.violet,  onTap: () => context.push('/add')),
      _QAction(icon: Icons.qr_code_scanner_rounded,   label: 'Scan QR',  color: AppColors.green,   onTap: () => context.push('/scan/qr')),
      _QAction(icon: Icons.receipt_long_rounded,      label: 'Receipt',  color: AppColors.amber,   onTap: () => context.push('/scan/receipt', extra: {})),
      _QAction(icon: Icons.bar_chart_rounded,         label: 'Analytics',color: AppColors.red,     onTap: () => context.go('/analytics')),
    ];
    return Row(
      children: actions.map((a) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _QuickActionBtn(action: a),
      ))).toList(),
    );
  }
}

class _QAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickActionBtn extends StatelessWidget {
  final _QAction action;
  const _QuickActionBtn({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: action.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action.icon, color: action.color, size: 20),
          ),
          const Gap(8),
          Text(action.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
