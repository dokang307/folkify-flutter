import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/instrument_provider.dart';
import '../../../../core/providers/progress_provider.dart';
import '../../../../core/services/api_error.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/services/quiz_service.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/upgrade_sheet.dart';

final _quizProvider = FutureProvider.autoDispose.family<Quiz, ({String instrument, String lesson})>(
  (ref, p) => QuizService.getQuiz(p.instrument, p.lesson),
);

class QuizScreen extends ConsumerStatefulWidget {
  final String instrumentId;
  final String lessonId;

  const QuizScreen({super.key, required this.instrumentId, required this.lessonId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  final Map<String, List<String>> _answers = {};
  QuizResult? _result;
  bool _submitting = false;

  String get _lessonPath => '/learn/${widget.instrumentId}/lesson/${widget.lessonId}';

  void _toggle(QuizQuestion q, String optionId) {
    setState(() {
      final current = List<String>.from(_answers[q.id] ?? const []);
      if (!q.multi) {
        _answers[q.id] = [optionId];
      } else if (current.contains(optionId)) {
        _answers[q.id] = current..remove(optionId);
      } else {
        _answers[q.id] = current..add(optionId);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await QuizService.submit(widget.instrumentId, widget.lessonId, _answers);
      if (!mounted) return;
      setState(() => _result = result);
      if (result.xpEarned != null) {
        ref.invalidate(instrumentDetailProvider(widget.instrumentId));
        ref.invalidate(userProgressProvider);
        AppToast.success('Hoàn thành bài học! +${result.xpEarned} XP');
      }
    } on ApiError catch (e) {
      AppToast.error(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(_quizProvider((instrument: widget.instrumentId, lesson: widget.lessonId)));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.xmark, color: AppColors.textPrimary),
          onPressed: () => context.go(_lessonPath),
        ),
        title: Text('Câu hỏi ôn tập', style: AppTextStyles.titleMedium),
      ),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          error: err,
          onRetry: () => ref.invalidate(_quizProvider((instrument: widget.instrumentId, lesson: widget.lessonId))),
        ),
        data: (quiz) => _result != null ? _buildResult(quiz, _result!) : _buildQuestion(quiz),
      ),
    );
  }

  Widget _buildQuestion(Quiz quiz) {
    final q = quiz.questions[_index];
    final selected = _answers[q.id] ?? const [];
    final isLast = _index == quiz.questions.length - 1;
    final answeredAll = quiz.questions.every((x) => (_answers[x.id] ?? const []).isNotEmpty);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < quiz.questions.length; i++)
                  Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.primary
                            : (_answers[quiz.questions[i].id] ?? const []).isNotEmpty
                                ? AppColors.primary.withValues(alpha: 0.45)
                                : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Câu ${_index + 1}/${quiz.questions.length} · ${q.multi ? 'Chọn tất cả đáp án đúng' : 'Chọn 1 đáp án'}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(q.question, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: q.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final o = q.options[i];
                  final on = selected.contains(o.id);
                  return Semantics(
                    selected: on,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggle(q, o.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 1.5 : 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: on ? AppColors.primary : Colors.transparent,
                                shape: q.multi ? BoxShape.rectangle : BoxShape.circle,
                                borderRadius: q.multi ? BorderRadius.circular(6) : null,
                                border: Border.all(color: on ? AppColors.primary : AppColors.textMuted),
                              ),
                              alignment: Alignment.center,
                              child: on
                                  ? const FaIcon(FontAwesomeIcons.check, size: 13, color: Colors.white)
                                  : Text(String.fromCharCode(65 + i), style: AppTextStyles.bodySmall),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(o.text, style: AppTextStyles.bodyLarge)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                if (_index > 0) ...[
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _index--), child: const Text('Câu trước'))),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    text: isLast ? 'Nộp bài' : 'Câu tiếp',
                    isLoading: _submitting,
                    onPressed: isLast
                        ? (answeredAll && !_submitting ? _submit : null)
                        : (selected.isEmpty ? null : () => setState(() => _index++)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Quiz quiz, QuizResult r) {
    final byId = {for (final x in r.results) x.questionId: x};
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (r.passed ? AppColors.success : AppColors.surfaceCard).withValues(alpha: r.passed ? 0.12 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              FaIcon(r.passed ? FontAwesomeIcons.trophy : FontAwesomeIcons.rotateLeft,
                  color: r.passed ? AppColors.warning : AppColors.textMuted, size: 36),
              const SizedBox(height: 12),
              Text('${r.scorePercent}%', style: AppTextStyles.displayMedium),
              Text(
                'Đúng ${r.correctCount}/${r.totalCount} câu · ${r.passed ? 'Bạn đã qua bài!' : 'Cần ${quiz.passPercent}% để hoàn thành bài'}',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (r.xpEarned != null) ...[
                const SizedBox(height: 6),
                Text('+${r.xpEarned} XP · Chuỗi ${r.currentStreak ?? 0} ngày',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 16),
              if (!r.passed)
                GradientButton(
                  text: 'Làm lại',
                  icon: FontAwesomeIcons.rotateLeft,
                  onPressed: () => setState(() {
                    _result = null;
                    _answers.clear();
                    _index = 0;
                  }),
                )
              else
                GradientButton(text: 'Về lộ trình', onPressed: () => context.go('/learn/${widget.instrumentId}')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final (i, q) in quiz.questions.indexed) ...[
          _ReviewCard(index: i, question: q, result: byId[q.id], chosen: _answers[q.id] ?? const []),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final QuestionResult? result;
  final List<String> chosen;

  const _ReviewCard({required this.index, required this.question, required this.result, required this.chosen});

  @override
  Widget build(BuildContext context) {
    final correctIds = result?.correctOptionIds ?? const [];
    final ok = result?.correct ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FaIcon(ok ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
                  color: ok ? AppColors.success : AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${index + 1}. ${question.question}', style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          for (final o in question.options)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Text(
                '${correctIds.contains(o.id) ? '✓' : chosen.contains(o.id) ? '✗' : '·'}  ${o.text}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: correctIds.contains(o.id)
                      ? AppColors.success
                      : chosen.contains(o.id)
                          ? AppColors.error
                          : AppColors.textSecondary,
                  fontWeight: correctIds.contains(o.id) ? FontWeight.w600 : null,
                ),
              ),
            ),
          if (result?.explanation != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: Text(result!.explanation!, style: AppTextStyles.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final apiError = error is ApiError ? error as ApiError : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiError?.message ?? 'Không tải được câu hỏi', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (apiError?.isPlanGate ?? false)
              GradientButton(text: 'Xem các gói', onPressed: () => showUpgradeSheet(context))
            else
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
