import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/qr_handler.dart';
import '../../design/pv_colors.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final text = _controller.text.trim();
    if (!QrHandler.isValidPublicId(text)) {
      setState(() => _error = 'Enter a valid PV or DET public ID (e.g. PV-TEST-T4D004)');
      return;
    }
    context.go('/verify/${text.toUpperCase()}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Record ID')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Public ID',
                hintText: 'PV-TEST-T4D004',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.tier4,
                foregroundColor: Colors.black,
              ),
              child: const Text('Look up'),
            ),
          ],
        ),
      ),
    );
  }
}
