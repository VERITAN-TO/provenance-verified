import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../trust/providers/trust_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

// PROFESSIONAL_CANNOT_SELECT_TIER — this screen projects canonical trust only.
// Server determines tier. This screen may not select tier, strengthen evidence,
// issue marks, or bypass tenant/auth. The tracked-ID list below is local/session
// state only — it is NOT a server-authoritative tenant inventory, and no proven
// server-authoritative Professional authorization seam exists to gate this screen
// on (R65 estate search: PR #3 comment history). Trust state is live from server.
// Fails closed on partial/unknown authority.
// MONEY_CONTROLS_TRUST = FALSE. PHYSICAL_MATCH_NOT_SUPPORTED.

class ProfessionalInventoryScreen extends ConsumerStatefulWidget {
  const ProfessionalInventoryScreen({super.key});

  @override
  ConsumerState<ProfessionalInventoryScreen> createState() =>
      _ProfessionalInventoryScreenState();
}

class _ProfessionalInventoryScreenState
    extends ConsumerState<ProfessionalInventoryScreen> {
  final _controller = TextEditingController();
  final List<String> _trackedIds = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addId() {
    final id = _controller.text.trim();
    if (id.isEmpty || _trackedIds.contains(id)) return;
    setState(() => _trackedIds.add(id));
    _controller.clear();
  }

  void _removeId(String id) {
    setState(() => _trackedIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // R65: non-authoritative — "Tracked Records", not "Professional
      // Inventory". This list is local/session state only, not a server
      // inventory, tenant membership, or professional authorization.
      appBar: AppBar(title: const Text('Tracked Records')),
      body: Column(
        children: [
          // Capability header — plain-language disclosure, no internal control
          // tokens in customer-visible text (tokens remain in the file header
          // comment above and in tests — PROFESSIONAL_CANNOT_SELECT_TIER,
          // PHYSICAL_MATCH_NOT_SUPPORTED).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: PvColors.muted.withAlpha(20),
            child: Text(
              'Canonical trust projection only. Tier is determined by PV and '
              'cannot be selected here. Physical object matching: not available. '
              'This list is local to your session only.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              semanticsLabel:
                  'Tracked records: canonical trust projection only. Tier is '
                  'determined by PV. Physical object matching: not available — '
                  'not supported in any mode. This list is local to your session only.',
            ),
          ),
          // Track ID entry row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Track Record ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addId(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addId,
                  style: FilledButton.styleFrom(
                    backgroundColor: PvColors.cyan,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Track'),
                ),
              ],
            ),
          ),
          if (_trackedIds.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Add record IDs above to track their trust state.',
                  style: TextStyle(color: PvColors.muted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _trackedIds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final id = _trackedIds[i];
                  return _InventoryRow(
                    publicId: id,
                    onRemove: () => _removeId(id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inventory row — live trust query, fail-closed, navigable to trust result
// ─────────────────────────────────────────────────────────────────────────────

class _InventoryRow extends ConsumerWidget {
  final String publicId;
  final VoidCallback onRemove;
  const _InventoryRow({required this.publicId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustRecordProvider(publicId));

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        // Navigate to full trust result only when tier is determined
        onTap: trustAsync.valueOrNull?.safeTier != null
            ? () => context.push('/verify/$publicId')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: trustAsync.when(
            loading: () => Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Loading trust record'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(publicId, style: PvTypography.mono)),
                _RemoveButton(onRemove: onRemove),
              ],
            ),
            error: (e, _) => _UnavailableInventoryRow(
              publicId: publicId,
              reason:
                  'Query failed — ${e.toString().split('\n').first}',
              onRemove: onRemove,
            ),
            data: (record) {
              final tier = record.safeTier;
              if (tier == null) {
                // Fail closed: UNQUALIFIED or no determination → AUTHORITY UNAVAILABLE
                return _UnavailableInventoryRow(
                  publicId: publicId,
                  reason:
                      'AUTHORITY UNAVAILABLE — do not rely on this record.',
                  onRemove: onRemove,
                );
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PvColors.cyan.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'T$tier',
                      style: PvTypography.label
                          .copyWith(color: PvColors.cyan),
                      semanticsLabel: 'Tier $tier — server-determined',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      publicId,
                      style: PvTypography.mono,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: PvColors.muted, size: 16),
                  const SizedBox(width: 4),
                  _RemoveButton(onRemove: onRemove),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onRemove;
  const _RemoveButton({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.remove_circle_outline,
          size: 18, color: PvColors.muted),
      onPressed: onRemove,
      tooltip: 'Remove from tracked records',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

class _UnavailableInventoryRow extends StatelessWidget {
  final String publicId;
  final String reason;
  final VoidCallback onRemove;
  const _UnavailableInventoryRow({
    required this.publicId,
    required this.reason,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Authority unavailable for $publicId: $reason',
      child: Row(
        children: [
          const Icon(Icons.block, color: PvColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(publicId,
                    style: PvTypography.mono,
                    overflow: TextOverflow.ellipsis),
                Text(
                  reason,
                  style: PvTypography.bodySmall
                      .copyWith(color: PvColors.error),
                ),
              ],
            ),
          ),
          _RemoveButton(onRemove: onRemove),
        ],
      ),
    );
  }
}
