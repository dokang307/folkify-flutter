import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'gradient_button.dart';

const _planLabel = {'FREE': 'Miễn phí', 'BASIC': 'Basic', 'PRO': 'Premium'};

String planLabel(String plan) => _planLabel[plan] ?? plan;

Color _planColor(String plan) => switch (plan) {
      'PRO' => AppColors.planPro,
      'BASIC' => AppColors.planBasic,
      _ => AppColors.planFree,
    };

/// Nhãn "🔒 Gói X" cho nội dung bị khóa theo gói.
class PlanLockBadge extends StatelessWidget {
  final String plan;
  const PlanLockBadge({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final color = _planColor(plan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.lock, size: 10, color: color),
          const SizedBox(width: 4),
          Text(planLabel(plan), style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Paywall dạng bottom sheet — luôn có lối đi tiếp (xem gói), không bao giờ là ngõ cụt.
Future<void> showUpgradeSheet(BuildContext context, {String requiredPlan = 'BASIC', String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: _planColor(requiredPlan).withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: FaIcon(FontAwesomeIcons.crown, color: _planColor(requiredPlan), size: 26),
            ),
            const SizedBox(height: 16),
            Text('Mở khóa với gói ${planLabel(requiredPlan)}', style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              reason ?? 'Nội dung này cần gói ${planLabel(requiredPlan)} trở lên để truy cập.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Xem các gói',
              icon: FontAwesomeIcons.arrowRight,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.go('/premium');
              },
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Để sau')),
          ],
        ),
      ),
    ),
  );
}
