import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/instrument_provider.dart';
import '../../../core/services/api_error.dart';
import '../../../core/services/app_toast.dart';
import '../../../core/services/scoring_service.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/upgrade_sheet.dart';

// Khớp giới hạn của folkify_ai / backend
// Người học chơi một đoạn (≥ 5 giây) hoặc cả tác phẩm (≤ 6 phút)
const _minSeconds = 5;
const _maxSeconds = 360;
const _countdownSeconds = 3;
const _maxUploadBytes = 25 * 1024 * 1024;

final _quotaProvider = FutureProvider.autoDispose<AiQuota>(
  (ref) => ScoringService.getQuota(),
);
final _songsProvider = FutureProvider.autoDispose
    .family<List<ScoringSong>, String>(
      (ref, slug) => ScoringService.getSongs(slug),
    );

enum _Phase { idle, countdown, recording, review, submitting }

class ScoringScreen extends ConsumerStatefulWidget {
  final String? initialInstrument;
  const ScoringScreen({super.key, this.initialInstrument});

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;

  String? _instrument;
  ScoringSong? _song;
  _Phase _phase = _Phase.idle;
  int _count = _countdownSeconds;
  Duration _elapsed = Duration.zero;
  final List<double> _levels = [];
  String? _takePath;
  String? _error;
  PerformanceResult? _result;

  @override
  void initState() {
    super.initState();
    _instrument = widget.initialInstrument;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _deleteTempTake();
    super.dispose();
  }

  /// Xóa file ghi âm tạm do app tạo (không đụng file người dùng chọn từ máy).
  void _deleteTempTake() {
    final path = _takePath;
    if (path != null && path.contains('folkify_take_')) {
      File(path).delete().ignore();
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    if (!await _recorder.hasPermission()) {
      setState(
        () => _error =
            'Folkify cần quyền micro. Vào Cài đặt → Ứng dụng → Folkify → Quyền → Micro, hoặc tải file ghi âm lên.',
      );
      return;
    }
    setState(() {
      _phase = _Phase.countdown;
      _count = _countdownSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
        _beginRecording();
      } else {
        setState(() => _count--);
      }
    });
  }

