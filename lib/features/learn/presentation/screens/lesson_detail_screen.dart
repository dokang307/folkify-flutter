import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/instrument_provider.dart';
import '../../../../core/providers/progress_provider.dart';
import '../../../../core/services/api_error.dart';
import '../../../../core/services/progress_service.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/upgrade_sheet.dart';
import '../../domain/models/instrument.dart';
import '../widgets/lesson_video.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final String instrumentId;
  final String lessonId;

  const LessonDetailScreen({
    super.key,
    required this.instrumentId,
    required this.lessonId,
  });

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  int _currentStep = 0;
  bool _completed = false;
  CompleteLessonResult? _lessonResult;
  int _prevStreak = 0;

  Future<void> _finishLesson(Lesson lesson) async {
    _prevStreak = ref.read(userProgressProvider).valueOrNull?.currentStreak ?? 0;
    setState(() => _completed = true);
    if (lesson.uuid.isEmpty) return;
    try {
      final result = await ProgressService.completeLesson(lesson.uuid);
      if (mounted) setState(() => _lessonResult = result);
      ref.invalidate(userProgressProvider);
      ref.invalidate(achievementsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider((
      instrumentSlug: widget.instrumentId,
      lessonSlug: widget.lessonId,
    )));
    final instrumentName = ref
            .watch(instrumentDetailProvider(widget.instrumentId))
            .valueOrNull
            ?.name ??
        '';

    return lessonAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: FaIcon(FontAwesomeIcons.arrowLeft,
                color: AppColors.textPrimary),
            onPressed: () => context.go('/learn/${widget.instrumentId}'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: FaIcon(FontAwesomeIcons.arrowLeft,
                color: AppColors.textPrimary),
            onPressed: () => context.go('/learn/${widget.instrumentId}'),
          ),
        ),
        body: err is ApiError && err.isPlanGate
            ? _buildLockedView(context, err)
            : Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err is ApiError ? err.message : 'Không tải được bài học',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(lessonDetailProvider((
                  instrumentSlug: widget.instrumentId,
                  lessonSlug: widget.lessonId,
                ))),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (lesson) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/learn/${widget.instrumentId}');
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: FaIcon(FontAwesomeIcons.arrowLeft,
                  color: AppColors.textPrimary),
              onPressed: () => context.go('/learn/${widget.instrumentId}'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (instrumentName.isNotEmpty)
                  Text(instrumentName,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary)),
                Text(lesson.title,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('+${lesson.xp} XP',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          body: _completed
              ? _CompletionView(
                  lesson: lesson,
                  instrumentId: widget.instrumentId,
                  result: _lessonResult,
                  previousStreak: _prevStreak,
                )
              : _buildLessonView(context, lesson),
        ),
      ),
    );
  }

  Widget _buildLessonView(BuildContext context, Lesson lesson) {
    return Column(
      children: [
        if (lesson.steps.isNotEmpty) _buildProgressBar(lesson),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildVideoPlaceholder(lesson),
                const SizedBox(height: 24),
                _buildDescription(lesson),
                if (lesson.steps.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildStepsSection(lesson),
                ],
                if (lesson.tips.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildTipsSection(lesson),
                ],
                const SizedBox(height: 24),
                _buildQuizCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        _buildBottomActions(context, lesson),
      ],
    );
  }

  Widget _buildProgressBar(Lesson lesson) {
    final progress =
        ((_currentStep + 1) / lesson.steps.length).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bước ${_currentStep + 1}/${lesson.steps.length}',
                  style: AppTextStyles.bodySmall),
              Text('${(progress * 100).toInt()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceElevated,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView(BuildContext context, ApiError err) {
    final requiredPlan = ref
            .watch(instrumentDetailProvider(widget.instrumentId))
            .valueOrNull
            ?.lessons
            .where((l) => l.id == widget.lessonId)
            .firstOrNull
            ?.requiredPlan ??
        'BASIC';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.lock, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 16),
            Text(err.message, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Mở khóa bài học',
              icon: FontAwesomeIcons.crown,
              onPressed: () => showUpgradeSheet(context, requiredPlan: requiredPlan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/learn/${widget.instrumentId}/lesson/${widget.lessonId}/quiz'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.penToSquare, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Câu hỏi ôn tập', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text('Đạt từ 70% để hoàn thành bài và nhận XP', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            FaIcon(FontAwesomeIcons.chevronRight, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(Lesson lesson) {
    final videoId = LessonVideo.resolveId(lesson.youtubeVideoId, lesson.youtubeUrl);
    if (videoId != null) {
      return LessonVideo(videoId: videoId, channelName: lesson.channelName);
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.video, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 8),
            Text('Video sắp ra mắt', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(Lesson lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giới thiệu', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Text(lesson.description,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
      ],
    );
  }

  Widget _buildStepsSection(Lesson lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Các bước thực hiện', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        ...lesson.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;
          return GestureDetector(
            onTap: () => setState(() => _currentStep = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.primary
                              : AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isDone
                          ? FaIcon(FontAwesomeIcons.squareCheck,
                              color: Colors.white, size: 16)
                          : Text(
                              '${index + 1}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTipsSection(Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.lightbulb,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('Mẹo luyện tập',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 10),
          ...lesson.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.warning)),
                    Expanded(
                        child: Text(tip,
                            style: AppTextStyles.bodyMedium
                                .copyWith(height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Lesson lesson) {
    final stepCount = lesson.steps.length;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Trước'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: GradientButton(
              text: stepCount == 0 || _currentStep >= stepCount - 1
                  ? 'Hoàn thành!'
                  : 'Bước tiếp theo',
              onPressed: () {
                if (stepCount > 0 && _currentStep < stepCount - 1) {
                  setState(() => _currentStep++);
                } else {
                  _finishLesson(lesson);
                }
              },
              icon: stepCount == 0 || _currentStep >= stepCount - 1
                  ? FontAwesomeIcons.circleCheck
                  : FontAwesomeIcons.arrowRight,
            ),
          ),
        ],
      ),
    );
  }

}

// ─── Completion animation widget ────────────────────────────────────────────

class _Particle {
  final double x;
  final double startY;
  final double speed;
  final Color color;
  final double size;
  final double rotSpeed;
  final bool isCircle;

  const _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotSpeed,
    required this.isCircle,
  });
}

