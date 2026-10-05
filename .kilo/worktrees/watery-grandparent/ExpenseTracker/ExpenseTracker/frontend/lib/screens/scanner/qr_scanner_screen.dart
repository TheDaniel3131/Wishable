import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gap/gap.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});
  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final _controller    = MobileScannerController(facing: CameraFacing.back, torchEnabled: false);
  final _manualCtrl    = TextEditingController();
  bool  _scanned       = false;
  bool  _isProcessing  = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _isProcessing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    setState(() => _scanned = true);
    await _processQR(raw);
  }

  Future<void> _processQR(String raw) async {
    setState(() => _isProcessing = true);
    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.parseQRCode(raw);
      if (mounted) {
        context.pop();
        context.push('/add', extra: result);
      }
    } catch (e) {
      // Fallback: parse locally
      _parseLocally(raw);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _parseLocally(String raw) {
    double? amount;
    String  desc = 'QR Payment';
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      amount = (obj['amount'] ?? obj['total'] ?? obj['billTotal'])?.toDouble();
      desc   = obj['merchant']?.toString() ?? obj['description']?.toString() ?? desc;
    } catch (_) {
      final match = RegExp(r'\d+\.?\d*').firstMatch(raw);
      if (match != null) amount = double.tryParse(match.group(0)!);
    }
    if (mounted) {
      context.pop();
      context.push('/add', extra: {'amount': amount, 'description': desc});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Camera
        MobileScanner(controller: _controller, onDetect: _onDetect),

        // Dark vignette
        Container(decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center, radius: .7,
            colors: [Colors.transparent, Colors.black.withOpacity(.6)],
          ),
        )),

        // Scanner frame
        Center(child: _ScannerFrame()),

        // UI overlay
        SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                const Gap(12),
                const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                // Torch toggle
                GestureDetector(
                  onTap: () => _controller.toggleTorch(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.white),
                  ),
                ),
              ]),
            ),

            const Spacer(),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Point camera at a QR code',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const Gap(40),

            // Manual input panel
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Manual Input', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const Gap(10),
                TextField(
                  controller: _manualCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '{"amount":25.90,"merchant":"DuitNow"}',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_manualCtrl.text.isNotEmpty) _processQR(_manualCtrl.text.trim());
                    },
                    child: const Text('Parse QR Data'),
                  ),
                ),
              ]),
            ),
            const Gap(20),
          ]),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: AppColors.violet)),
          ),
      ]),
    );
  }
}

// ── Scanner Frame ─────────────────────────────────────────────────────────────
class _ScannerFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240, height: 240,
      child: Stack(children: [
        // Corner brackets
        Positioned(top: 0, left: 0,    child: _Corner(top: true,  left: true)),
        Positioned(top: 0, right: 0,   child: _Corner(top: true,  left: false)),
        Positioned(bottom: 0, left: 0, child: _Corner(top: false, left: true)),
        Positioned(bottom: 0, right: 0,child: _Corner(top: false, left: false)),
        // Animated scan line
        _ScanLine(),
      ]),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top, left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        border: Border(
          top:    top    ? const BorderSide(color: AppColors.violet, width: 3) : BorderSide.none,
          bottom: !top   ? const BorderSide(color: AppColors.violet, width: 3) : BorderSide.none,
          left:   left   ? const BorderSide(color: AppColors.violet, width: 3) : BorderSide.none,
          right:  !left  ? const BorderSide(color: AppColors.violet, width: 3) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft:     (top && left)    ? const Radius.circular(4) : Radius.zero,
          topRight:    (top && !left)   ? const Radius.circular(4) : Radius.zero,
          bottomLeft:  (!top && left)   ? const Radius.circular(4) : Radius.zero,
          bottomRight: (!top && !left)  ? const Radius.circular(4) : Radius.zero,
        ),
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: 24 + (_anim.value * 192),
        left: 0, right: 0,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.violet,
            boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(.6), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
