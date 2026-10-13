import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/upgrade_sheet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/instrument_provider.dart';
import '../../../../core/widgets/instrument_image.dart';
import '../../domain/models/instrument.dart';

class InstrumentDetailScreen extends ConsumerStatefulWidget {
  final String instrumentId;
  const InstrumentDetailScreen({super.key, required this.instrumentId});

  @override
  ConsumerState<InstrumentDetailScreen> createState() =>
      _InstrumentDetailScreenState();
}

class _InstrumentDetailScreenState
    extends ConsumerState<InstrumentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentAsync =
        ref.watch(instrumentDetailProvider(widget.instrumentId));

    return instrumentAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không tải được dữ liệu',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(instrumentDetailProvider(widget.instrumentId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (inst) => Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverHeader(context, inst, innerBoxIsScrolled),
        ],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLessonsTab(inst),
                  _buildInfoTab(inst),
                  _buildSongsTab(inst),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader(BuildContext context, Instrument inst, bool scrolled) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: FaIcon(FontAwesomeIcons.arrowLeft, color: Colors.white, size: 16),
        ),
        onPressed: () => context.canPop() ? context.pop() : context.go('/learn'),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            InstrumentImage.fromDetail(inst, fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(inst.category, style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(inst.region, style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(inst.name, style: AppTextStyles.displayMedium),
                  Text(inst.englishName, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTextStyles.labelLarge,
        tabs: const [
          Tab(text: 'Bài học'),
          Tab(text: 'Thông tin'),
          Tab(text: 'Bài hát'),
        ],
      ),
    );
  }

  Widget _buildLessonsTab(Instrument inst) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: inst.lessons.length,
      separatorBuilder: (_, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lesson = inst.lessons[index];
        // Bài "học tiếp" = bài mở khóa đầu tiên chưa hoàn thành
        final nextIndex = inst.lessons.indexWhere((l) => !l.locked && !l.completed);
        final isFirst = index == nextIndex;
        return GestureDetector(
          onTap: () => lesson.locked
              ? showUpgradeSheet(context, requiredPlan: lesson.requiredPlan)
              : context.go('/learn/${inst.id}/lesson/${lesson.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFirst ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isFirst ? AppColors.primary : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: lesson.locked
                        ? FaIcon(FontAwesomeIcons.lock, color: AppColors.textMuted, size: 18)
                        : lesson.completed
                            ? FaIcon(FontAwesomeIcons.check, color: AppColors.success, size: 20)
                            : isFirst
                                ? FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 22)
                                : Text(
                                    '${index + 1}',
                                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.textMuted),
                                  ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: AppTextStyles.titleMedium, maxLines: 2),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          FaIcon(FontAwesomeIcons.clock, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(lesson.duration, style: AppTextStyles.bodySmall),
                          const SizedBox(width: 12),
                          _LevelBadge(level: lesson.level),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (lesson.locked)
                  PlanLockBadge(plan: lesson.requiredPlan)
                else
                Column(
                  children: [
                    Text('+${lesson.xp}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    Text('XP', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(Instrument inst) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mô tả', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(inst.description, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
          const SizedBox(height: 24),
          _buildInfoGrid(inst),
          const SizedBox(height: 24),
          Text('Điều thú vị', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          ...inst.facts.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: FaIcon(FontAwesomeIcons.check, color: AppColors.primary, size: 13),
                    ),
                    Expanded(child: Text(f, style: AppTextStyles.bodyMedium.copyWith(height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Instrument inst) {
    final items = [
      ('Nguồn gốc', inst.origin, FontAwesomeIcons.globe),
      ('Chất liệu', inst.material, FontAwesomeIcons.gear),
      ('Âm vực', inst.soundRange, FontAwesomeIcons.microphone),
      ('Vùng miền', inst.region, FontAwesomeIcons.locationPin),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            FaIcon(item.$3, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$1, style: AppTextStyles.bodySmall),
                  Text(item.$2, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSongsTab(Instrument inst) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: inst.songs.length,
      separatorBuilder: (_, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final song = inst.songs[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FaIcon(FontAwesomeIcons.music, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: AppTextStyles.titleMedium),
                    Text(song.artist, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Text(song.duration, style: AppTextStyles.bodySmall),
              const SizedBox(width: 10),
              FaIcon(FontAwesomeIcons.circlePlay, color: AppColors.primary, size: 28),
            ],
          ),
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});

  Color get _color => switch (level) {
    'Beginner' => AppColors.success,
    'Intermediate' => AppColors.warning,
    _ => AppColors.error,
  };

  String get _label => switch (level) {
    'Beginner' => 'Cơ bản',
    'Intermediate' => 'Trung cấp',
    _ => 'Nâng cao',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(_label, style: AppTextStyles.bodySmall.copyWith(color: _color, fontWeight: FontWeight.w600, fontSize: 10)),
    );
  }
}
