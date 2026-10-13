import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/token_storage.dart';
import '../services/user_service.dart';

class AuthState {
  final bool isLoggedIn;
  final bool requiresBiometric;
  final String? userName;
  final String? userEmail;
  final String? userId;
  final String? role;
  final String? plan; // "FREE" | "BASIC" | "PRO"
  final DateTime? planExpiresAt; // null = không giới hạn (gói cũ / FREE)

  const AuthState({
    required this.isLoggedIn,
    this.requiresBiometric = false,
    this.userName,
    this.userEmail,
    this.userId,
    this.role,
    this.plan,
    this.planExpiresAt,
  });

  /// Gói còn hiệu lực (chưa hết hạn). NULL expiry = không giới hạn.
  bool get _planActive =>
      planExpiresAt == null || planExpiresAt!.isAfter(DateTime.now());

  /// Thành viên premium (đã mua BASIC hoặc PRO còn hạn) — mở khóa tải bản nhạc premium.
  bool get isPremium => (plan == 'BASIC' || plan == 'PRO') && _planActive;

  /// Gói PRO còn hạn — mở khóa thêm luyện tập AI Pitch.
  bool get isPro => plan == 'PRO' && _planActive;

  /// Gói thực tế sau khi tính hết hạn ("FREE" nếu đã hết hạn).
  String get effectivePlan => isPro ? 'PRO' : (isPremium ? 'BASIC' : 'FREE');

  /// Số ngày còn lại của gói (null nếu không giới hạn hoặc đã hết hạn).
  int? get daysRemaining {
    final exp = planExpiresAt;
    if (exp == null || !isPremium) return null;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays + 1;
  }

  AuthState copyWith({
    bool? isLoggedIn,
    bool? requiresBiometric,
    String? userName,
    String? userEmail,
    String? userId,
    String? role,
    String? plan,
    DateTime? planExpiresAt,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      requiresBiometric: requiresBiometric ?? this.requiresBiometric,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _keyUserName = 'folkify_user_name';
  static const _keyUserEmail = 'folkify_user_email';
  static const _keyUserId = 'folkify_user_id';
  static const _keyUserRole = 'folkify_user_role';
  static const _keyUserPlan = 'folkify_user_plan';
  static const _keyUserPlanExpires = 'folkify_user_plan_expires';
  static const _keyBiometricEnabled = 'folkify_biometric_enabled';

  @override
  AuthState build() {
    ApiClient.onSessionExpired = clearSession;
    // Luôn bắt đăng nhập lại: KHÔNG khôi phục phiên đã lưu khi mở app.
    // Sau splash, mọi người dùng đều được điều hướng về trang login.
    return const AuthState(isLoggedIn: false);
  }

  AuthState _buildLoggedInState(SharedPreferences prefs) => AuthState(
        isLoggedIn: true,
        userName: prefs.getString(_keyUserName),
        userEmail: prefs.getString(_keyUserEmail),
        userId: prefs.getString(_keyUserId),
        role: prefs.getString(_keyUserRole),
        plan: prefs.getString(_keyUserPlan) ?? 'FREE',
        planExpiresAt: parsePlanExpiry(prefs.getString(_keyUserPlanExpires)),
      );

  Future<bool> authenticateWithBiometric() async {
    final success = await BiometricService.authenticate();
    if (!success) return false;
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null) {
        final tokens = await AuthService.refreshAccessToken(refreshToken);
        await _persistUser(tokens);
        state = AuthState(
          isLoggedIn: true,
          userEmail: tokens.user.email,
          userName: tokens.user.name,
          userId: tokens.user.id,
          role: tokens.user.role,
          plan: tokens.user.plan,
          planExpiresAt: tokens.user.planExpiresAt,
        );
        return true;
      }
    } catch (_) {
      // Không có mạng hoặc refresh thất bại — dùng credentials đã lưu
    }
    final prefs = await SharedPreferences.getInstance();
    state = _buildLoggedInState(prefs);
    return true;
  }

