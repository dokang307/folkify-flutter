import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'auth_service.dart';
import '../../features/learn/domain/models/instrument.dart';

class InstrumentService {
  static final _dio = ApiClient.instance;

  static Future<List<InstrumentSummary>> getAll() async {
    try {
      final res = await _dio.get('/api/instruments');
      final list = res.data['result'] as List;
      return list
          .map((e) => InstrumentSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<Instrument> getDetail(String slug) async {
    try {
      final res = await _dio.get('/api/instruments/$slug');
      return Instrument.fromJson(res.data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<Lesson> getLessonDetail(
      String instrumentSlug, String lessonSlug) async {
    try {
      final res = await _dio
          .get('/api/instruments/$instrumentSlug/lessons/$lessonSlug');
      return Lesson.fromDetailJson(
          res.data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      // Giữ mã lỗi (1106 = cần nâng cấp gói) để màn bài học hiện paywall
      throw ApiError.fromDio(e);
    }
  }

  static String _extractMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'] as String;
      }
    } catch (_) {}
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout =>
        'Kết nối quá thời gian, vui lòng thử lại',
      DioExceptionType.connectionError => 'Không thể kết nối máy chủ',
      _ => 'Lỗi không xác định',
    };
  }
}
