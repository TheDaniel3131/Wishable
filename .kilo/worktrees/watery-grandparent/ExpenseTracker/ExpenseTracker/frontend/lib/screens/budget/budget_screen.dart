import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/transaction.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBudgets = ref.watch(budgetsProvider);
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budgets', style: Theme.of(context).textTheme.displaySmall),
                GestureDetector(
                  onTap: () => _showAddBudget(context, ref),
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
            child: asyncBudgets.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.red))),
              data:    (budgets) => budgets.isEmpty
                ? _EmptyBudgets(onAdd: () => _showAddBudget(context, ref))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: budgets.length,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (ctx, i) => _BudgetCard(budget: budgets[i], fmt: fmt)
                      .animate().fadeIn(delay: Duration(milliseconds: i * 60)).slideY(begin: .04),
                  ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddBudget(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _AddBudgetSheet(ref: ref),
    );
  }
}

// ── Budget Card ───────────────────────────────────────────────────────────────
class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final NumberFormat fmt;
  const _BudgetCard({required this.budget, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cat      = categoryById(budget.category);
    final pct      = (budget.spent / budget.limitAmount).clamp(0.0, 1.0);
    final isOver   = budget.spent > budget.limitAmount;
    final barColor = pct > .8 ? AppColors.red : pct > .6 ? AppColors.amber : AppColors.green;
    final left     = budget.limitAmount - budget.spent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 26)),
              const Gap(12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(budget.period, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(budget.limitAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Text('limit', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ],
        ),
        const Gap(16),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 10,
          ),
        ),
        const Gap(8),

        // Spent / left
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Spent ${fmt.format(budget.spent)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(
              isOver ? 'Over by ${fmt.format(-left)}' : '${fmt.format(left)} left',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: barColor),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Add Budget Sheet ──────────────────────────────────────────────────────────
class _AddBudgetSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddBudgetSheet({required this.ref});

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  final _limitCtrl = TextEditingController();
  String _category = 'food';
  String _period   = 'monthly';
  bool   _saving   = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)))),
          const Gap(20),
          const Text('New Budget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Gap(20),

          // Category picker
          const Text('CATEGORY', style: TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: .5, fontWeight: FontWeight.w500)),
          const Gap(8),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: kCategories.map((cat) {
                final sel = cat.id == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? cat.color.withOpacity(.15) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? cat.color.withOpacity(.5) : AppColors.border),
                    ),
                    child: Row(children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const Gap(6),
                      Text(cat.label, style: TextStyle(fontSize: 13, color: sel ? cat.color : AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(16),

          // Monthly limit
          const Text('MONTHLY LIMIT (RM)', style: TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: .5, fontWeight: FontWeight.w500)),
          const Gap(8),
          TextField(
            controller: _limitCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(prefixText: 'RM  ', prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ),
          const Gap(24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Budget'),
            ),
          ),
          const Gap(8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final limit = double.tryParse(_limitCtrl.text);
    if (limit == null || limit <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.ref.read(budgetsProvider.notifier).add(Budget(
        id: const Uuid().v4(), category: _category, limitAmount: limit, period: _period,
      ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyBudgets extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBudgets({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.account_balance_wallet_rounded, size: 36, color: AppColors.textMuted),
        ),
        const Gap(16),
        const Text('No budgets set', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        const Gap(6),
        const Text('Track your spending limits', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Gap(24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Budget'),
        ),
      ]),
    );
  }
}
