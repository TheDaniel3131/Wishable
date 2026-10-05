import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

// ── Transaction ───────────────────────────────────────────────────────────────
@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String   id,
    required String   type,        // 'expense' | 'income'
    required double   amount,
    required String   description,
    required String   category,
    required DateTime date,
    String?           receiptUrl,
    String?           qrData,
    String?           notes,
    @Default(false) bool isScanned,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

// ── Budget ─────────────────────────────────────────────────────────────────────
@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String category,
    required double limitAmount,
    required String period,        // 'monthly' | 'weekly'
    @Default(0.0) double spent,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);
}

// ── Analytics Summary ──────────────────────────────────────────────────────────
@freezed
class AnalyticsSummary with _$AnalyticsSummary {
  const factory AnalyticsSummary({
    required double totalIncome,
    required double totalExpenses,
    required double balance,
    required Map<String, double> byCategory,
    required List<DailyTotal>    dailyTotals,
  }) = _AnalyticsSummary;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsSummaryFromJson(json);
}

@freezed
class DailyTotal with _$DailyTotal {
  const factory DailyTotal({
    required String date,
    required double income,
    required double expense,
  }) = _DailyTotal;

  factory DailyTotal.fromJson(Map<String, dynamic> json) =>
      _$DailyTotalFromJson(json);
}

// ── Receipt Scan Result ────────────────────────────────────────────────────────
@freezed
class ReceiptScanResult with _$ReceiptScanResult {
  const factory ReceiptScanResult({
    required String         merchant,
    required List<LineItem> items,
    required double         subtotal,
    required double         tax,
    required double         total,
    required String         currency,
  }) = _ReceiptScanResult;

  factory ReceiptScanResult.fromJson(Map<String, dynamic> json) =>
      _$ReceiptScanResultFromJson(json);
}

@freezed
class LineItem with _$LineItem {
  const factory LineItem({
    required String name,
    required double price,
    @Default(1) int quantity,
  }) = _LineItem;

  factory LineItem.fromJson(Map<String, dynamic> json) =>
      _$LineItemFromJson(json);
}

// ── User ───────────────────────────────────────────────────────────────────────
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String name,
    required String email,
    String?         avatarUrl,
    @Default('MYR') String currency,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
