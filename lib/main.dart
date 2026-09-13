import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'design/pv_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Auth state is managed via FlutterSecureStorage ('pv_customer_session').
  // Supabase client integration is deferred — do NOT call Supabase.initialize()
  // until supabase_flutter is added to pubspec.yaml.
  runApp(const ProviderScope(child: PvApp()));
}

class PvApp extends StatelessWidget {
  const PvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PROVENANCE VERIFIED™',
      theme: PvTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
