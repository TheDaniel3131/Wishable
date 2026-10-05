import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

// ── Analytics Period ──────────────────────────────────────────────────────────
enum AnalyticsPeriod { week, month, year }

final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>(
  (_) => AnalyticsPeriod.month,
);

// ── Transactions ──────────────────────────────────────────────────────────────
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    return ref.read(apiServiceProvider).getTransactions();
  }

  Future<void> add(Transaction tx) async {
    final api = ref.read(apiServiceProvider);
    final created = await api.createTransaction(tx);
    state = AsyncData([created, ...state.value ?? []]);
  }

  Future<void> remove(String id) async {
    await ref.read(apiServiceProvider).deleteTransaction(id);
    state = AsyncData(
      (state.value ?? []).where((t) => t.id != id).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(apiServiceProvider).getTransactions(),
    );
  }
}

// ── Analytics ─────────────────────────────────────────────────────────────────
final analyticsProvider =
    FutureProvider.family<AnalyticsSummary, String>((ref, period) async {
  return ref.read(apiServiceProvider).getAnalytics(period);
});

// ── Budgets ───────────────────────────────────────────────────────────────────
final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    return ref.read(apiServiceProvider).getBudgets();
  }

  Future<void> add(Budget budget) async {
    final created = await ref.read(apiServiceProvider).createBudget(budget);
    state = AsyncData([...state.value ?? [], created]);
  }

  Future<void> update(String id, Budget budget) async {
    final updated = await ref.read(apiServiceProvider).updateBudget(id, budget);
    state = AsyncData(
      (state.value ?? []).map((b) => b.id == id ? updated : b).toList(),
    );
  }

  Future<void> remove(String id) async {
    await ref.read(apiServiceProvider).deleteBudget(id);
    state = AsyncData(
      (state.value ?? []).where((b) => b.id != id).toList(),
    );
  }
}

// ── Balance Summary (derived from transactions) ───────────────────────────────
final balanceSummaryProvider = Provider<({double income, double expense, double balance})>((ref) {
  final txs = ref.watch(transactionsProvider).value ?? [];
  double income = 0, expense = 0;
  for (final tx in txs) {
    if (tx.type == 'income') income += tx.amount;
    else expense += tx.amount;
  }
  return (income: income, expense: expense, balance: income - expense);
});

// ── Recent transactions (last 5) ──────────────────────────────────────────────
final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txs = ref.watch(transactionsProvider).value ?? [];
  final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));
  return sorted.take(5).toList();
});
