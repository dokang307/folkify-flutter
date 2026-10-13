import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/gradient_button.dart';

// ⚠️ Thanh toán qua Apple IAP đã được TẮT — chỉ dùng Pay2S (chuyển khoản/QR).
// Toàn bộ code IAP cũ còn ở lib/core/providers/iap_provider.dart (không bị xóa),
// và bản màn hình dùng IAP còn trong lịch sử git nếu cần bật lại.

// Giá phải khớp với backend (PAY2S_PRICE_BASIC / PAY2S_PRICE_PRO).
const _kBasicPrice = '49.000đ';
const _kProPrice = '99.000đ';

class PremiumPlansScreen extends ConsumerStatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  ConsumerState<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends ConsumerState<PremiumPlansScreen> {
  String _selectedPlan = 'PRO'; // 'BASIC' | 'PRO'

  // Thanh toán qua PayOS (chuyển khoản / QR).
  void _payWithPay2s() {
    context.push('/premium/pay2s?plan=$_selectedPlan');
  }

  /// Xác nhận rồi hủy gói hiện tại — tài khoản về Free ngay.
  Future<void> _confirmCancelPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Hủy gói?', style: AppTextStyles.headlineMedium),
        content: Text(
          'Tài khoản sẽ trở về Free ngay lập tức và bạn mất quyền dùng các tính năng premium. '
          'Số ngày còn lại sẽ không được hoàn tiền.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Giữ gói', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hủy gói', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authStateProvider.notifier).cancelPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy gói. Tài khoản của bạn trở về Free.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = _selectedPlan == 'PRO';
    final auth = ref.watch(authStateProvider);
    final currentPlan = auth.effectivePlan;
    final daysRemaining = auth.daysRemaining;
    final alreadyOnSelected = _selectedPlan == currentPlan;
    final price = isPro ? _kProPrice : _kBasicPrice;
    final buttonText = alreadyOnSelected
        ? 'Gia hạn gói ${isPro ? 'Pro' : 'Basic'} — $price'
        : 'Thanh toán gói ${isPro ? 'Pro' : 'Basic'} — $price';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Nâng cấp tài khoản', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            if (currentPlan != 'FREE') ...[
              const SizedBox(height: 16),
              _buildCurrentPlanBanner(currentPlan, daysRemaining),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _confirmCancelPlan,
                  icon: FaIcon(FontAwesomeIcons.ban, size: 12, color: AppColors.textMuted),
                  label: Text('Hủy gói ngay',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildPlans(currentPlan),
            const SizedBox(height: 28),
            _buildFeatureList(),
            const SizedBox(height: 32),
            GradientButton(
              text: buttonText,
              onPressed: _payWithPay2s,
              icon: FontAwesomeIcons.crown,
            ),
            const SizedBox(height: 12),
            Text(
              'Thanh toán một lần qua chuyển khoản ngân hàng / quét mã QR (Pay2S). '
              'Gói được kích hoạt ngay sau khi hệ thống ghi nhận thanh toán.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://folkify-landingpage.vercel.app/privacy'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    'Chính sách bảo mật',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  '  •  ',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://folkify-landingpage.vercel.app/terms'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    'Điều khoản sử dụng',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        FaIcon(FontAwesomeIcons.crown, color: const Color(0xFFF59E0B), size: 56),
        const SizedBox(height: 16),
        Text('Mở khóa toàn bộ\nnội dung Folkify',
            style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Học không giới hạn với hàng trăm bài học và bản nhạc',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCurrentPlanBanner(String currentPlan, int? daysRemaining) {
    final label = currentPlan == 'PRO' ? 'Pro' : 'Basic';
    final color = currentPlan == 'PRO' ? AppColors.planPro : AppColors.planBasic;
    final suffix = daysRemaining != null ? ' · còn $daysRemaining ngày' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.solidCircleCheck, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bạn đang là thành viên gói $label$suffix',
              style: AppTextStyles.titleMedium.copyWith(color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlans(String currentPlan) {
    return Column(
      children: [
        _PlanCard(
          title: 'Basic',
          price: _kBasicPrice,
          features: const ['Tất cả bài học cơ bản', '50+ bản nhạc', 'Luyện tập không giới hạn'],
          color: AppColors.planBasic,
          isSelected: _selectedPlan == 'BASIC',
          isCurrent: currentPlan == 'BASIC',
          onTap: () => setState(() => _selectedPlan = 'BASIC'),
        ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Pro',
          price: _kProPrice,
          features: const [
            'Tất cả bài học & bản nhạc',
            'Luyện tập AI Pitch',
            'Máy lên dây thông minh',
            'Tải bản nhạc offline',
            'Hỗ trợ ưu tiên 24/7',
          ],
          color: AppColors.planPro,
          isSelected: _selectedPlan == 'PRO',
          isCurrent: currentPlan == 'PRO',
          onTap: () => setState(() => _selectedPlan = 'PRO'),
          isBest: true,
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    final features = [
      (FontAwesomeIcons.book, 'Học không giới hạn', '100+ bài học từ cơ bản đến nâng cao'),
      (FontAwesomeIcons.listUl, 'Kho bản nhạc phong phú', '200+ bản nhạc dân tộc Việt Nam'),
      (FontAwesomeIcons.download, 'Học offline', 'Tải nội dung để học mà không cần mạng'),
      (FontAwesomeIcons.arrowTrendUp, 'Theo dõi tiến trình', 'Thống kê chi tiết hành trình học tập'),
    ];

    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: FaIcon(f.$1, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.$2, style: AppTextStyles.titleMedium),
                  Text(f.$3, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final bool isSelected;
  final bool isBest;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isBest = false,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTextStyles.headlineMedium.copyWith(color: color)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ĐANG DÙNG',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PHỔ BIẾN',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(price, style: AppTextStyles.headlineLarge.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 14),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleCheck, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(f, style: AppTextStyles.bodyMedium),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
