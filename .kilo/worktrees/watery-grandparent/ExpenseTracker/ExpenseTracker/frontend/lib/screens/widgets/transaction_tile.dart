import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';

class TransactionTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback? onTap;
  const TransactionTile({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat    = categoryById(tx.category);
    final isExp  = tx.type == 'expense';
    final fmt    = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final dateFmt= DateFormat('d MMM').format(tx.date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Category icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(children: [
                Text(cat.label, style: Theme.of(context).textTheme.bodySmall),
                const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(dateFmt, style: Theme.of(context).textTheme.bodySmall),
                if (tx.isScanned) ...[
                  const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const Icon(Icons.document_scanner_rounded, size: 10, color: AppColors.violet),
                ],
              ]),
            ],
          )),
          // Amount
          Text(
            '${isExp ? '-' : '+'}${fmt.format(tx.amount)}',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: isExp ? AppColors.red : AppColors.green,
            ),
          ),
        ]),
      ),
    );
  }
}
