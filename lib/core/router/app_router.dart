import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/biometric_lock_screen.dart';
import '../../features/auth/presentation/screens/register_success_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/learn/presentation/screens/learn_screen.dart';
import '../../features/learn/presentation/screens/instrument_detail_screen.dart';
import '../../features/learn/presentation/screens/lesson_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_screen.dart';
import '../../features/sheets/presentation/screens/sheet_music_screen.dart';
import '../../features/premium/presentation/screens/premium_plans_screen.dart';
import '../../features/premium/presentation/screens/pay2s_checkout_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/change_password_screen.dart';
import '../../features/learn/presentation/screens/quiz_screen.dart';
import '../../features/scoring/presentation/scoring_screen.dart';
import '../widgets/main_shell.dart';
import '../providers/auth_provider.dart';

// Bridges Riverpod auth state → GoRouter refreshListenable
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    });
  }
  final Ref _ref;

  bool get isLoggedIn => _ref.read(authStateProvider).isLoggedIn;
  bool get requiresBiometric => _ref.read(authStateProvider).requiresBiometric;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final requiresBiometric = notifier.requiresBiometric;
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/reset-password';
      final isBiometricLock = loc == '/biometric-lock';

      if (isSplash) return null;
      if (requiresBiometric && !isBiometricLock) return '/biometric-lock';
      if (!isLoggedIn && !requiresBiometric && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      if (isLoggedIn && isBiometricLock) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(path: '/register-success', builder: (_, _) => const RegisterSuccessScreen()),
      GoRoute(path: '/biometric-lock', builder: (_, _) => const BiometricLockScreen()),
      // Trang thanh toán Pay2S — full màn hình, KHÔNG có navbar (ngoài ShellRoute).
      GoRoute(
        path: '/premium/pay2s',
        builder: (_, s) => Pay2sCheckoutScreen(
          plan: (s.uri.queryParameters['plan'] ?? 'PRO').toUpperCase(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const HomeScreen())),
          GoRoute(path: '/learn', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const LearnScreen())),
          GoRoute(
            path: '/learn/:id',
            pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: InstrumentDetailScreen(
              instrumentId: s.pathParameters['id']!,
            )),
          ),
          GoRoute(
            path: '/learn/:id/lesson/:lessonId',
            pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: LessonDetailScreen(
              instrumentId: s.pathParameters['id']!,
              lessonId: s.pathParameters['lessonId']!,
            )),
          ),
          GoRoute(
            path: '/learn/:id/lesson/:lessonId/quiz',
            builder: (_, s) => QuizScreen(
              instrumentId: s.pathParameters['id']!,
              lessonId: s.pathParameters['lessonId']!,
            ),
          ),
          GoRoute(path: '/practice', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const PracticeScreen())),
          GoRoute(
            path: '/practice/ai',
            builder: (_, s) => ScoringScreen(initialInstrument: s.uri.queryParameters['instrument']),
          ),
          GoRoute(path: '/sheets', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const SheetMusicScreen())),
          GoRoute(path: '/premium', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const PremiumPlansScreen())),
          GoRoute(path: '/profile', pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const ProfileScreen())),
          GoRoute(path: '/change-password', builder: (_, _) => const ChangePasswordScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Không tìm thấy trang: ${state.error}'),
      ),
    ),
  );
});
