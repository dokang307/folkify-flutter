import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_error.dart';

class QuizOption {
  final String id;
  final String text;
  const QuizOption({required this.id, required this.text});
}

class QuizQuestion {
  final String id;
  final String question;
  final bool multi;
  final List<QuizOption> options;

  const QuizQuestion({required this.id, required this.question, required this.multi, required this.options});

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as String,
        question: json['question'] as String,
        multi: json['type'] == 'MULTI',
        options: (json['options'] as List)
            .map((o) => QuizOption(id: o['id'] as String, text: o['text'] as String))
            .toList(),
      );
}

class Quiz {
  final int passPercent;
  final List<QuizQuestion> questions;
  const Quiz({required this.passPercent, required this.questions});
}

class QuestionResult {
  final String questionId;
  final bool correct;
  final List<String> correctOptionIds;
  final String? explanation;

  const QuestionResult({
    required this.questionId,
    required this.correct,
    required this.correctOptionIds,
    this.explanation,
  });
}

class QuizResult {
  final int scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final List<QuestionResult> results;
  final int? xpEarned;
  final int? currentStreak;

  const QuizResult({
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.results,
    this.xpEarned,
    this.currentStreak,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final completion = json['completion'] as Map<String, dynamic>?;
    return QuizResult(
      scorePercent: json['scorePercent'] as int,
      correctCount: json['correctCount'] as int,
      totalCount: json['totalCount'] as int,
      passed: json['passed'] as bool,
      results: (json['results'] as List)
          .map((r) => QuestionResult(
                questionId: r['questionId'] as String,
                correct: r['correct'] as bool,
                correctOptionIds: (r['correctOptionIds'] as List).cast<String>(),
                explanation: r['explanation'] as String?,
              ))
          .toList(),
      xpEarned: completion?['xpEarned'] as int?,
      currentStreak: completion?['currentStreak'] as int?,
    );
  }
}

class QuizService {
  static final _dio = ApiClient.instance;

  static String _path(String instrument, String lesson) => '/api/instruments/$instrument/lessons/$lesson/quiz';

  static Future<Quiz> getQuiz(String instrument, String lesson) async {
    try {
      final res = await _dio.get(_path(instrument, lesson));
      final data = res.data['result'] as Map<String, dynamic>;
      return Quiz(
        passPercent: data['passPercent'] as int? ?? 70,
        questions: (data['questions'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  static Future<QuizResult> submit(String instrument, String lesson, Map<String, List<String>> answers) async {
    try {
      final res = await _dio.post('${_path(instrument, lesson)}/attempts', data: {'answers': answers});
      return QuizResult.fromJson(res.data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
