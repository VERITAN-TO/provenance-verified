// My PV — customer asset wallet.
// Requires authentication. Shows a sign-in CTA for anonymous users.
// Trust tier display follows MTA1: server determines, mobile displays.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/my_pv_models.dart';
import '../providers/my_pv_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';

class MyPvScreen extends ConsumerWidget {
  const MyPvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My PV')),
        body: _UnauthenticatedView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My PV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Submit new asset',
            onPressed: () => context.push('/submit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit'),
        backgroundColor: PvColors.cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Submit Asset'),
      ),
      body: RefreshIndicator(
        color: PvColors.cyan,
        onRefresh: () async => ref.invalidate(customerAssetsProvider),
        child: _AssetGrid(),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Unauthenticated CTA
// ────────────────────────────────────────────────────────────────────────────

class _UnauthenticatedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: PvColors.silver, size: 56),
            const SizedBox(height: 20),
            const Text('Sign in to view your assets', style: PvTypography.title),
            const SizedBox(height: 10),
            Text(
              'Your digital passports, custody history, and reliance receipts are waiting.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => context.push('/sign-in'),
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.cyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Asset grid — list + grid adaptive layout
// ────────────────────────────────────────────────────────────────────────────

class _AssetGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(customerAssetsProvider);
    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorView(error: err),
      data: (assets) {
        if (assets.isEmpty) {
          return _EmptyAssetsView();
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: assets.length,
          itemBuilder: (context, i) => _AssetCard(asset: assets[i]),
        );
      },
    );
  }
}

class _AssetCard extends StatelessWidget {
  final CustomerAsset asset;
  const _AssetCard({required this.asset});

  Color _tierColor(int? tier) {
    switch (tier) {
      case 1: return PvColors.tier1;
      case 2: return PvColors.tier2;
      case 3: return PvColors.tier3;
      case 4: return PvColors.tier4;
      default: return PvColors.muted;
    }
  }

  String _tierLabel(int? tier) {
    if (tier == null) return 'NOT QUALIFIED';
    switch (tier) {
      case 1: return 'T1 FINGERPRINT';
      case 2: return 'T2 DECLARED';
      case 3: return 'T3 VERIFIED';
      case 4: return 'T4 GOLD';
      default: return 'TIER $tier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(asset.trustTier);
    return Semantics(
      label: '${asset.assetName}, ${_tierLabel(asset.trustTier)}${asset.hasStaledReceipts ? ', stale receipts' : ''}',
      button: true,
      child: InkWell(
        onTap: () => context.push('/my-pv/asset/${asset.assetId}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: PvColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: asset.hasStaledReceipts ? PvColors.warning : PvColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asset image / placeholder
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  child: asset.imageUrl != null
                      ? Image.network(
                          asset.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _AssetPlaceholder(),
                        )
                      : _AssetPlaceholder(),
                ),
              ),

              // Info section
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.assetName,
                      style: PvTypography.body.copyWith(
                        color: PvColors.onBackground,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.assetType,
                      style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: tierColor.withAlpha(30),
                              border: Border.all(color: tierColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tierLabel(asset.trustTier),
                              style: PvTypography.label.copyWith(
                                  color: tierColor, fontSize: 8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (asset.hasStaledReceipts)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Tooltip(
                              message: 'Stale receipts',
                              child: Icon(Icons.update,
                                  color: PvColors.warning, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PvColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined,
            color: PvColors.muted, size: 40),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ────────────────────────────────────────────────────────────────────────────

class _EmptyAssetsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: PvColors.muted, size: 56),
            const SizedBox(height: 16),
            const Text('No assets yet', style: PvTypography.title),
            const SizedBox(height: 8),
            Text(
              'Submit your first asset to start building your provenance record.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/submit'),
              icon: const Icon(Icons.add),
              label: const Text('Submit Asset'),
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.cyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final msg = error.toString();
    final isAuth = msg.contains('not_authenticated');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuth ? Icons.lock_outline : Icons.error_outline,
              color: isAuth ? PvColors.silver : PvColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isAuth ? 'Session expired' : 'Could not load assets',
              style: PvTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              isAuth
                  ? 'Please sign in again.'
                  : 'Check your connection and pull down to retry.',
              style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              textAlign: TextAlign.center,
            ),
            if (isAuth) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/sign-in'),
                style: FilledButton.styleFrom(
                  backgroundColor: PvColors.cyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
