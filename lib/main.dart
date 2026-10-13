import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_orientations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_toast.dart';
import 'core/providers/progress_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setPreferredOrientations(appOrientations);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: FolkifyApp()));
}

class FolkifyApp extends ConsumerStatefulWidget {
  const FolkifyApp({super.key});

  @override
  ConsumerState<FolkifyApp> createState() => _FolkifyAppState();
}

class _FolkifyAppState extends ConsumerState<FolkifyApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgrounded = _backgroundedAt;
      if (backgrounded != null &&
          DateTime.now().difference(backgrounded).inMinutes >= 5) {
        // Invalidate tất cả data providers để fetch lại
        ref.invalidate(userProgressProvider);
        ref.invalidate(achievementsProvider);
        ref.invalidate(weeklyActivityProvider);
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Folkify',
      theme: AppTheme.dark,
      routerConfig: router,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