final _kParticles = List<_Particle>.generate(70, (i) {
  final rng = Random(i * 13 + 7);
  const colors = [
    Color(0xFFD97706),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];
  return _Particle(
    x: rng.nextDouble(),
    startY: -rng.nextDouble() * 0.25,
    speed: 0.55 + rng.nextDouble() * 0.75,
    color: colors[rng.nextInt(colors.length)],
    size: 5.0 + rng.nextDouble() * 8.0,
    rotSpeed: (rng.nextDouble() - 0.5) * 10,
    isCircle: rng.nextBool(),
  );
});

class _ConfettiPainter extends CustomPainter {
  final double progress;

  const _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _kParticles) {
      final rawY = p.startY + p.speed * progress;
      if (rawY > 1.05 || rawY < -0.05) continue;
      final x = p.x * size.width;
      final y = rawY * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: 0.9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotSpeed * progress);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _CompletionView extends StatefulWidget {
  final Lesson lesson;
  final String instrumentId;
  final CompleteLessonResult? result;
  final int previousStreak;

  const _CompletionView({
    required this.lesson,
    required this.instrumentId,
    required this.previousStreak,
    this.result,
  });

  @override
  State<_CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<_CompletionView>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _confetti;
  late final AnimationController _pulse;

  late final Animation<double> _trophyScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _xpFade;
  late final Animation<Offset> _xpSlide;
  late final Animation<double> _buttonsFade;
  late final Animation<int> _xpCount;
  late final Animation<double> _trophyPulse;

  bool _celebrationDone = false;

  @override
  void initState() {
    super.initState();


    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
      upperBound: 2.5,
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _trophyScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );

    _contentFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.38, 0.65, curve: Curves.easeOut),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.38, 0.65, curve: Curves.easeOut),
    ));

    _xpFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.78, curve: Curves.easeOut),
    );

    _xpSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.78, curve: Curves.easeOut),
    ));

    _buttonsFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
    );

    _xpCount = IntTween(begin: 0, end: widget.lesson.xp).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.52, 0.95, curve: Curves.easeOut),
      ),
    );

    _trophyPulse = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) _maybeTriggerCelebrations();
    });
  }

  @override
  void didUpdateWidget(_CompletionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result == null && widget.result != null) {
      _maybeTriggerCelebrations();
    }
  }

  void _maybeTriggerCelebrations() {
    if (_celebrationDone) return;
    if (!_entrance.isCompleted) return;
    if (widget.result == null) return;
    if (!mounted) return;
    _celebrationDone = true;
    _triggerCelebrations();
  }

  Future<void> _triggerCelebrations() async {
    final result = widget.result!;
    for (final ach in result.newAchievements) {
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (ctx, anim1, anim2) => CelebrationOverlay.achievement(ach),
      );
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 220));
    }
    const milestones = {3, 7, 14, 30, 60, 100};
    if (result.currentStreak > widget.previousStreak &&
        milestones.contains(result.currentStreak)) {
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (ctx, anim1, anim2) => CelebrationOverlay.streak(result.currentStreak),
      );
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _confetti.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _confetti,
          builder: (ctx, child) => CustomPaint(
            painter: _ConfettiPainter(_confetti.value),
            child: const SizedBox.expand(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_trophyScale, _trophyPulse]),
                  builder: (ctx, child) => Transform.scale(
                    scale: _trophyScale.value * _trophyPulse.value,
                    child: FaIcon(FontAwesomeIcons.trophy,
                        color: AppColors.primary, size: 80),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        Text('Bài học hoàn thành!',
                            style: AppTextStyles.displayMedium,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'Bạn vừa hoàn thành "${widget.lesson.title}"',
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _xpFade,
                  child: SlideTransition(
                    position: _xpSlide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.star,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              AnimatedBuilder(
                                animation: _xpCount,
                                builder: (ctx, child) => Text(
                                  '+${_xpCount.value}',
                                  style: AppTextStyles.displayMedium
                                      .copyWith(color: AppColors.primary),
                                ),
                              ),
                              Text('XP nhận được',
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _buttonsFade,
                  child: Column(
                    children: [
                      GradientButton(
                        text: 'Tiếp tục học',
                        onPressed: () =>
                            context.go('/learn/${widget.instrumentId}'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                        child: const Text('Về trang chủ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
