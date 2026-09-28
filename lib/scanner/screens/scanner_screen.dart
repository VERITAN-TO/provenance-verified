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
  // R66: an invalid/deceptive QR scan must expose an accessible error, not
  // only a visual SnackBar — a screen-reader user watching a live camera
  // view may never discover a transient SnackBar. This persists on screen
  // (liveRegion announces it) until the next valid scan or manual dismiss.
  String? _scanError;

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final result = QrHandler.parse(raw);
    if (result is QrValid) {
      setState(() {
        _processing = true;
        _scanError = null;
      });
      _controller.stop();
      context.push('/verify/${result.publicId}').then((_) {
        _processing = false;
        _controller.start();
      });
    } else if (result is QrInvalid && raw != null) {
      setState(() => _scanError = result.reason);
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
          if (_scanError != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Semantics(
                liveRegion: true,
                label: 'Scan error: $_scanError',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: PvColors.error,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scanError!,
                            style: PvTypography.bodySmall.copyWith(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Dismiss',
                          onPressed: () => setState(() => _scanError = null),
                        ),
                      ],
                    ),
                  ),
                ),
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