  Future<void> skipBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    state = _buildLoggedInState(prefs);
  }

  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, true);
  }

  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, false);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<void> _persistUser(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      TokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
      prefs.setString(_keyUserName, tokens.user.name),
      prefs.setString(_keyUserEmail, tokens.user.email),
      prefs.setString(_keyUserId, tokens.user.id),
      prefs.setString(_keyUserRole, tokens.user.role),
      prefs.setString(_keyUserPlan, tokens.user.plan),
      prefs.setString(_keyUserPlanExpires, tokens.user.planExpiresAt?.toIso8601String() ?? ''),
    ]);
  }

  /// Đồng bộ lại gói từ backend (gọi sau khi thanh toán thành công / khi mở Profile).
  Future<void> refreshPlan() async {
    try {
      final profile = await UserService.getProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserPlan, profile.plan);
      await prefs.setString(
          _keyUserPlanExpires, profile.planExpiresAt?.toIso8601String() ?? '');
      state = state.copyWith(plan: profile.plan, planExpiresAt: profile.planExpiresAt);
    } catch (_) {
      // Lỗi mạng — giữ nguyên gói hiện tại.
    }
  }

  /// Hủy gói hiện tại — gọi backend rồi đưa state về FREE ngay (xóa hạn).
  Future<void> cancelPlan() async {
    await UserService.cancelPlan();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserPlan, 'FREE');
    await prefs.remove(_keyUserPlanExpires);
    state = AuthState(
      isLoggedIn: state.isLoggedIn,
      requiresBiometric: state.requiresBiometric,
      userName: state.userName,
      userEmail: state.userEmail,
      userId: state.userId,
      role: state.role,
      plan: 'FREE',
      planExpiresAt: null,
    );
  }

  /// Cập nhật gói ngay tại máy (dùng để phản hồi tức thì sau khi mua xong).
  /// Đặt hạn tạm bằng thời hạn mặc định; sau đó [refreshPlan] sẽ lấy hạn chính xác từ backend.
  Future<void> setPlanLocally(String plan) async {
    final expiry = DateTime.now().add(const Duration(days: 30));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserPlan, plan);
    await prefs.setString(_keyUserPlanExpires, expiry.toIso8601String());
    state = state.copyWith(plan: plan, planExpiresAt: expiry);
  }

  Future<void> login(String email, String password) async {
    final tokens = await AuthService.login(email, password);
    await _persistUser(tokens);
    state = AuthState(
      isLoggedIn: true,
      userEmail: tokens.user.email,
      userName: tokens.user.name,
      userId: tokens.user.id,
      role: tokens.user.role,
      plan: tokens.user.plan,
      planExpiresAt: tokens.user.planExpiresAt,
    );
  }

  Future<void> register(String name, String email, String password) async {
    final tokens = await AuthService.register(name, email, password);
    await _persistUser(tokens);
    state = AuthState(
      isLoggedIn: true,
      userEmail: tokens.user.email,
      userName: tokens.user.name,
      userId: tokens.user.id,
      role: tokens.user.role,
      plan: tokens.user.plan,
      planExpiresAt: tokens.user.planExpiresAt,
    );
  }

  Future<bool> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: '711076732273-571552lb6kbbe8upf1oj2q6u66roai9o.apps.googleusercontent.com',
    );
    final account = await googleSignIn.signIn();
    if (account == null) return false;

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw AuthException('Không lấy được Google token');

    final tokens = await AuthService.loginWithGoogle(idToken);
    await _persistUser(tokens);
    state = AuthState(
      isLoggedIn: true,
      userEmail: tokens.user.email,
      userName: tokens.user.name,
      userId: tokens.user.id,
      role: tokens.user.role,
      plan: tokens.user.plan,
      planExpiresAt: tokens.user.planExpiresAt,
    );
    return true;
  }

  Future<bool> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final identityToken = credential.identityToken;
    if (identityToken == null) throw AuthException('Không lấy được Apple token');

    final givenName = credential.givenName;
    final familyName = credential.familyName;
    final fullName = [givenName, familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    final tokens = await AuthService.loginWithApple(
      identityToken,
      fullName: fullName.isEmpty ? null : fullName,
    );
    await _persistUser(tokens);
    state = AuthState(
      isLoggedIn: true,
      userEmail: tokens.user.email,
      userName: tokens.user.name,
      userId: tokens.user.id,
      role: tokens.user.role,
      plan: tokens.user.plan,
      planExpiresAt: tokens.user.planExpiresAt,
    );
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;

    if (biometricEnabled) {
      // Giữ refresh token để dùng biometric re-login
      await TokenStorage.clearAccessToken();
    } else {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await AuthService.logout(refreshToken);
      }
      await TokenStorage.clearTokens();
    }

    await Future.wait([
      prefs.remove(_keyUserName),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserRole),
      prefs.remove(_keyUserPlan),
      prefs.remove(_keyUserPlanExpires),
    ]);
    state = const AuthState(isLoggedIn: false);
  }

  Future<void> updateUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    state = state.copyWith(userName: name);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await TokenStorage.clearTokens();
    await Future.wait([
      prefs.remove(_keyUserName),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserRole),
      prefs.remove(_keyUserPlan),
      prefs.remove(_keyUserPlanExpires),
    ]);
    state = const AuthState(isLoggedIn: false);
  }

  Future<bool> biometricRelogin() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    final success = await BiometricService.authenticate();
    if (!success) return false;
    try {
      final tokens = await AuthService.refreshAccessToken(refreshToken);
      await _persistUser(tokens);
      state = AuthState(
        isLoggedIn: true,
        userEmail: tokens.user.email,
        userName: tokens.user.name,
        userId: tokens.user.id,
        role: tokens.user.role,
        plan: tokens.user.plan,
        planExpiresAt: tokens.user.planExpiresAt,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
