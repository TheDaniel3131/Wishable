import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final ReceiptScanResult? prefilled;
  const AddTransactionScreen({super.key, this.prefilled});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String   _type        = 'expense';
  String   _category    = 'food';
  DateTime _date        = DateTime.now();
  bool     _isSubmitting= false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilled != null) {
      _amountCtrl.text = widget.prefilled!.total.toStringAsFixed(2);
      _descCtrl.text   = widget.prefilled!.merchant;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    final desc   = _descCtrl.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in amount and description'),
        backgroundColor: AppColors.red,
      ));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final tx = Transaction(
        id:          const Uuid().v4(),
        type:        _type,
        amount:      amount,
        description: desc,
        category:    _category,
        date:        _date,
        notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isScanned:   widget.prefilled != null,
      );
      await ref.read(transactionsProvider.notifier).add(tx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaction added!'),
          backgroundColor: AppColors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                ),
              ),
              const Gap(12),
              Text('New Transaction', style: Theme.of(context).textTheme.headlineMedium),
            ]),
          ),
          const Gap(24),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Type toggle
                _TypeToggle(current: _type, onChanged: (t) => setState(() => _type = t))
                  .animate().fadeIn(duration: 300.ms),
                const Gap(20),

                // Amount input
                _AmountInput(controller: _amountCtrl, type: _type)
                  .animate().fadeIn(delay: 50.ms),
                const Gap(16),

                // Description
                _label('Description'),
                TextField(
                  controller: _descCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'What was this for?'),
                ).animate().fadeIn(delay: 100.ms),
                const Gap(16),

                // Category
                _label('Category'),
                _CategoryGrid(selected: _category, onSelect: (c) => setState(() => _category = c))
                  .animate().fadeIn(delay: 150.ms),
                const Gap(16),

                // Date
                _label('Date'),
                _DatePicker(date: _date, onChanged: (d) => setState(() => _date = d))
                  .animate().fadeIn(delay: 200.ms),
                const Gap(16),

                // Notes
                _label('Notes (optional)'),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Add a note...'),
                ).animate().fadeIn(delay: 250.ms),
                const Gap(20),

                // Scan shortcuts
                Row(children: [
                  Expanded(child: _ScanBtn(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan QR',
                    color: AppColors.green,
                    onTap: () => context.push('/scan/qr'),
                  )),
                  const Gap(10),
                  Expanded(child: _ScanBtn(
                    icon: Icons.receipt_long_rounded,
                    label: 'Scan Receipt',
                    color: AppColors.amber,
                    onTap: () => context.push('/scan/receipt', extra: {
                      'onResult': (ReceiptScanResult result) {
                        setState(() {
                          _amountCtrl.text = result.total.toStringAsFixed(2);
                          _descCtrl.text   = result.merchant;
                        });
                      }
                    }),
                  )),
                ]).animate().fadeIn(delay: 300.ms),
                const Gap(20),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Transaction'),
                  ),
                ).animate().fadeIn(delay: 350.ms),
                const Gap(40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500, letterSpacing: .5)),
  );
}

// ── Type Toggle ───────────────────────────────────────────────────────────────
class _TypeToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _TypeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(children: ['expense', 'income'].map((t) {
        final active = t == current;
        final color  = t == 'expense' ? AppColors.red : AppColors.green;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: active ? Border.all(color: color.withOpacity(.4)) : null,
            ),
            child: Center(child: Text(
              t[0].toUpperCase() + t.substring(1),
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: active ? color : AppColors.textSecondary,
              ),
            )),
          ),
        ));
      }).toList()),
    );
  }
}

// ── Amount Input ──────────────────────────────────────────────────────────────
class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String type;
  const _AmountInput({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMid),
      ),
      child: Column(children: [
        Text('RM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.textSecondary)),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -2),
          decoration: const InputDecoration(
            hintText: '0.00',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
      ]),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────
class _CategoryGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .9,
      children: kCategories.map((cat) {
        final active = cat.id == selected;
        return GestureDetector(
          onTap: () => onSelect(cat.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: active ? cat.color.withOpacity(.12) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? cat.color.withOpacity(.5) : AppColors.border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 22)),
              const Gap(5),
              Text(cat.label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date Picker ───────────────────────────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DatePicker({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.violet, surface: AppColors.surfaceAlt),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
          const Gap(10),
          Text(DateFormat('d MMMM yyyy').format(date), style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        ]),
      ),
    );
  }
}

// ── Scan Button ───────────────────────────────────────────────────────────────
class _ScanBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ScanBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderMid),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const Gap(8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ]),
      ),
    );
  }
}
