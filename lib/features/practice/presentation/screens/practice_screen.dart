import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  int _selectedTab = 0;
  int _selectedRhythm = 0;
  double _bpm = 60;
  bool _isPlaying = false;

  // AI Pitch state
  int _aiMode = 0;
  int _aiNoteIndex = 0;
  bool _aiRecording = false;

  static const _aiModes = ['Gam đi lên', 'Ngũ cung', 'Kết câu'];
  static const _aiNotesByMode = [
    ['Đô4', 'Rê4', 'Mi4', 'Fa4', 'Sol4', 'La4', 'Si4'],
    ['Đô4', 'Rê4', 'Mi4', 'Sol4', 'La4'],
    ['Sol3', 'La3', 'Đô4', 'Rê4', 'Mi4'],
  ];

  // Quiz state
  bool _quizStarted = false;
  bool _quizFinished = false;
  int _quizScore = 0;
  int _currentQuiz = 0;
  int? _quizSelected;
  bool _quizAnswered = false;
  bool _quizTimedOut = false;
  int _quizTimeLeft = 5;
  Timer? _quizTimer;
  final List<({bool correct, bool timedOut})> _quizResults = [];

  static const _quizQuestions = [
    (
      question: 'Nhạc cụ nào có tiếng vang đặc trưng như thế này?',
      hint: "Nốt: 'Fa' — nốt thứ 4",
      options: ['Đàn Tranh', 'Sáo Trúc', 'Đàn Bầu', 'Đàn Nguyệt'],
      correct: 2,
      fact: 'Âm nhạc dân tộc Việt Nam có hơn 50 loại nhạc cụ, mỗi vùng miền có những loại đặc trưng riêng.',
    ),
    (
      question: 'Nhạc cụ nào thuộc họ dây gảy?',
      hint: 'Gợi ý: Được gảy bằng ngón tay hoặc miếng gảy',
      options: ['Sáo Trúc', 'Đàn Tranh', 'Đàn Tỳ Bà', 'Cồng Chiêng'],
      correct: 1,
      fact: 'Đàn tranh có 16–17 dây, mỗi dây gảy tạo ra âm thanh riêng biệt và rất phong phú.',
    ),
    (
      question: 'Nhạc cụ nào đặc trưng của vùng Tây Nguyên?',
      hint: 'Gợi ý: Thường dùng trong lễ hội cộng đồng',
      options: ['Đàn Bầu', 'Đàn Nguyệt', 'Cồng Chiêng', 'Sáo Trúc'],
      correct: 2,
      fact: 'Cồng Chiêng Tây Nguyên được UNESCO công nhận là Di sản văn hóa phi vật thể năm 2005.',
    ),
  ];

  void _startQuizTimer() {
    _quizTimer?.cancel();
    _quizTimeLeft = 5;
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_quizTimeLeft <= 1) {
        _quizTimer?.cancel();
        _timeUp();
      } else {
        setState(() => _quizTimeLeft--);
      }
    });
  }

  void _timeUp() {
    if (_quizAnswered) return;
    _quizTimer?.cancel();
    setState(() {
      _quizAnswered = true;
      _quizTimedOut = true;
      _quizTimeLeft = 0;
      _quizResults.add((correct: false, timedOut: true));
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _advanceQuiz();
    });
  }

  void _selectQuizAnswer(int index) {
    if (_quizAnswered) return;
    _quizTimer?.cancel();
    final isCorrect = index == _quizQuestions[_currentQuiz].correct;
    setState(() {
      _quizSelected = index;
      _quizAnswered = true;
      _quizTimedOut = false;
      _quizResults.add((correct: isCorrect, timedOut: false));
      if (isCorrect) _quizScore++;
    });
  }

  void _advanceQuiz() {
    if (_currentQuiz >= _quizQuestions.length - 1) {
      setState(() => _quizFinished = true);
      return;
    }
    setState(() {
      _currentQuiz++;
      _quizSelected = null;
      _quizAnswered = false;
      _quizTimedOut = false;
      _quizTimeLeft = 5;
    });
    _startQuizTimer();
  }

  void _resetQuiz() {
    _quizTimer?.cancel();
    setState(() {
      _quizStarted = false;
      _quizFinished = false;
      _quizScore = 0;
      _currentQuiz = 0;
      _quizSelected = null;
      _quizAnswered = false;
      _quizTimedOut = false;
      _quizTimeLeft = 5;
      _quizResults.clear();
    });
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    super.dispose();
  }

  final _tabs = [
    {'icon': FontAwesomeIcons.music, 'label': 'Nhịp điệu'},
    {'icon': FontAwesomeIcons.gamepad, 'label': 'Đố vui'},
    {'icon': FontAwesomeIcons.microchip, 'label': 'AI Pitch'},
  ];

  final _rhythms = [
    {
      'name': 'Nhịp 4/4 cơ bản',
      'desc': 'Nhịp cơ bản 4/4 để luyện giữ nhịp đều',
      'level': 'Beginner',
      'bpm': 60,
    },
    {
      'name': 'Nhịp chèo',
      'desc': 'Nhịp điệu đặc trưng của hát chèo Bắc Bộ',
      'level': 'Intermediate',
      'bpm': 80,
    },
    {
      'name': 'Nhịp cải lương',
      'desc': 'Nhịp điệu của đờn ca tài tử và cải lương Nam Bộ',
      'level': 'Advanced',
      'bpm': 100,
    },
  ];

  Color _levelColor(String level) {
    switch (level) {
      case 'Beginner':
        return const Color(0xFF16A34A);
      case 'Intermediate':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  const SizedBox(height: 24),
                  if (_selectedTab == 0) ...[
                    Text('Chọn nhịp luyện tập', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildRhythmList(),
                    const SizedBox(height: 20),
                    _buildMetronomeCard(),
                  ] else if (_selectedTab == 1)
                    _buildQuizTab()
                  else
                    // Quyền dùng AI do màn /practice/ai kiểm tra theo quota từng gói (BASIC/PRO).
                    _buildAiPitchTab(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        image: DecorationImage(
          image: AssetImage('assets/images/header_bg.jpg'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Folkify',
                style: AppTextStyles.headlineMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FaIcon(FontAwesomeIcons.drum, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'Luyện tập',
                style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Rèn kỹ năng âm nhạc mỗi ngày', style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75))),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Row(
                children: [
                  FaIcon(tab['icon'] as FaIconData,
                    size: 15,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab['label'] as String,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRhythmList() {
    return Column(
      children: _rhythms.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final isSelected = _selectedRhythm == i;
        final level = r['level'] as String;
        final color = _levelColor(level);
        return GestureDetector(
          onTap: () => setState(() {
            _selectedRhythm = i;
            _bpm = (r['bpm'] as int).toDouble();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r['name'] as String,
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(level, style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r['desc'] as String, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '${r['bpm']} BPM',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetronomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Máy đếm nhịp', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              FaIcon(FontAwesomeIcons.clock, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${_bpm.toInt()} BPM',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('40 BPM', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              Text('160 BPM', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _bpm,
              min: 40,
              max: 160,
              onChanged: (v) => setState(() => _bpm = v),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _iconButton(FontAwesomeIcons.arrowsRotate, onTap: () => setState(() {
                _bpm = (_rhythms[_selectedRhythm]['bpm'] as int).toDouble();
                _isPlaying = false;
              })),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                  icon: FaIcon(_isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, size: 18),
                  label: Text(_isPlaying ? 'Dừng lại' : 'Bắt đầu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: AppTextStyles.labelLarge,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _iconButton(FontAwesomeIcons.volumeHigh, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(FaIconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: FaIcon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildQuizStartScreen() {
    final stats = [
      (FontAwesomeIcons.listOl, '${_quizQuestions.length} câu hỏi'),
      (FontAwesomeIcons.music, 'Nhạc cụ dân tộc'),
      (FontAwesomeIcons.bolt, 'Tích điểm XP'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const FaIcon(FontAwesomeIcons.gamepad, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Đố vui nhạc cụ',
                style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Đoán tên nhạc cụ qua mô tả\nvà gợi ý âm thanh',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: stats.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: FaIcon(s.$1, color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(s.$2, style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _quizStarted = true);
            _startQuizTimer();
          },
          icon: const FaIcon(FontAwesomeIcons.play, size: 15),
          label: const Text('Bắt đầu chơi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: AppTextStyles.labelLarge,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FaIcon(FontAwesomeIcons.circleInfo, color: AppColors.primaryLight, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mỗi câu có 5 giây để trả lời. Hết giờ sẽ bị tính sai. Trả lời đúng để cộng điểm!',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    if (!_quizStarted) return _buildQuizStartScreen();
    if (_quizFinished) return _buildQuizResultScreen();

    final q = _quizQuestions[_currentQuiz];
    final options = q.options;
    final correct = q.correct;
    final timerColor = _quizTimeLeft >= 3
        ? const Color(0xFF4ADE80)
        : _quizTimeLeft == 2
            ? const Color(0xFFF59E0B)
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Điểm số', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                  Text('Đoán đúng nhạc cụ', style: AppTextStyles.bodySmall),
                ],
              ),
              const Spacer(),
              Text(
                '$_quizScore',
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${_quizResults.length} câu',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Question card
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 36),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.bullseye, color: Colors.white54, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'Câu ${_currentQuiz + 1}/${_quizQuestions.length}',
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Timer badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: timerColor, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: _quizTimedOut
                        ? FaIcon(FontAwesomeIcons.xmark, color: timerColor, size: 13)
                        : _quizAnswered
                            ? FaIcon(FontAwesomeIcons.check, color: AppColors.primary, size: 13)
                            : Text(
                                '$_quizTimeLeft',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: timerColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                  ),
                ],
              ),
              // Timer bar
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _quizAnswered ? (_quizTimedOut ? 0 : 1) : _quizTimeLeft / 5,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(timerColor),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const FaIcon(FontAwesomeIcons.recordVinyl, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                q.question,
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_quizTimedOut)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hết giờ!',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
                  ),
                )
              else
                Text(
                  q.hint,
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Answer grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: List.generate(options.length, (i) {
            final isSelected = _quizSelected == i;
            final isCorrect = i == correct;
            Color borderColor = AppColors.border;
            Color bgColor = Colors.white;
            Color iconColor = AppColors.textMuted;
            if (_quizAnswered) {
              if (isCorrect) {
                borderColor = AppColors.primary;
                bgColor = AppColors.surfaceCard;
                iconColor = AppColors.primary;
              } else if (isSelected) {
                borderColor = AppColors.error;
                bgColor = AppColors.error.withValues(alpha: 0.06);
                iconColor = AppColors.error;
              }
            }
            return GestureDetector(
              onTap: () => _selectQuizAnswer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: isSelected || isCorrect && _quizAnswered ? 1.5 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.recordVinyl, color: iconColor, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      options[i],
                      style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),

        // Next button (only after user picks an answer — timeout auto-advances)
        if (_quizAnswered && !_quizTimedOut) ...[
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _advanceQuiz,
            icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 15),
            label: Text(_currentQuiz < _quizQuestions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: AppTextStyles.labelLarge,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Fact card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FaIcon(FontAwesomeIcons.lightbulb, color: Color(0xFFF59E0B), size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bạn có biết?', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(q.fact, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizResultScreen() {
    final total = _quizQuestions.length;
    final pct = total > 0 ? ((_quizScore / total) * 100).round() : 0;
    final (String message, FaIconData icon, Color color) = pct == 100
        ? ('Xuất sắc! Bạn biết hết rồi!', FontAwesomeIcons.trophy, AppColors.primary)
        : pct >= 67
            ? ('Khá tốt! Tiếp tục luyện nhé!', FontAwesomeIcons.star, const Color(0xFF16A34A))
            : pct >= 34
                ? ('Cần luyện thêm bạn ơi!', FontAwesomeIcons.fire, const Color(0xFFD97706))
                : ('Hãy học thêm nhạc cụ nhé!', FontAwesomeIcons.bookOpen, AppColors.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Result hero card
        Container(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: FaIcon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Kết quả', style: AppTextStyles.bodySmall.copyWith(color: Colors.white54)),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(children: [
                  TextSpan(
                    text: '$_quizScore',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 48,
                    ),
                  ),
                  TextSpan(
                    text: ' / $total',
                    style: AppTextStyles.headlineMedium.copyWith(color: Colors.white60),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text('câu trả lời đúng', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message,
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Per-question breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chi tiết', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ..._quizResults.asMap().entries.map((e) {
                final i = e.key;
                final result = e.value;
                final q = _quizQuestions[i];
                return Padding(
                  padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: result.correct
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: FaIcon(
                          result.correct ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                          color: result.correct ? AppColors.primary : AppColors.error,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Câu ${i + 1}',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                            Text(
                              q.options[q.correct],
                              style: AppTextStyles.labelMedium.copyWith(
                                color: result.correct ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (result.timedOut)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hết giờ',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton.icon(
          onPressed: _resetQuiz,
          icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 15),
          label: const Text('Chơi lại'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: AppTextStyles.labelLarge,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  /// Màn khóa khi user chưa có gói PRO — mời nâng cấp.
  Widget _buildAiScoringEntry() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/practice/ai'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const FaIcon(FontAwesomeIcons.microphoneLines, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trình diễn tác phẩm & AI chấm điểm', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Chọn tác phẩm, chơi một đoạn hoặc cả bài — AI chấm cao độ, nhịp, độ ổn định',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const FaIcon(FontAwesomeIcons.chevronRight, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPitchTab() {
    final notes = _aiNotesByMode[_aiMode];
    final noteIdx = _aiNoteIndex.clamp(0, notes.length - 1);
    final currentNote = notes[noteIdx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAiScoringEntry(),
        const SizedBox(height: 16),
        // AI Performance card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Performance', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
                        const SizedBox(height: 4),
                        Text(
                          'Đánh giá nốt nhạc realtime',
                          style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: FaIcon(FontAwesomeIcons.waveSquare, color: Colors.white, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _aiStatChip('Nốt', '--'),
                  const SizedBox(width: 10),
                  _aiStatChip('Tần số', '--'),
                  const SizedBox(width: 10),
                  _aiStatChip('Accuracy', '0%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sequence mode card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.recordVinyl, color: AppColors.textMuted, size: 13),
                  const SizedBox(width: 7),
                  Text(
                    'Sequence mode',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mode selector
              Row(
                children: List.generate(_aiModes.length, (i) {
                  final sel = _aiMode == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _aiMode = i;
                        _aiNoteIndex = 0;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < _aiModes.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _aiModes[i],
                          style: AppTextStyles.labelMedium.copyWith(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Note chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(notes.length, (i) {
                    final sel = noteIdx == i;
                    return GestureDetector(
                      onTap: () => setState(() => _aiNoteIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < notes.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          notes[i],
                          style: AppTextStyles.labelMedium.copyWith(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),

              // Record button
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _aiRecording = !_aiRecording),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: _aiRecording ? AppColors.error : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_aiRecording ? AppColors.error : AppColors.primary)
                              .withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          _aiRecording ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _aiRecording ? 'Dừng' : 'Ghi Âm',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Accuracy badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.signal, color: AppColors.textMuted, size: 12),
                      const SizedBox(width: 6),
                      Text('0%', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Target row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mục tiêu: $currentNote · Bước ${noteIdx + 1}/${notes.length}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  Text('--', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 8),

              // Pitch deviation bar
              SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(width: 1.5, height: 10, color: AppColors.border),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-50', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                  Text('0', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                  Text('+50', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),

              // Status message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Text(
                  _aiRecording
                      ? 'Đang ghi âm... Hãy hát nốt $currentNote'
                      : 'Nhấn Ghi Âm để bắt đầu.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

}
