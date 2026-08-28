import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provenance_verified_app/trust/widgets/trust_badge.dart';
import 'package:provenance_verified_app/trust/trust_models.dart';

TrustRecord _makeRecord({
  bool eligible = true,
  QualificationState qualState = QualificationState.qualified,
  int tier = 1,
  bool conflict = false,
  ContinuityState continuityState = ContinuityState.known,
}) {
  return TrustRecord(
    publicId: 'PV-TEST-WIDGET-001',
    trustStateDigest: 'sha256:${'a' * 64}',
    subject: TrustSubject(
      subjectId: 'test-subject',
      physicalSubjectId: 'TEST-001',
      continuityState: continuityState,
    ),
    determination: TrustDetermination(
      determinationId: 'det-001',
      tier: tier,
      eligible: eligible,
      qualificationState: qualState,
      materialConflict: conflict,
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TrustBadge — UNQUALIFIED_T1_OVERCLAIM = ZERO', () {
    testWidgets('UNQUALIFIED record shows NOT QUALIFIED, not T1', (tester) async {
      final record = _makeRecord(
        eligible: false,
        qualState: QualificationState.unqualified,
        tier: 1,
      );
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('NOT QUALIFIED'), findsOneWidget);
      expect(find.textContaining('T1'), findsNothing);
      expect(find.textContaining('FINGERPRINT'), findsNothing);
    });

    testWidgets('UNQUALIFIED with tier=2 in determination still shows NOT QUALIFIED', (tester) async {
      final record = _makeRecord(
        eligible: true,
        qualState: QualificationState.unqualified,
        tier: 2,
      );
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('NOT QUALIFIED'), findsOneWidget);
      expect(find.textContaining('T2'), findsNothing);
    });

    testWidgets('eligible=false shows NOT QUALIFIED regardless of tier', (tester) async {
      final record = _makeRecord(eligible: false, tier: 3);
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('NOT QUALIFIED'), findsOneWidget);
    });

    testWidgets('T1 qualified shows T1 label', (tester) async {
      final record = _makeRecord(eligible: true, qualState: QualificationState.qualified, tier: 1);
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('T1 ASSET FINGERPRINT'), findsOneWidget);
    });

    testWidgets('T4 Gold shows correct label', (tester) async {
      final record = _makeRecord(eligible: true, qualState: QualificationState.qualified, tier: 4);
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('T4 GOLD STANDARD'), findsOneWidget);
    });

    testWidgets('record with material conflict shows MATERIAL CONFLICT indicator', (tester) async {
      final record = _makeRecord(eligible: true, qualState: QualificationState.qualified, tier: 2, conflict: true);
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('MATERIAL CONFLICT'), findsOneWidget);
    });

    testWidgets('record with custody gap shows CUSTODY GAP indicator', (tester) async {
      final record = _makeRecord(
        eligible: true,
        qualState: QualificationState.qualified,
        tier: 3,
        continuityState: ContinuityState.gap,
      );
      await tester.pumpWidget(_wrap(TrustBadge(record: record)));

      expect(find.text('CUSTODY GAP'), findsOneWidget);
    });

    testWidgets('all 8 stone records produce non-overclaiming labels', (tester) async {
      // Stone-6 is the UNQUALIFIED record — must show NOT QUALIFIED
      final stone6 = TrustRecord(
        publicId: 'PV-TEST-S6-001',
        trustStateDigest: 'sha256:${'0' * 64}',
        subject: TrustSubject(
          subjectId: 'wrong-subject',
          physicalSubjectId: 'AMBIGUOUS-001',
          identityState: IdentityState.ambiguous,
        ),
        determination: TrustDetermination(
          determinationId: 'det-s6',
          tier: 1,
          eligible: false,
          qualificationState: QualificationState.unqualified,
        ),
        prohibitedInferences: const ['NOT_UNIQUELY_IDENTIFIED'],
      );
      await tester.pumpWidget(_wrap(TrustBadge(record: stone6)));

      // Must show NOT QUALIFIED — never T1 for UNQUALIFIED
      expect(find.text('NOT QUALIFIED'), findsOneWidget);
      expect(find.textContaining('T1'), findsNothing);
      expect(find.textContaining('FINGERPRINT'), findsNothing);
    });
  });
}
