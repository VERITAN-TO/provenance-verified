import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/routing/qr_handler.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _processing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final result = QrHandler.parse(raw);
    if (result is QrValid) {
      setState(() => _processing = true);
      _controller.stop();
      context.push('/verify/${result.publicId}').then((_) {
        _processing = false;
        _controller.start();
      });
    } else if (result is QrInvalid && raw != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.reason),
          backgroundColor: PvColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROVENANCE VERIFIED™'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Enter ID manually',
            onPressed: () => context.push('/verify/manual'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Reliance receipts',
            onPressed: () => context.push('/my-pv/receipts'),
          ),
          IconButton(
            icon: const Icon(Icons.business_center_outlined),
            // R65: non-authoritative — this is a bounded batch Verify utility,
            // not a Professionally-authorized entry point. No server-authoritative
            // Professional authorization seam exists to gate on (see estate search
            // in PR #3 comment history); do not imply authorization here.
            tooltip: 'Batch verify',
            onPressed: () => context.push('/professional/batch'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Semantics(
            label: 'Camera viewfinder. Point at a PROVENANCE VERIFIED™ QR code to scan.',
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan a PROVENANCE VERIFIED™ QR code',
                style: PvTypography.bodySmall.copyWith(
                  color: Colors.white70,
                ),
                semanticsLabel: 'Scan a PROVENANCE VERIFIED™ QR code',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
