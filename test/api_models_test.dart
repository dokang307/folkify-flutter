import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folkify_flutter/core/services/api_error.dart';
import 'package:folkify_flutter/core/services/quiz_service.dart';
import 'package:folkify_flutter/core/services/scoring_service.dart';
import 'package:folkify_flutter/features/learn/domain/models/instrument.dart';
import 'package:folkify_flutter/features/learn/presentation/widgets/lesson_video.dart';

// Payload mẫu theo đúng shape backend trả về (LessonSummaryResponse, QuizResultResponse, PerformanceResponse)
void main() {
  test('lesson summary carries lock + completion state', () {
    final lesson = Lesson.fromSummaryJson({
      'id': 'uuid-1',
      'slug': 'dt-09',
      'title': 'Xàng xê',
      'xp': 120,
      'requiredPlan': 'PRO',
      'locked': true,
      'completed': false,
    });
    expect(lesson.locked, isTrue);
    expect(lesson.requiredPlan, 'PRO');
    expect(lesson.completed, isFalse);
  });

  test('lesson summary from older backend defaults to unlocked FREE', () {
    final lesson = Lesson.fromSummaryJson({'id': 'u', 'slug': 'dt-01', 'title': 't'});
    expect(lesson.locked, isFalse);
    expect(lesson.requiredPlan, 'FREE');
  });

  test('youtube id resolves from id or url, rejects placeholders', () {
    expect(LessonVideo.resolveId('gnog5AYksx4', null), 'gnog5AYksx4');
    expect(LessonVideo.resolveId(null, 'https://www.youtube.com/embed/gnog5AYksx4'), 'gnog5AYksx4');
    expect(LessonVideo.resolveId(null, 'https://www.youtube.com/embed/example1'), isNull);
    expect(LessonVideo.resolveId(null, null), isNull);
  });

  test('quiz result parses completion XP', () {
    final r = QuizResult.fromJson({
      'scorePercent': 100,
      'correctCount': 2,
      'totalCount': 2,
      'passed': true,
      'results': [
        {'questionId': 'q1', 'correct': true, 'correctOptionIds': ['o1'], 'explanation': 'vì'},
      ],
      'completion': {'xpEarned': 50, 'totalXp': 400, 'currentStreak': 3, 'newAchievements': []},
    });
    expect(r.passed, isTrue);
    expect(r.xpEarned, 50);
    expect(r.results.single.correctOptionIds, ['o1']);
  });

  test('performance result parses metrics chart and deviations', () {
    final p = PerformanceResult.fromJson({
      'id': 'p1',
      'songId': 's1',
      'songTitle': 'Trống cơm',
      'overall': 82,
      'pitchScore': 78,
      'rhythmScore': 88,
      'stabilityScore': 90,
      'feedback': ['Khá tốt', 'Bạn đã chơi đoạn 0:45–1:30 / 3:10 (24% tác phẩm).'],
      'metrics': {
        'chart': {'times': [0, 1.5], 'target': [67, 69], 'user': [67.1, 69.4]},
        'noteDeviations': [
          {'start': 1.2, 'end': 1.8, 'cents': 48},
        ],
        'matchedStart': 45,
        'matchedEnd': 90.5,
        'referenceDurationSeconds': 190,
        'coveragePercent': 24,
      },
    });
    expect(p.songTitle, 'Trống cơm');
    expect(p.rhythmScore, 88);
    expect(p.chartTimes, [0.0, 1.5]);
    expect(p.deviations.single.cents, 48.0);
    expect(p.matchedStart, 45.0);
    expect(p.matchedEnd, 90.5);
    expect(p.referenceDuration, 190.0);
    expect(p.coveragePercent, 24);
  });

  test('scoring song parses lock + readiness', () {
    final song = ScoringSong.fromJson({
      'id': 's2',
      'title': 'Trống cơm',
      'artist': 'Dân ca Bắc Bộ',
      'duration': '3:10',
      'requiredPlan': 'PRO',
      'locked': true,
      'scoringReady': true,
      'referenceAudioUrl': null,
      'referenceDurationSeconds': 190,
    });
    expect(song.locked, isTrue);
    expect(song.scoringReady, isTrue);
    expect(song.requiredPlan, 'PRO');
    expect(song.referenceDurationSeconds, 190.0);
  });

  test('api error keeps backend code for plan gating', () {
    final e = ApiError.fromDio(DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 403,
        data: {'code': 1106, 'message': 'Bài học này cần nâng cấp gói để truy cập'},
      ),
    ));
    expect(e.code, ApiError.planRequired);
    expect(e.isPlanGate, isTrue);
    expect(e.message, contains('nâng cấp'));
  });

  test('network failure maps to friendly message', () {
    final e = ApiError.fromDio(DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    ));
    expect(e.code, isNull);
    expect(e.message, 'Không thể kết nối máy chủ');
  });
}
