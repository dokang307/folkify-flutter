import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_error.dart';

class AiQuota {
  final int limit;
  final int used;
  final int remaining;
  final DateTime resetsAt;

  const AiQuota({required this.limit, required this.used, required this.remaining, required this.resetsAt});

  factory AiQuota.fromJson(Map<String, dynamic> json) => AiQuota(
        limit: json['limit'] as int,
        used: json['used'] as int,
        remaining: json['remaining'] as int,
        resetsAt: DateTime.parse(json['resetsAt'] as String).toLocal(),
      );
}

/// Tác phẩm của nhạc cụ — đơn vị để AI chấm phần trình diễn.
class ScoringSong {
  final String id;
  final String title;
  final String? artist;
  final String? duration;
  final String requiredPlan;
  /// Gói hiện tại chưa đủ để AI chấm tác phẩm này.
  final bool locked;
  /// Đã có bản mẫu để chấm.
  final bool scoringReady;
  final double? referenceDurationSeconds;

  const ScoringSong({
    required this.id,
    required this.title,
    this.artist,
    this.duration,
    required this.requiredPlan,
    required this.locked,
    required this.scoringReady,
    this.referenceDurationSeconds,
  });

  factory ScoringSong.fromJson(Map<String, dynamic> json) => ScoringSong(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        duration: json['duration'] as String?,
        requiredPlan: json['requiredPlan'] as String? ?? 'BASIC',
        locked: json['locked'] as bool? ?? false,
        scoringReady: json['scoringReady'] as bool? ?? false,
        referenceDurationSeconds: (json['referenceDurationSeconds'] as num?)?.toDouble(),
      );
}

class NoteDeviation {
  final double start;
  final double end;
  final double cents;
  const NoteDeviation({required this.start, required this.end, required this.cents});
}

class PerformanceResult {
  final String id;
  final String songTitle;
  final int overall;
  final int pitchScore;
  final int rhythmScore;
  final int stabilityScore;
  final List<String> feedback;
  final List<double> chartTimes;
  final List<double> chartTarget;
  final List<double> chartUser;
  final List<NoteDeviation> deviations;
  /// Khúc của tác phẩm người học đã chơi (giây trên bản mẫu) và % bao phủ.
  final double matchedStart;
  final double matchedEnd;
  final double referenceDuration;
  final int coveragePercent;

  const PerformanceResult({
    required this.id,
    required this.songTitle,
    required this.overall,
    required this.pitchScore,
    required this.rhythmScore,
    required this.stabilityScore,
    required this.feedback,
    required this.chartTimes,
    required this.chartTarget,
    required this.chartUser,
    required this.deviations,
    required this.matchedStart,
    required this.matchedEnd,
    required this.referenceDuration,
    required this.coveragePercent,
  });

  static List<double> _nums(dynamic list) =>
      (list as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [];

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory PerformanceResult.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>? ?? const {};
    final chart = metrics['chart'] as Map<String, dynamic>? ?? const {};
    return PerformanceResult(
      id: json['id'] as String,
      songTitle: json['songTitle'] as String? ?? '',
      overall: json['overall'] as int,
      pitchScore: json['pitchScore'] as int,
      rhythmScore: json['rhythmScore'] as int,
      stabilityScore: json['stabilityScore'] as int,
      feedback: (json['feedback'] as List?)?.cast<String>() ?? const [],
      chartTimes: _nums(chart['times']),
      chartTarget: _nums(chart['target']),
      chartUser: _nums(chart['user']),
      deviations: ((metrics['noteDeviations'] as List?) ?? const [])
          .map((d) => NoteDeviation(
                start: (d['start'] as num).toDouble(),
                end: (d['end'] as num).toDouble(),
                cents: (d['cents'] as num).toDouble(),
              ))
          .toList(),
      matchedStart: _num(metrics['matchedStart']),
      matchedEnd: _num(metrics['matchedEnd']),
      referenceDuration: _num(metrics['referenceDurationSeconds']),
      coveragePercent: (metrics['coveragePercent'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScoringService {
  static final _dio = ApiClient.instance;

  // Bản ghi tới 6 phút: tải lên + phân tích phía server có thể mất cả phút
  static const _analyzeTimeout = Duration(minutes: 3);

  static Future<AiQuota> getQuota() async {
    try {
      final res = await _dio.get('/api/me/entitlements');
      return AiQuota.fromJson(res.data['result']['aiQuota'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  static Future<List<ScoringSong>> getSongs(String instrument) async {
    try {
      final res = await _dio.get('/api/instruments/$instrument/songs');
      return (res.data['result'] as List).map((e) => ScoringSong.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  /// Gửi bản ghi một đoạn hoặc cả tác phẩm — AI tự dò đoạn đã chơi.
  static Future<PerformanceResult> submit({required String filePath, required String songId}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
        'songId': songId,
      });
      final res = await _dio.post(
        '/api/performances',
        data: form,
        options: Options(sendTimeout: _analyzeTimeout, receiveTimeout: _analyzeTimeout),
      );
      return PerformanceResult.fromJson(res.data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    } on FileSystemException {
      throw const ApiError('Không đọc được file ghi âm, hãy ghi lại.');
    } on TypeError {
      throw const ApiError('Phản hồi chấm điểm không hợp lệ, vui lòng thử lại.');
    }
  }
}
