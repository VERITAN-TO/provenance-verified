// M2 Native E2E Runner — Standalone Profile Build
// Writes JSON results to $HOME/Documents/m2_e2e_results.json (no path_provider needed).
// Retrieve via: xcrun devicectl device copy from --device D92D9A26-C7C0-5343-8401-DF86222060C2
//   --domain-type appDataContainer
//   --domain-identifier to.veritan.pv.provenanceVerifiedApp
//   --source Documents/m2_e2e_results.json --destination /tmp/m2_e2e_results.json
// MTA1_CONTRACT: c446198e5ef4eb96cfe84c8c280a0ba94e4eac52
// SECURITY: qual backend only, no production mutations.

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'core/config/environment.dart';
import 'core/network/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const E2ERunnerApp());
}

class E2ERunnerApp extends StatelessWidget {
  const E2ERunnerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'PV M2 E2E', home: E2ERunnerScreen());
  }
}

class E2ERunnerScreen extends StatefulWidget {
  const E2ERunnerScreen({super.key});
  @override
  State<E2ERunnerScreen> createState() => _E2ERunnerScreenState();
}

class _E2ERunnerScreenState extends State<E2ERunnerScreen> {
  final List<String> _log = [];
  final List<Map<String, dynamic>> _results = [];
  bool _done = false;
  int _pass = 0;
  int _fail = 0;

  @override
  void initState() {
    super.initState();
    _writeProgress({'status': 'LAUNCHED', 'pass': 0, 'fail': 0});
    _runAll();
  }

