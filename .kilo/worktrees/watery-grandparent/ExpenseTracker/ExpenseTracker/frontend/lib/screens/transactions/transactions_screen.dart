// ── transactions_screen.dart ──────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTxs = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('History', style: Theme.of(context).textTheme.displaySmall),
                GestureDetector(
                  onTap: () => context.push('/add'),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncTxs.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.red))),
              data:    (txs) => txs.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (ctx, i) => TransactionTile(tx: txs[i])
                      .animate().fadeIn(delay: Duration(milliseconds: i * 30)),
                  ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.textMuted),
        ),
        const Gap(16),
        const Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        const Gap(6),
        const Text('Add your first one above', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}