  Future<void> _beginRecording() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/folkify_take_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // Tắt xử lý giọng nói: khử ồn/tự chỉnh âm lượng làm méo cao độ nhạc cụ
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 44100,
      ),
      path: path,
    );
    _levels.clear();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((a) {
          // dBFS (-60..0) → 0..1 cho vạch mức âm
          final level = ((a.current + 60) / 60).clamp(0.0, 1.0);
          setState(() {
            _levels.add(level);
            if (_levels.length > 60) _levels.removeAt(0);
          });
        });
    final started = DateTime.now();
    setState(() {
      _phase = _Phase.recording;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final e = DateTime.now().difference(started);
      setState(() => _elapsed = e);
      if (e.inSeconds >= _maxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    if (_elapsed.inSeconds < _minSeconds || path == null) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Bản ghi quá ngắn — hãy chơi ít nhất $_minSeconds giây.';
      });
      return;
    }
    setState(() {
      _takePath = path;
      _phase = _Phase.review;
    });
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(type: FileType.audio);
    final file = res?.files.single;
    if (file?.path == null) return;
    if (file!.size > _maxUploadBytes) {
      setState(
        () => _error =
            'File quá lớn (tối đa ${_maxUploadBytes ~/ 1024 ~/ 1024} MB).',
      );
      return;
    }
    setState(() {
      _error = null;
      _takePath = file.path;
      _elapsed = Duration.zero;
      _phase = _Phase.review;
    });
  }

  Future<void> _submit() async {
    final path = _takePath;
    if (path == null) return;
    setState(() => _phase = _Phase.submitting);
    try {
      final result = await ScoringService.submit(
        filePath: path,
        songId: _song!.id,
      );
      ref.invalidate(_quotaProvider);
      if (mounted) setState(() => _result = result);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.review);
      if (e.isPlanGate) {
        showUpgradeSheet(context, reason: e.message);
      } else {
        if (e.code == ApiError.aiQuotaExceeded) ref.invalidate(_quotaProvider);
        AppToast.error(e.message);
      }
    } catch (_) {
      // Lỗi ngoài dự kiến (file tạm bị xóa, phản hồi lạ...) — không để UI kẹt ở trạng thái "đang chấm"
      if (!mounted) return;
      setState(() => _phase = _Phase.review);
      AppToast.error('Không gửi được bản ghi, vui lòng thử lại.');
    }
  }

  void _reset() {
    _deleteTempTake();
    setState(() {
      _takePath = null;
      _result = null;
      _error = null;
      _phase = _Phase.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.arrowLeft,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.go('/practice'),
        ),
        title: Text('AI chấm điểm', style: AppTextStyles.titleMedium),
      ),
      body: _result != null
          ? _ResultView(result: _result!, onAgain: _reset)
          : _buildPractice(),
    );
  }

  Widget _buildPractice() {
    final quota = ref.watch(_quotaProvider);
    final instruments = ref.watch(instrumentListProvider);
    final slug = _instrument ?? instruments.valueOrNull?.firstOrNull?.id;
    final songs = slug == null ? null : ref.watch(_songsProvider(slug));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Chọn một tác phẩm, chơi một đoạn bất kỳ hoặc cả bài — AI tự nhận ra đoạn bạn chơi rồi chấm cao độ, nhịp và độ ổn định.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: instruments.valueOrNull?.length ?? 0,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final inst = instruments.value![i];
              final on = inst.id == slug;
              return ChoiceChip(
                label: Text(inst.name),
                selected: on,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                // labelStyle của chipTheme là màu chữ phụ — trên nền primary khi chọn sẽ chìm mất
                labelStyle: TextStyle(color: on ? Colors.white : AppColors.textSecondary),
                onSelected: _phase == _Phase.idle
                    ? (_) => setState(() {
                        _instrument = inst.id;
                        _song = null;
                      })
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Tác phẩm', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        if (songs?.isLoading ?? false)
          const Center(child: CircularProgressIndicator()),
        if (songs?.valueOrNull?.isEmpty ?? false)
          Text(
            'Nhạc cụ này chưa có tác phẩm nào.',
            style: AppTextStyles.bodySmall,
          ),
        for (final song in songs?.valueOrNull ?? const <ScoringSong>[]) ...[
          _TargetTile(
            title: song.title,
            subtitle: [
              song.artist,
              song.duration,
            ].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
            icon: FontAwesomeIcons.music,
            selected: _song?.id == song.id,
            enabled: song.locked || song.scoringReady,
            trailing: song.locked
                ? PlanLockBadge(plan: song.requiredPlan)
                : song.scoringReady
                ? null
                : Text('Chưa có bản mẫu', style: AppTextStyles.bodySmall),
            onTap: () {
              if (song.locked) {
                showUpgradeSheet(context, requiredPlan: song.requiredPlan);
              } else if (song.scoringReady && _phase == _Phase.idle) {
                setState(() => _song = song);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        if (_song == null)
          _Gate(
            icon: FontAwesomeIcons.music,
            title: 'Chọn một tác phẩm để bắt đầu',
            body: 'Bạn có thể thu âm một câu, một đoạn hoặc cả bài.',
            action: const SizedBox.shrink(),
          )
        else
          quota.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              e is ApiError ? e.message : 'Không tải được thông tin gói',
              style: AppTextStyles.bodyMedium,
            ),
            data: (q) {
              if (q.limit == 0) {
                return _Gate(
                  icon: FontAwesomeIcons.lock,
                  title: 'AI chấm điểm có trong gói Basic và Premium',
                  body:
                      'Nâng cấp để nhận điểm và nhận xét chi tiết cho từng lần luyện tập.',
                  action: GradientButton(
                    text: 'Xem các gói',
                    onPressed: () => context.go('/premium'),
                  ),
                );
              }
              if (q.remaining <= 0) {
                final d = q.resetsAt;
                return _Gate(
                  icon: FontAwesomeIcons.gaugeHigh,
                  title: 'Bạn đã dùng hết lượt chấm điểm tháng này',
                  body:
                      'Lượt mới vào ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}.',
                  action: OutlinedButton(
                    onPressed: () => context.go('/premium'),
                    child: const Text('Xem gói Premium'),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRecorderPanel(),
                  const SizedBox(height: 8),
                  Text(
                    'Còn ${q.remaining}/${q.limit} lượt trong tháng. Lỗi phân tích không bị trừ lượt.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecorderPanel() {
    final secs = _elapsed.inSeconds;
    final clock = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: switch (_phase) {
              _Phase.countdown => Center(
                child: Text(
                  '$_count',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              _Phase.recording => Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: _LevelPainter(_levels),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: secs / _maxSeconds,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  Text('$clock / 6:00', style: AppTextStyles.bodySmall),
                ],
              ),
              _Phase.review || _Phase.submitting => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.fileAudio,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      secs > 0
                          ? 'Bản ghi $clock'
                          : _takePath!.split(RegExp(r'[\\/]')).last,
                      style: AppTextStyles.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _Phase.idle => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.microphone,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đặt máy gần nhạc cụ, nơi yên tĩnh. Ghi từ $_minSeconds giây đến ${_maxSeconds ~/ 60} phút — một đoạn hoặc cả bài.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          switch (_phase) {
            _Phase.idle => Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Ghi âm',
                    icon: FontAwesomeIcons.microphone,
                    onPressed: _start,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const FaIcon(FontAwesomeIcons.upload, size: 14),
                    label: const Text('Tải file'),
                  ),
                ),
              ],
            ),
            _Phase.countdown => TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _phase = _Phase.idle);
              },
              child: const Text('Hủy'),
            ),
            _Phase.recording => GradientButton(
              text: secs < _minSeconds
                  ? 'Dừng (tối thiểu ${_minSeconds}s)'
                  : 'Dừng',
              icon: FontAwesomeIcons.stop,
              onPressed: _stop,
            ),
            _Phase.review || _Phase.submitting => Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    text: _phase == _Phase.submitting
                        ? 'Đang chấm…'
                        : 'Gửi AI chấm',
                    isLoading: _phase == _Phase.submitting,
                    icon: FontAwesomeIcons.paperPlane,
                    onPressed: _phase == _Phase.submitting ? null : _submit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _phase == _Phase.submitting ? null : _reset,
                    child: const Text('Làm lại'),
                  ),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final FaIconData icon;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool enabled;

  const _TargetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              FaIcon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String body;
  final Widget action;

  const _Gate({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: AppColors.textMuted, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  final List<double> levels;
  _LevelPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final step = size.width / 60;
    for (var i = 0; i < levels.length; i++) {
      final h = math.max(2.0, levels[i] * size.height);
      final x = size.width - (levels.length - i) * step + step / 2;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) => true;
}

class _ResultView extends StatelessWidget {
  final PerformanceResult result;
  final VoidCallback onAgain;
  const _ResultView({required this.result, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final headline = r.feedback.isNotEmpty
        ? r.feedback.first
        : 'Kết quả chấm điểm';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: r.overall / 100,
                  strokeWidth: 10,
                  backgroundColor: AppColors.surfaceElevated,
                  color: r.overall >= 90
                      ? AppColors.warning
                      : r.overall >= 50
                      ? AppColors.primary
                      : AppColors.error,
                ),
                Center(
                  child: Text(
                    '${r.overall}',
                    style: AppTextStyles.displayLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          headline,
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _bar('Cao độ', r.pitchScore),
        _bar('Nhịp', r.rhythmScore),
        _bar('Ổn định', r.stabilityScore),
        if (r.referenceDuration > 0) ...[
          const SizedBox(height: 8),
          Text('Đoạn đã chơi', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          _CoverageBar(result: r),
        ],
        if (r.chartTimes.length > 1) ...[
          const SizedBox(height: 16),
          Text('Đường cao độ', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _ContourPainter(r),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đường liền: bạn · Đường mờ: bản mẫu · Vùng đỏ: nốt lệch',
            style: AppTextStyles.bodySmall,
          ),
        ],
        if (r.feedback.length > 1) ...[
          const SizedBox(height: 20),
          Text('Nhận xét', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          for (final line in r.feedback.skip(1))
            Padding(
              padding: EdgeInsets.only(
                bottom: 8,
                left: line.startsWith('•') ? 16 : 0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  line.replaceFirst(RegExp(r'^•\s*'), ''),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        GradientButton(
          text: 'Luyện lại',
          icon: FontAwesomeIcons.microphone,
          onPressed: onAgain,
        ),
      ],
    );
  }

  Widget _bar(String label, int? score) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text(score?.toString() ?? '—', style: AppTextStyles.bodyMedium),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (score ?? 0) / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: AppColors.surfaceElevated,
          color: AppColors.primary,
        ),
      ],
    ),
  );
}

class _ContourPainter extends CustomPainter {
  final PerformanceResult r;
  _ContourPainter(this.r);

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = r.chartTimes.first;
    final t1 = r.chartTimes.last;
    final all = [...r.chartTarget, ...r.chartUser];
    final lo = all.reduce(math.min) - 1;
    final hi = all.reduce(math.max) + 1;
    double x(double t) => t1 == t0 ? 0 : (t - t0) / (t1 - t0) * size.width;
    double y(double m) => size.height - (m - lo) / (hi - lo) * size.height;

    final band = Paint()..color = AppColors.error.withValues(alpha: 0.15);
    for (final d in r.deviations) {
      canvas.drawRect(
        Rect.fromLTRB(x(d.start), 0, x(d.end), size.height),
        band,
      );
    }
    Path line(List<double> values) {
      final p = Path()..moveTo(x(r.chartTimes[0]), y(values[0]));
      for (var i = 1; i < values.length && i < r.chartTimes.length; i++) {
        p.lineTo(x(r.chartTimes[i]), y(values[i]));
      }
      return p;
    }

    canvas.drawPath(
      line(r.chartTarget),
      Paint()
        ..color = AppColors.textMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      line(r.chartUser),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ContourPainter old) => old.r != r;
}

String _clock(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Vị trí đoạn người học đã chơi trên toàn bộ tác phẩm.
class _CoverageBar extends StatelessWidget {
  final PerformanceResult result;
  const _CoverageBar({required this.result});

  @override
  Widget build(BuildContext context) {
    final total = result.referenceDuration;
    final left = (result.matchedStart / total).clamp(0.0, 1.0);
    final width = ((result.matchedEnd - result.matchedStart) / total).clamp(
      0.015,
      1.0 - left,
    );
    final full = result.coveragePercent >= 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          full
              ? 'Cả tác phẩm'
              : '${_clock(result.matchedStart)}–${_clock(result.matchedEnd)} · ${result.coveragePercent}% tác phẩm',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, c) => Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: c.maxWidth * left,
                  width: c.maxWidth * width,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0:00', style: AppTextStyles.bodySmall),
            Text(_clock(total), style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }
}