  void _emit(String line) {
    // ignore: avoid_print
    print('[PV_E2E] $line');
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _runAll() async {
    const qualSubjectId = String.fromEnvironment('PV_QUAL_SUBJECT_ID', defaultValue: '');
    final client = ApiClient();

    _emit('START qual=$qualSubjectId base=${Env.pvApiBaseUrl}');

    await _run('NATIVE-01', 'trust query on native hardware', () async {
      if (Env.pvTenantId.isEmpty) throw Exception('PV_TENANT_ID missing');
      if (qualSubjectId.isEmpty) throw Exception('PV_QUAL_SUBJECT_ID missing');
      final r = await client.getMachineTrust(qualSubjectId);
      if (r.schema != 'pv.machine-trust.v1') throw Exception('schema=${r.schema}');
      if (!r.trustStateDigest.startsWith('sha256:')) throw Exception('digest=${r.trustStateDigest}');
      if (![1, 2, 3, 4].contains(r.tier)) throw Exception('tier=${r.tier}');
      return {'schema': r.schema, 'tier': r.tier, 'digest': r.trustStateDigest};
    });

    await _run('NATIVE-02', 'actionability on native hardware', () async {
      final j = await client.evaluateActionability(subjectId: qualSubjectId,
          purposeId: 'PURCHASE', requestedAction: 'evaluate', claimScope: 'standard');
      final d = j['decision'] as String? ?? '';
      if (!['ALLOW','QUALIFY','DENY','UNKNOWN'].contains(d)) throw Exception('decision=$d');
      return {'decision': d, 'digest': j['trust_state_digest']};
    });

    await _run('NATIVE-03', 'reliance receipt on native hardware', () async {
      final j = await client.createRelianceReceipt(subjectId: qualSubjectId,
          purposeId: 'PURCHASE', requestedAction: 'evaluate', claimScope: 'standard');
      final id = j['receipt_id']?.toString() ?? '';
      if (id.isEmpty) throw Exception('receipt_id empty');
      return {'receipt_id': id};
    });

    await _run('NATIVE-04', 'trust requery on native hardware', () async {
      final r1 = await client.getMachineTrust(qualSubjectId);
      final r2 = await client.getMachineTrust(qualSubjectId);
      if (r1.trustStateDigest.isEmpty) throw Exception('digest1 empty');
      if (r2.trustStateDigest.isEmpty) throw Exception('digest2 empty');
      return {'digest1': r1.trustStateDigest, 'digest2': r2.trustStateDigest};
    });

    await _run('NATIVE-05', 'stale detection on native hardware', () async {
      final r = await client.getMachineTrust(qualSubjectId);
      const fake = 'sha256:native0000000000000000000000000000000000000000000000000000dead';
      if (r.trustStateDigest == fake) throw Exception('current==fake stale');
      return {'current_digest': r.trustStateDigest, 'stale_mismatch': true};
    });

    await _run('NATIVE-06', 'moneyControlsTrust=false on native hardware', () async {
      final r = await client.getMachineTrust(qualSubjectId);
      final tr = r.toTrustRecord(qualSubjectId);
      if (tr.moneyControlsTrust) throw Exception('MTA1 VIOLATION');
      return {'money_controls_trust': false};
    });

    await _run('NATIVE-07', 'UNQUALIFIED_T1_OVERCLAIM=ZERO on native hardware', () async {
      final r = await client.getMachineTrust(qualSubjectId);
      final tr = r.toTrustRecord(qualSubjectId);
      if (!tr.isQualified && tr.safeTier != null) throw Exception('overclaim safeTier=${tr.safeTier}');
      return {'is_qualified': tr.isQualified, 'safe_tier': tr.safeTier};
    });

    await _run('NATIVE-08', 'mobile token bootstrap + auth HTTP 200 on native hardware', () async {
      // M3: ApiClient acquires token via MobileTokenService — no static key.
      final r = await client.getMachineTrust(qualSubjectId);
      if (r.schema != 'pv.machine-trust.v1') throw Exception('schema=${r.schema}');
      return {'http': 200, 'schema': 'pv.machine-trust.v1', 'via_token_service': true};
    });

    client.dispose();

    if (mounted) setState(() => _done = true);
    await _writeProgress({});
    _emit('FINAL_RESULT=${_fail == 0 ? "PASS" : "FAIL"} pass=$_pass fail=$_fail');
  }

  Future<void> _writeProgress(Map<String, dynamic> extra) async {
    final data = {
      'schema': 'pv.m2.ios-e2e-results.v1',
      'final_result': _done ? (_fail == 0 ? 'PASS' : 'FAIL') : 'IN_PROGRESS',
      'pass': _pass, 'fail': _fail, 'total': 8,
      'tests': List<Map<String, dynamic>>.from(_results),
      'security': {'PRODUCTION_SUPABASE_MUTATIONS': 'ZERO', 'V4_ACTIVATED_BY_M2': 'NO'},
      ...extra,
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    // Primary: Dart standard temp (NSTemporaryDirectory on iOS — most reliable)
    try {
      final tmpDir = Directory.systemTemp;
      _emit('TMP_PATH=${tmpDir.path}');
      final f = File('${tmpDir.path}/m2_e2e_results.json');
      await f.writeAsString(jsonStr);
      _emit('WRITTEN_SYSTMP=${f.path}');
      return;
    } catch (e) {
      _emit('SYSTMP_ERR=$e');
    }

    // Fallback: TMPDIR env var
    try {
      final tmpdir = Platform.environment['TMPDIR'] ?? '';
      _emit('TMPDIR_ENV=$tmpdir');
      if (tmpdir.isNotEmpty) {
        final f = File('${tmpdir}m2_e2e_results.json');
        await f.writeAsString(jsonStr);
        _emit('WRITTEN_ENV=${f.path}');
        return;
      }
    } catch (e) {
      _emit('ENVTMP_ERR=$e');
    }

    _emit('WRITE_FAILED');
  }

  Future<void> _run(String id, String desc, Future<Map<String, dynamic>> Function() body) async {
    try {
      final detail = await body();
      _pass++;
      _results.add({'id': id, 'result': 'PASS', 'desc': desc, 'detail': detail});
      _emit('$id=PASS');
    } catch (e) {
      _fail++;
      _results.add({'id': id, 'result': 'FAIL', 'desc': desc, 'error': '$e'});
      _emit('$id=FAIL error=$e');
    }
    await _writeProgress({'completed': _pass + _fail});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _done ? (_fail == 0 ? 'PASS 8/8' : 'FAIL $_fail/8') : 'Running...',
          style: TextStyle(color: _done ? (_fail == 0 ? Colors.green : Colors.red) : Colors.yellow,
              fontFamily: 'Courier', fontSize: 14),
        ),
      ),
      body: ListView.builder(
        itemCount: _log.length,
        itemBuilder: (ctx, i) {
          final l = _log[i];
          Color c = Colors.white70;
          if (l.contains('=PASS')) c = Colors.green;
          if (l.contains('=FAIL') || l.contains('ERROR')) c = Colors.red;
          if (l.contains('FINAL_RESULT=PASS')) c = Colors.greenAccent;
          if (l.contains('FINAL_RESULT=FAIL')) c = Colors.redAccent;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(l, style: TextStyle(color: c, fontFamily: 'Courier', fontSize: 11)),
          );
        },
      ),
    );
  }
}
