import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../models/transaction.dart';

// ── API Config ────────────────────────────────────────────────────────────────
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
}

// ── API Service ───────────────────────────────────────────────────────────────
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.addAll([
      // Auth token injection
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.delete(key: 'auth_token');
          }
          handler.next(error);
        },
      ),
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    ]);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email, 'password': password,
    });
    final token = res.data['token'] as String;
    await _storage.write(key: 'auth_token', value: token);
    return res.data;
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name, 'email': email, 'password': password,
    });
    final token = res.data['token'] as String;
    await _storage.write(key: 'auth_token', value: token);
    return res.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  // ── Transactions ────────────────────────────────────────────────────────────
  Future<List<Transaction>> getTransactions({
    String? type,
    String? category,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get('/transactions', queryParameters: {
      if (type       != null) 'type':       type,
      if (category   != null) 'category':   category,
      if (startDate  != null) 'startDate':  startDate,
      if (endDate    != null) 'endDate':    endDate,
      'page': page, 'limit': limit,
    });
    return (res.data['data'] as List)
        .map((j) => Transaction.fromJson(j))
        .toList();
  }

  Future<Transaction> createTransaction(Transaction tx) async {
    final res = await _dio.post('/transactions', data: tx.toJson());
    return Transaction.fromJson(res.data['data']);
  }

  Future<Transaction> updateTransaction(String id, Transaction tx) async {
    final res = await _dio.put('/transactions/$id', data: tx.toJson());
    return Transaction.fromJson(res.data['data']);
  }

  Future<void> deleteTransaction(String id) async {
    await _dio.delete('/transactions/$id');
  }

  // ── Analytics ───────────────────────────────────────────────────────────────
  Future<AnalyticsSummary> getAnalytics(String period) async {
    final res = await _dio.get('/analytics', queryParameters: {'period': period});
    return AnalyticsSummary.fromJson(res.data['data']);
  }

  // ── Budgets ─────────────────────────────────────────────────────────────────
  Future<List<Budget>> getBudgets() async {
    final res = await _dio.get('/budgets');
    return (res.data['data'] as List)
        .map((j) => Budget.fromJson(j))
        .toList();
  }

  Future<Budget> createBudget(Budget budget) async {
    final res = await _dio.post('/budgets', data: budget.toJson());
    return Budget.fromJson(res.data['data']);
  }

  Future<Budget> updateBudget(String id, Budget budget) async {
    final res = await _dio.put('/budgets/$id', data: budget.toJson());
    return Budget.fromJson(res.data['data']);
  }

  Future<void> deleteBudget(String id) async {
    await _dio.delete('/budgets/$id');
  }

  // ── Receipt Scanning (Claude Vision) ────────────────────────────────────────
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final formData = FormData.fromMap({
      'receipt': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'receipt.jpg',
      ),
    });
    final res = await _dio.post('/scan/receipt', data: formData);
    return ReceiptScanResult.fromJson(res.data['data']);
  }

  // QR parse is done on the backend to normalize formats
  Future<Map<String, dynamic>> parseQRCode(String rawData) async {
    final res = await _dio.post('/scan/qr', data: {'raw': rawData});
    return res.data['data'];
  }
}

// ── Riverpod Provider ─────────────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
