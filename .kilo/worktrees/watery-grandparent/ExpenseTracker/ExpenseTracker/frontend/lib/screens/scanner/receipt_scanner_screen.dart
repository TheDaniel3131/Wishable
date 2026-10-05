import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';

class ReceiptScannerScreen extends ConsumerStatefulWidget {
  final Function(ReceiptScanResult)? onResult;
  const ReceiptScannerScreen({super.key, this.onResult});

  @override
  ConsumerState<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  File?               _imageFile;
  ReceiptScanResult?  _result;
  bool                _isAnalyzing = false;
  String?             _error;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90, maxWidth: 1800);
    if (picked == null) return;
    setState(() { _imageFile = File(picked.path); _result = null; _error = null; });
    await _analyze();
  }

  Future<void> _analyze() async {
    if (_imageFile == null) return;
    setState(() => _isAnalyzing = true);
    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.scanReceipt(_imageFile!);
      setState(() { _result = result; _isAnalyzing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isAnalyzing = false; });
    }
  }

  void _useResult() {
    if (_result == null) return;
    widget.onResult?.call(_result!);
    context.pop();
    if (widget.onResult == null) {
      context.push('/add', extra: {
        'amount':      _result!.total,
        'description': _result!.merchant,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

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
                  child: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                ),
              ),
              const Gap(12),
              Text('Scan Receipt', style: Theme.of(context).textTheme.headlineMedium),
            ]),
          ),
          const Gap(20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [

                // ── Image area ──────────────────────────────────────────────
                if (_imageFile == null)
                  _UploadPlaceholder(
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                  ).animate().fadeIn()
                else
                  Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_imageFile!, height: 280, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const Gap(12),
                    Row(children: [
                      Expanded(child: _OutlineBtn(icon: Icons.camera_alt_rounded,    label: 'Retake',  onTap: () => _pickImage(ImageSource.camera))),
                      const Gap(8),
                      Expanded(child: _OutlineBtn(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: () => _pickImage(ImageSource.gallery))),
                    ]),
                  ]).animate().fadeIn(),

                const Gap(20),

                // ── Analyzing state ─────────────────────────────────────────
                if (_isAnalyzing)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(children: [
                      const CircularProgressIndicator(color: AppColors.violet, strokeWidth: 2),
                      const Gap(16),
                      const Text('Analyzing with Claude Vision...', style: TextStyle(color: AppColors.textSecondary)),
                      const Gap(4),
                      const Text('Extracting items, tax, and total', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ).animate().fadeIn(),

                // ── Error state ─────────────────────────────────────────────
                if (_error != null && !_isAnalyzing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.red.withOpacity(.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 20),
                      const Gap(10),
                      Expanded(child: Text('Analysis failed: $_error', style: const TextStyle(color: AppColors.red, fontSize: 13))),
                    ]),
                  ).animate().fadeIn(),

                // ── Result ──────────────────────────────────────────────────
                if (_result != null && !_isAnalyzing)
                  _ReceiptResultCard(result: _result!, fmt: fmt).animate().fadeIn().slideY(begin: .05),

                const Gap(20),

                // ── Use this button ─────────────────────────────────────────
                if (_result != null && !_isAnalyzing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _useResult,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text('Use ${fmt.format(_result!.total)}'),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                const Gap(40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Upload placeholder ────────────────────────────────────────────────────────
class _UploadPlaceholder extends StatelessWidget {
  final VoidCallback onCamera, onGallery;
  const _UploadPlaceholder({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMid, width: 2, style: BorderStyle.solid),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.amber.withOpacity(.12), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, color: AppColors.amber, size: 32),
        ),
        const Gap(16),
        const Text('Upload your receipt', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const Gap(6),
        const Text('Claude AI will extract all items and total', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Gap(24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          ),
          const Gap(12),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.textSecondary),
            label: const Text('Gallery', style: TextStyle(color: AppColors.textSecondary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Receipt result card ───────────────────────────────────────────────────────
class _ReceiptResultCard extends StatelessWidget {
  final ReceiptScanResult result;
  final NumberFormat fmt;
  const _ReceiptResultCard({required this.result, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.violet.withOpacity(.3)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.violet),
            Gap(6),
            Text('Extracted by Claude AI', style: TextStyle(color: AppColors.violet, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
        const Gap(16),

        // Merchant
        if (result.merchant.isNotEmpty)
          _Row(label: result.merchant, value: '', isHeader: true),

        const Divider(height: 20),

        // Line items
        ...result.items.map((item) => _Row(label: item.name, value: fmt.format(item.price))),

        if (result.tax > 0) ...[
          const Divider(height: 20),
          _Row(label: 'Tax', value: fmt.format(result.tax)),
        ],

        const Divider(height: 20),
        _Row(label: 'TOTAL', value: fmt.format(result.total), isTotal: true),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool isHeader, isTotal;
  const _Row({required this.label, required this.value, this.isHeader = false, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(
          fontSize: isHeader ? 16 : isTotal ? 14 : 14,
          fontWeight: isHeader || isTotal ? FontWeight.w700 : FontWeight.w400,
          color: isHeader ? AppColors.textPrimary : AppColors.textSecondary,
        ))),
        if (value.isNotEmpty)
          Text(value, style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          )),
      ]),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderMid),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const Gap(8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}
