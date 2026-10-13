import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_orientations.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Video bài học: hiện thumbnail trước, chỉ khởi tạo player YouTube khi người học bấm phát
/// (tiết kiệm dữ liệu di động và tránh tải WebView không cần thiết).
class LessonVideo extends StatefulWidget {
  final String videoId;
  final String? channelName;

  const LessonVideo({super.key, required this.videoId, this.channelName});

  /// Lấy video id từ id thuần hoặc URL watch/embed; trả null nếu không hợp lệ.
  static String? resolveId(String? videoId, String? url) {
    if (videoId != null && RegExp(r'^[\w-]{11}$').hasMatch(videoId)) return videoId;
    if (url == null || url.isEmpty) return null;
    final id = YoutubePlayer.convertUrlToId(url);
    return id != null && RegExp(r'^[\w-]{11}$').hasMatch(id) ? id : null;
  }

  @override
  State<LessonVideo> createState() => _LessonVideoState();
}

class _LessonVideoState extends State<LessonVideo> {
  YoutubePlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _play() {
    setState(() {
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, enableCaption: true),
      );
    });
  }

  /// Toàn màn hình bằng route riêng (không dùng toggleFullScreenMode của package: nó chỉ xoay
  /// cả app sang ngang và không xoay lại khi người học thoát bằng nút Back).
  Future<void> _openFullScreen() async {
    final inline = _controller;
    if (inline == null) return;
    final wasPlaying = inline.value.isPlaying;
    inline.pause();
    final position = await Navigator.of(context, rootNavigator: true).push<Duration>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenVideo(videoId: widget.videoId, start: inline.value.position),
      ),
    );
    if (!mounted || _controller != inline) return;
    if (position != null) inline.seekTo(position);
    if (wasPlaying) inline.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: controller != null
              ? YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: AppColors.primary,
                  bottomActions: _controls(
                    icon: Icons.fullscreen,
                    tooltip: 'Toàn màn hình',
                    onPressed: _openFullScreen,
                  ),
                )
              : AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GestureDetector(
                    onTap: _play,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: Colors.black),
                        ),
                        Container(color: Colors.black26),
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 26),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        if (widget.channelName != null) ...[
          const SizedBox(height: 8),
          Text('Video của kênh ${widget.channelName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

/// Thanh điều khiển giống mặc định của package nhưng thay FullScreenButton bằng nút của app.
List<Widget> _controls({required IconData icon, required String tooltip, required VoidCallback onPressed}) => [
      const SizedBox(width: 14),
      const CurrentPosition(),
      const SizedBox(width: 8),
      ProgressBar(isExpanded: true, colors: const ProgressBarColors(playedColor: AppColors.primary, handleColor: AppColors.primary)),
      const RemainingDuration(),
      const PlaybackSpeedButton(),
      IconButton(icon: Icon(icon, color: Colors.white), tooltip: tooltip, onPressed: onPressed),
    ];

/// Video toàn màn hình: khoá ngang khi mở, luôn trả app về hướng dọc khi đóng (kể cả nút Back
/// hay route bị huỷ). Trả về vị trí đang xem để player trong bài học phát tiếp đúng chỗ.
class _FullScreenVideo extends StatefulWidget {
  final String videoId;
  final Duration start;

  const _FullScreenVideo({required this.videoId, required this.start});

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final YoutubePlayerController _controller = YoutubePlayerController(
    initialVideoId: widget.videoId,
    flags: YoutubePlayerFlags(autoPlay: true, enableCaption: true, startAt: widget.start.inSeconds),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    restoreAppOrientation();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_controller.value.position);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: AppColors.primary,
            bottomActions: _controls(icon: Icons.fullscreen_exit, tooltip: 'Thoát toàn màn hình', onPressed: _close),
          ),
        ),
      ),
    );
  }
}
