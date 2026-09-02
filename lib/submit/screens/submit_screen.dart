// SubmitScreen — multi-step gemstone certification submission wizard.
//
// MONEY_CONTROLS_TRUST = FALSE
// CLIENT_CLAIMED_LAB_CONFIRMED = ZERO
//
// Payment is a prerequisite to BEGIN processing, not a factor in trust
// determination.  The selected service tier is a REQUESTED SERVICE.
// The determined trust tier is set exclusively by the backend after review.
// Uploading a document does not guarantee any specific trust tier.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/submit_models.dart';
import '../providers/submit_provider.dart';
import '../widgets/service_tier_card.dart';
import '../../design/pv_colors.dart';
import '../../design/pv_typography.dart';
import '../../core/config/environment.dart';

// ---------------------------------------------------------------------------
// Total wizard steps
// ---------------------------------------------------------------------------

const int _kTotalSteps = 7; // 0-6

class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  bool _loading  = false;
  String? _error;

  // Quote fetched in step 4
  SubmissionQuote? _quote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(submitProvider);
      if (draft == null) {
        ref.read(submitProvider.notifier).beginNew();
      }
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _setError(String? msg) => setState(() => _error = msg);
  void _setLoading(bool v)    => setState(() { _loading = v; if (v) _error = null; });

  Future<void> _next() async {
    final notifier = ref.read(submitProvider.notifier);
    final draft    = ref.read(submitProvider);
    if (draft == null) return;

    _setLoading(true);
    _setError(null);

    try {
      switch (draft.step) {
        case 0: // Service selection → start submission on backend
          if (draft.selectedTier == null) {
            _setError('Please select a service tier before continuing.');
            return;
          }
          await notifier.startSubmission();
          break;

        case 1: // Asset info → save to backend
          if (draft.assetName.trim().isEmpty) {
            _setError('Please enter an asset name.');
            return;
          }
          if (draft.assetType.trim().isEmpty) {
            _setError('Please select an asset type.');
            return;
          }
          await notifier.saveAssetInfo();
          notifier.goToStep(2);
          break;

        case 2: // Evidence upload → upload pending documents
          await notifier.uploadPendingDocuments();
          notifier.goToStep(3);
          break;

        case 3: // Declarations → save to backend
          final d = ref.read(submitProvider);
          if (d == null || !d.declarationsComplete) {
            _setError('Please complete all declarations before continuing.');
            return;
          }
          await notifier.saveDeclarations();
          // Fetch quote immediately for step 4
          final quote = await notifier.fetchQuote();
          setState(() => _quote = quote);
          notifier.goToStep(4);
          break;

        case 4: // Review & Pricing — user taps "Proceed to Payment"
          notifier.goToStep(5);
          break;

        case 5: // Checkout step — handled by button handlers, not here
          break;

        default:
          break;
      }
    } on SubmitApiException catch (e) {
      _setError('Server error (${e.statusCode}): ${e.message}');
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _back() async {
    final draft = ref.read(submitProvider);
    if (draft == null || draft.step == 0) return;
    ref.read(submitProvider.notifier).goToStep(draft.step - 1);
    setState(() => _error = null);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(submitProvider);
    final step  = draft?.step ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stepTitle(step),
          style: PvTypography.label.copyWith(color: PvColors.onBackground),
        ),
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: _loading ? null : _back,
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Progress bar ───────────────────────────────────────────────
          _ProgressBar(currentStep: step, totalSteps: _kTotalSteps),

          // ── Error banner ───────────────────────────────────────────────
          if (_error != null)
            _ErrorBanner(message: _error!, onDismiss: () => _setError(null)),

          // ── Step content ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: PvColors.cyan,
                      strokeWidth: 2,
                    ),
                  )
                : _buildStep(draft, step),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(SubmissionDraft? draft, int step) {
    switch (step) {
      case 0: return _Step0ServiceSelection(
                  draft:     draft,
                  onNext:    _next,
                  loading:   _loading,
                );
      case 1: return _Step1AssetInfo(draft: draft, onNext: _next, loading: _loading);
      case 2: return _Step2Evidence(draft: draft, onNext: _next, loading: _loading);
      case 3: return _Step3Declarations(draft: draft, onNext: _next, loading: _loading);
      case 4: return _Step4ReviewPricing(
                  draft:   draft,
                  quote:   _quote,
                  onNext:  _next,
                  loading: _loading,
                );
      case 5: return _Step5Checkout(
                  draft:      draft,
                  onComplete: _handleCheckoutComplete,
                  loading:    _loading,
                );
      case 6: return _Step6Confirmation(draft: draft);
      default: return const SizedBox.shrink();
    }
  }

  Future<void> _handleCheckoutComplete() async {
    _setLoading(true);
    _setError(null);
    try {
      final isQual = Env.isQualification || Env.isDevelopment;
      await ref.read(submitProvider.notifier).checkout(testMode: isQual);
      ref.read(submitProvider.notifier).goToStep(6);
    } on SubmitApiException catch (e) {
      _setError('Checkout error (${e.statusCode}): ${e.message}');
    } catch (e) {
      _setError('Checkout failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  String _stepTitle(int step) {
    const titles = [
      'SELECT SERVICE',
      'ASSET INFORMATION',
      'EVIDENCE UPLOAD',
      'DECLARATIONS',
      'REVIEW & PRICING',
      'CHECKOUT',
      'SUBMISSION CONFIRMED',
    ];
    if (step < titles.length) return titles[step];
    return 'SUBMIT';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Progress bar
// ────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _ProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps > 0 ? (currentStep + 1) / totalSteps : 0.0;
    return Semantics(
      label: 'Step ${currentStep + 1} of $totalSteps',
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: PvColors.border,
        color: PvColors.cyan,
        minHeight: 3,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error banner
// ────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: PvColors.error.withAlpha(30),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: PvColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: PvTypography.bodySmall.copyWith(color: PvColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: PvColors.error),
            padding: EdgeInsets.zero,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 0 — Service Selection
// ────────────────────────────────────────────────────────────────────────────

class _Step0ServiceSelection extends ConsumerWidget {
  final SubmissionDraft? draft;
  final Future<void> Function() onNext;
  final bool loading;

  const _Step0ServiceSelection({
    required this.draft,
    required this.onNext,
    required this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTier = draft?.selectedTier;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Select Requested Service',
                style: PvTypography.headline.copyWith(color: PvColors.onBackground),
              ),
              const SizedBox(height: 6),
              Text(
                'This is your requested service tier — it is not a guaranteed outcome. '
                'The trust determination is made exclusively by the PROVENANCE VERIFIED '
                'team after evidence review.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
              const SizedBox(height: 20),
              ...ServiceTier.values.map(
                (tier) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ServiceTierCard(
                    tier:       tier,
                    isSelected: selectedTier == tier,
                    onSelect:   () => ref.read(submitProvider.notifier).selectTier(tier),
                  ),
                ),
              ),
            ],
          ),
        ),
        _BottomBar(
          onNext: selectedTier != null ? onNext : null,
          nextLabel: 'Continue',
          loading: loading,
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 1 — Asset Information
// ────────────────────────────────────────────────────────────────────────────

class _Step1AssetInfo extends ConsumerStatefulWidget {
  final SubmissionDraft? draft;
  final Future<void> Function() onNext;
  final bool loading;

  const _Step1AssetInfo({
    required this.draft,
    required this.onNext,
    required this.loading,
  });

  @override
  ConsumerState<_Step1AssetInfo> createState() => _Step1AssetInfoState();
}

class _Step1AssetInfoState extends ConsumerState<_Step1AssetInfo> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _speciesCtrl;
  late final TextEditingController _varietyCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _dimensionsCtrl;
  late final TextEditingController _originCtrl;
  late final TextEditingController _treatmentsCtrl;

  String? _selectedAssetType;

  static const _assetTypes = [
    'Natural Gemstone',
    'Treated Gemstone',
    'Synthetic Gemstone',
    'Imitation / Simulant',
    'Assembled Stone',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final d    = widget.draft;
    final attrs = d?.gemstoneAttributes ?? const GemstoneAttributes();
    _nameCtrl         = TextEditingController(text: d?.assetName ?? '');
    _speciesCtrl      = TextEditingController(text: attrs.species);
    _varietyCtrl      = TextEditingController(text: attrs.variety);
    _weightCtrl       = TextEditingController(text: attrs.weight);
    _dimensionsCtrl   = TextEditingController(text: attrs.dimensions);
    _originCtrl       = TextEditingController(text: attrs.origin);
    _treatmentsCtrl   = TextEditingController(text: attrs.treatments);
    _selectedAssetType = d?.assetType.isEmpty == true ? null : d?.assetType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _varietyCtrl.dispose();
    _weightCtrl.dispose();
    _dimensionsCtrl.dispose();
    _originCtrl.dispose();
    _treatmentsCtrl.dispose();
    super.dispose();
  }

  void _syncToProvider() {
    final notifier = ref.read(submitProvider.notifier);
    notifier.updateAssetName(_nameCtrl.text.trim());
    notifier.updateAssetType(_selectedAssetType ?? '');
    notifier.updateGemstoneAttributes(GemstoneAttributes(
      species:    _speciesCtrl.text.trim(),
      variety:    _varietyCtrl.text.trim(),
      weight:     _weightCtrl.text.trim(),
      dimensions: _dimensionsCtrl.text.trim(),
      origin:     _originCtrl.text.trim(),
      treatments: _treatmentsCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Asset Information',
                  style: PvTypography.headline.copyWith(color: PvColors.onBackground)),
              const SizedBox(height: 16),

              _PvTextField(
                controller: _nameCtrl,
                label: 'Asset Name',
                hint: 'e.g. "Unheated Burma Ruby"',
                onChanged: (_) {},
              ),
              const SizedBox(height: 14),

              // Asset type dropdown
              _SectionLabel('Asset Type'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: PvColors.surface,
                  border: Border.all(color: PvColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAssetType,
                    hint: Text('Select type',
                        style: PvTypography.body.copyWith(color: PvColors.muted)),
                    isExpanded: true,
                    dropdownColor: PvColors.surfaceElevated,
                    style: PvTypography.body.copyWith(color: PvColors.onSurface),
                    onChanged: (v) => setState(() => _selectedAssetType = v),
                    items: _assetTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _SectionLabel('GEMSTONE ATTRIBUTES (DECLARED)'),
              Text(
                'These are your declared attributes. They are not verified at this stage.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
              const SizedBox(height: 12),

              _PvTextField(controller: _speciesCtrl,    label: 'Species',    hint: 'e.g. Corundum'),
              const SizedBox(height: 12),
              _PvTextField(controller: _varietyCtrl,    label: 'Variety',    hint: 'e.g. Ruby'),
              const SizedBox(height: 12),
              _PvTextField(controller: _weightCtrl,     label: 'Weight',     hint: 'e.g. 3.45 ct'),
              const SizedBox(height: 12),
              _PvTextField(controller: _dimensionsCtrl, label: 'Dimensions', hint: 'e.g. 9.2 × 7.1 × 4.3 mm'),
              const SizedBox(height: 12),
              _PvTextField(controller: _originCtrl,     label: 'Declared Origin', hint: 'e.g. Mogok, Myanmar (declared)'),
              const SizedBox(height: 12),
              _PvTextField(controller: _treatmentsCtrl, label: 'Declared Treatments',
                  hint: 'e.g. None declared, or Heat treated (declared)'),

              const SizedBox(height: 20),
              _SectionLabel('PHOTOS'),
              Text(
                'Add photos of the gemstone. Supported: JPEG, PNG.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
              const SizedBox(height: 8),
              _PhotoSection(),
            ],
          ),
        ),
        _BottomBar(
          onNext: () async {
            _syncToProvider();
            await onNext();
          },
          nextLabel: 'Continue',
          loading: widget.loading,
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Photo section (file-based; image_picker not in pubspec — placeholder UI)
// ────────────────────────────────────────────────────────────────────────────

class _PhotoSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoPaths = ref.watch(submitProvider)?.photoPaths ?? const [];

    return Column(
      children: [
        if (photoPaths.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: PvColors.border, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.camera_alt_outlined, color: PvColors.muted, size: 32),
                const SizedBox(height: 8),
                Text('No photos added',
                    style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: photoPaths
                .map((p) => _PhotoTile(
                      path: p,
                      onRemove: () => ref.read(submitProvider.notifier).removePhoto(p),
                    ))
                .toList(),
          ),
        const SizedBox(height: 12),
        // Note: image_picker is not in pubspec. This button is the integration
        // point. Add image_picker to pubspec and replace this with picker logic.
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Photo capture: add image_picker to pubspec to enable.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: PvColors.surface,
              ),
            );
          },
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Add Photo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PvColors.silver,
            side: const BorderSide(color: PvColors.border),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _PhotoTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: PvColors.surface,
            border: Border.all(color: PvColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.image_outlined, color: PvColors.muted, size: 32),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: PvColors.error,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 2 — Evidence Upload
// ────────────────────────────────────────────────────────────────────────────

class _Step2Evidence extends ConsumerWidget {
  final SubmissionDraft? draft;
  final Future<void> Function() onNext;
  final bool loading;

  const _Step2Evidence({
    required this.draft,
    required this.onNext,
    required this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = draft?.documents ?? const [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Evidence Upload',
                  style: PvTypography.headline.copyWith(color: PvColors.onBackground)),
              const SizedBox(height: 6),

              // Trust-neutrality notice — evidence review is server-authoritative
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PvColors.surface,
                  border: Border.all(color: PvColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: PvColors.silver, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uploaded documents are reviewed by our team. '
                        'Uploading a document does not guarantee any specific trust tier. '
                        'Trust determination is made exclusively by PROVENANCE VERIFIED '
                        'after review.',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (documents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: PvColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.upload_file_outlined, color: PvColors.muted, size: 32),
                      const SizedBox(height: 8),
                      Text('No documents added',
                          style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
                    ],
                  ),
                )
              else
                ...documents.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DocumentTile(
                          doc:      e.value,
                          index:    e.key,
                          onRemove: () => ref.read(submitProvider.notifier).removeDocument(e.key),
                          onTypeChanged: (t) => ref.read(submitProvider.notifier).updateDocumentType(e.key, t),
                        ),
                      ),
                    ),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Integration point: add file_picker to pubspec to enable
                  // real file picking. The backend endpoint accepts multipart
                  // POST /api/v1/customer/submissions/:id/evidence.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Document upload: add file_picker to pubspec to enable.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: PvColors.surface,
                    ),
                  );
                },
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Add Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PvColors.silver,
                  side: const BorderSide(color: PvColors.border),
                ),
              ),
            ],
          ),
        ),
        _BottomBar(
          onNext: onNext,
          nextLabel: 'Continue',
          loading: loading,
          skipLabel: documents.isEmpty ? 'Skip (no documents)' : null,
          onSkip: documents.isEmpty
              ? () => ref.read(submitProvider.notifier).goToStep(3)
              : null,
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final EvidenceDocument doc;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<EvidenceDocumentType> onTypeChanged;

  const _DocumentTile({
    required this.doc,
    required this.index,
    required this.onRemove,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PvColors.surface,
        border: Border.all(color: PvColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: PvColors.silver, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.fileName,
                    style: PvTypography.body.copyWith(color: PvColors.onBackground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                DropdownButton<EvidenceDocumentType>(
                  value: doc.docType,
                  isDense: true,
                  dropdownColor: PvColors.surfaceElevated,
                  style: PvTypography.bodySmall.copyWith(color: PvColors.silver),
                  underline: const SizedBox.shrink(),
                  onChanged: (v) { if (v != null) onTypeChanged(v); },
                  items: EvidenceDocumentType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          if (doc.uploaded)
            const Icon(Icons.check_circle, color: PvColors.success, size: 18)
          else
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: PvColors.muted),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 3 — Declarations
// ────────────────────────────────────────────────────────────────────────────

class _Step3Declarations extends ConsumerWidget {
  final SubmissionDraft? draft;
  final Future<void> Function() onNext;
  final bool loading;

  const _Step3Declarations({
    required this.draft,
    required this.onNext,
    required this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(submitProvider.notifier);
    final d        = draft;
    final ready    = d?.declarationsComplete == true;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Declarations',
                  style: PvTypography.headline.copyWith(color: PvColors.onBackground)),
              const SizedBox(height: 6),
              Text(
                'Please read and confirm each declaration before continuing.',
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
              const SizedBox(height: 20),

              _DeclarationCheckbox(
                value:     d?.declaredAccurate ?? false,
                onChanged: notifier.setDeclaredAccurate,
                text:      'I declare the above information is accurate to the best of my knowledge.',
              ),
              const SizedBox(height: 12),
              _DeclarationCheckbox(
                value:     d?.declaredTierMayDiffer ?? false,
                onChanged: notifier.setDeclaredTierMayDiffer,
                // Core constraint: client cannot over-claim tier
                text:      'I understand the determined trust tier may differ from my '
                           'requested service tier. The final determination is made '
                           'exclusively by the PROVENANCE VERIFIED review team.',
              ),
              const SizedBox(height: 12),
              _DeclarationCheckbox(
                value:     d?.declaredTermsAgreed ?? false,
                onChanged: notifier.setDeclaredTermsAgreed,
                text:      'I agree to the Terms of Service and Privacy Policy.',
              ),
            ],
          ),
        ),
        _BottomBar(
          onNext: ready ? onNext : null,
          nextLabel: 'Continue to Review',
          loading: loading,
        ),
      ],
    );
  }
}

class _DeclarationCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  const _DeclarationCheckbox({required this.value, required this.onChanged, required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: PvColors.cyan,
            side: const BorderSide(color: PvColors.border),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                text,
                style: PvTypography.body.copyWith(color: PvColors.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 4 — Review & Pricing
// ────────────────────────────────────────────────────────────────────────────

class _Step4ReviewPricing extends StatelessWidget {
  final SubmissionDraft? draft;
  final SubmissionQuote? quote;
  final Future<void> Function() onNext;
  final bool loading;

  const _Step4ReviewPricing({
    required this.draft,
    required this.quote,
    required this.onNext,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Review & Pricing',
                  style: PvTypography.headline.copyWith(color: PvColors.onBackground)),
              const SizedBox(height: 16),

              // Submission summary
              if (draft != null) ...[
                _ReviewRow('Asset', draft!.assetName),
                _ReviewRow('Type', draft!.assetType),
                _ReviewRow('Requested Service', draft!.selectedTier?.displayName ?? '—'),
                const Divider(color: PvColors.border, height: 24),
              ],

              // Quote
              if (quote != null) ...[
                _ReviewRow('Service', quote!.serviceDescription),
                _ReviewRow(
                  'Price',
                  '${quote!.currency} ${quote!.price.toStringAsFixed(2)}',
                  valueStyle: PvTypography.title.copyWith(color: PvColors.onBackground),
                ),
                _ReviewRow(
                  'Estimated Turnaround',
                  '${quote!.turnaroundDays} business days',
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PvColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PvColors.border),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PvColors.cyan)),
                      SizedBox(width: 12),
                      Text('Loading quote…', style: PvTypography.body),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PvColors.surface,
                  border: Border.all(color: PvColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Payment is required to begin processing your submission. '
                  'Payment is not a factor in the trust determination — '
                  'all determinations are made solely by the review team based on evidence.',
                  style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                ),
              ),
            ],
          ),
        ),
        _BottomBar(
          onNext: quote != null ? onNext : null,
          nextLabel: 'Proceed to Payment',
          loading: loading,
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _ReviewRow(this.label, this.value, {this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: PvTypography.bodySmall.copyWith(color: PvColors.muted)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: valueStyle ?? PvTypography.body.copyWith(color: PvColors.onBackground),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 5 — Checkout
// ────────────────────────────────────────────────────────────────────────────

class _Step5Checkout extends StatelessWidget {
  final SubmissionDraft? draft;
  final Future<void> Function() onComplete;
  final bool loading;

  const _Step5Checkout({
    required this.draft,
    required this.onComplete,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final isQual = Env.isQualification || Env.isDevelopment;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Checkout',
                  style: PvTypography.headline.copyWith(color: PvColors.onBackground)),
              const SizedBox(height: 16),

              if (isQual) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PvColors.warning.withAlpha(20),
                    border: Border.all(color: PvColors.warning),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEST MODE — QUALIFICATION ENVIRONMENT',
                        style: PvTypography.label.copyWith(color: PvColors.warning),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No real payment will be processed. Tap "Test Payment" '
                        'to simulate a successful payment for testing purposes.',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PvColors.surface,
                    border: Border.all(color: PvColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.payment_outlined, color: PvColors.muted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Payment Gateway Placeholder',
                        style: PvTypography.title.copyWith(color: PvColors.silver),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Production: Stripe or approved payment gateway',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submission ID: ${draft?.submissionId ?? "—"}',
                        style: PvTypography.mono.copyWith(color: PvColors.muted),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PvColors.surface,
                    border: Border.all(color: PvColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.payment_outlined, color: PvColors.muted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Payment Gateway',
                        style: PvTypography.title.copyWith(color: PvColors.silver),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure payment processing via approved gateway.',
                        style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        _BottomBar(
          onNext: loading ? null : onComplete,
          nextLabel: isQual ? 'Test Payment (Simulated)' : 'Complete Payment',
          loading: loading,
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Step 6 — Confirmation
// ────────────────────────────────────────────────────────────────────────────

class _Step6Confirmation extends ConsumerWidget {
  final SubmissionDraft? draft;
  const _Step6Confirmation({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.check_circle, color: PvColors.success, size: 64),
        const SizedBox(height: 20),

        Text(
          'Submission Confirmed',
          style: PvTypography.headline.copyWith(color: PvColors.onBackground),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        if (draft?.submissionId != null) ...[
          Text(
            'Submission ID',
            style: PvTypography.label.copyWith(color: PvColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            draft!.submissionId!,
            style: PvTypography.mono.copyWith(color: PvColors.cyan, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PvColors.surface,
            border: Border.all(color: PvColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT STEPS',
                style: PvTypography.label.copyWith(color: PvColors.muted),
              ),
              const SizedBox(height: 12),
              _NextStep(
                icon: Icons.local_shipping_outlined,
                text: 'Await shipment instructions from our team (email within 1–2 business days).',
              ),
              const SizedBox(height: 10),
              _NextStep(
                icon: Icons.inventory_outlined,
                text: 'Ship your gemstone using the provided instructions. '
                    'Custody transfer will be recorded on receipt.',
              ),
              const SizedBox(height: 10),
              _NextStep(
                icon: Icons.track_changes_outlined,
                text: 'Track your submission status in the Activity tab.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ref.read(submitProvider.notifier).reset();
              context.go('/activity');
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View in Activity'),
            style: FilledButton.styleFrom(
              backgroundColor: PvColors.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(submitProvider.notifier).reset();
              context.go('/home');
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PvColors.onBackground,
              side: const BorderSide(color: PvColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _NextStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NextStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PvColors.silver, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: PvTypography.bodySmall.copyWith(color: PvColors.onSurface)),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ────────────────────────────────────────────────────────────────────────────

class _PvTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _PvTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: PvTypography.body.copyWith(color: PvColors.onBackground),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PvTypography.body.copyWith(color: PvColors.muted),
            filled: true,
            fillColor: PvColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: PvColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: PvColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: PvColors.cyan),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PvTypography.label.copyWith(color: PvColors.muted),
      );
}

class _BottomBar extends StatelessWidget {
  final Future<void> Function()? onNext;
  final String nextLabel;
  final bool loading;
  final String? skipLabel;
  final VoidCallback? onSkip;

  const _BottomBar({
    required this.onNext,
    required this.nextLabel,
    required this.loading,
    this.skipLabel,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: PvColors.background,
        border: Border(top: BorderSide(color: PvColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : (onNext != null ? () => onNext!() : null),
              style: FilledButton.styleFrom(
                backgroundColor: PvColors.cyan,
                foregroundColor: Colors.black,
                disabledBackgroundColor: PvColors.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(nextLabel),
            ),
          ),
          if (skipLabel != null && onSkip != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSkip,
              child: Text(
                skipLabel!,
                style: PvTypography.bodySmall.copyWith(color: PvColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
