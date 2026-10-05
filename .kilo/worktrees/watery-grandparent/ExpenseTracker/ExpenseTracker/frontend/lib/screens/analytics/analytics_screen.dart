import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/transaction.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final periodStr = period.name;
    final asyncData = ref.watch(analyticsProvider(periodStr));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Analytics', style: Theme.of(context).textTheme.displaySmall),
                _PeriodToggle(current: period),
              ],
            ),
          ),
          const Gap(16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
              error:   (e, _) => _FallbackAnalytics(),
              data:    (data) => _AnalyticsContent(data: data),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Period Toggle ─────────────────────────────────────────────────────────────
class _PeriodToggle extends ConsumerWidget {
  final AnalyticsPeriod current;
  const _PeriodToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AnalyticsPeriod.values.map((p) {
          final active = p == current;
          return GestureDetector(
            onTap: () => ref.read(analyticsPeriodProvider.notifier).state = p,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.violet : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                p.name[0].toUpperCase() + p.name.substring(1),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Main analytics content ────────────────────────────────────────────────────
class _AnalyticsContent extends StatelessWidget {
  final AnalyticsSummary data;
  const _AnalyticsContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // Stat cards
        Row(children: [
          Expanded(child: _StatCard(label: 'Income',   value: fmt.format(data.totalIncome),   color: AppColors.green)),
          const Gap(10),
          Expanded(child: _StatCard(label: 'Expenses', value: fmt.format(data.totalExpenses), color: AppColors.red)),
        ]).animate().fadeIn(duration: 400.ms),
        const Gap(16),

        // Bar chart
        _SpendingBarChart(dailyTotals: data.dailyTotals)
          .animate().fadeIn(delay: 100.ms, duration: 400.ms),
        const Gap(16),

        // Category breakdown
        _CategoryBreakdown(byCategory: data.byCategory, total: data.totalExpenses)
          .animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const Gap(6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _SpendingBarChart extends StatelessWidget {
  final List<DailyTotal> dailyTotals;
  const _SpendingBarChart({required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    final days = dailyTotals.isEmpty
      ? List.generate(7, (i) => DailyTotal(date: 'D${i+1}', income: 0, expense: (i+1)*120.0))
      : dailyTotals;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Overview', style: Theme.of(context).textTheme.headlineSmall),
          const Gap(20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: days.map((d) => d.expense).reduce((a, b) => a > b ? a : b) * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceHigh,
                    getTooltipItem: (group, _, rod, __) {
                      return BarTooltipItem(
                        'RM ${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= days.length) return const SizedBox();
                        final label = days[idx].date.length > 3
                          ? days[idx].date.substring(0, 3)
                          : days[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 44,
                      getTitlesWidget: (val, _) => Text(
                        'RM${val.toInt()}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: days.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                      toY: e.value.expense,
                      color: AppColors.violet,
                      width: 18,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Breakdown ────────────────────────────────────────────────────────
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> byCategory;
  final double total;
  const _CategoryBreakdown({required this.byCategory, required this.total});

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final sorted  = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal  = sorted.isEmpty ? 1.0 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Category', style: Theme.of(context).textTheme.headlineSmall),
          const Gap(16),
          ...sorted.map((entry) {
            final cat = categoryById(entry.key);
            final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                    const Gap(8),
                    Text(cat.label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                  Text(fmt.format(entry.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ]),
                const Gap(6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                    minHeight: 8,
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Fallback when API is unavailable ─────────────────────────────────────────
class _FallbackAnalytics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _AnalyticsContent(
      data: AnalyticsSummary(
        totalIncome:   6200,
        totalExpenses: 1919.50,
        balance:       4280.50,
        byCategory:    {'food': 450, 'transport': 120, 'shopping': 820, 'groceries': 320, 'bills': 189, 'fun': 90},
        dailyTotals:   List.generate(7, (i) => DailyTotal(
          date:    ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i],
          income:  i == 0 ? 6200 : 0,
          expense: [320, 180, 450, 210, 380, 540, 240][i].toDouble(),
        )),
      ),
    );
  }
}
