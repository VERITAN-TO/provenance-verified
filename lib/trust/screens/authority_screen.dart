import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';
import '../../core/config/constants.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class AuthorityScreen extends ConsumerWidget {
  final String publicId;
  const AuthorityScreen({super.key, required this.publicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));
    return Scaffold(
      appBar: AppBar(title: const Text('Issuing Authority')),
      body: trustAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (record) {
          final authority = record.authority;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PvColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ISSUING AUTHORITY',
                      style: PvTypography.label.copyWith(color: PvColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authority?.issuingEntity ?? 'Not recorded',
                      style: PvTypography.title,
                    ),
                    if (authority?.credentialId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Credential: ${authority!.credentialId}',
                          style: PvTypography.body,
                        ),
                      ),
                    if (authority?.credentialValid != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              authority!.credentialValid! ? Icons.check_circle : Icons.cancel,
                              color: authority.credentialValid! ? PvColors.success : PvColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              authority.credentialValid! ? 'Credential valid' : 'Credential invalid',
                              style: PvTypography.bodySmall.copyWith(
                                color: authority.credentialValid! ? PvColors.success : PvColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PvColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MTA-1 CONTRACT',
                      style: PvTypography.label.copyWith(color: PvColors.muted),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      PvConstants.mta1ContractSha,
                      style: PvTypography.mono.copyWith(color: PvColors.tier3),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
