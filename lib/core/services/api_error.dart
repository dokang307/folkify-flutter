import 'package:dio/dio.dart';

/// Lỗi API giữ lại mã lỗi backend (ErrorCode.java) để UI xử lý riêng
/// (vd. 1106 → hiện màn nâng cấp gói thay vì thông báo lỗi chung).
class ApiError implements Exception {
  final String message;
  final int? code;
  final int? status;

  const ApiError(this.message, {this.code, this.status});

  static const planRequired = 1106;
  static const aiNotInPlan = 1310;
  static const aiQuotaExceeded = 1311;
  static const audioInvalid = 1312;
  static const aiServiceUnavailable = 1313;

  bool get isPlanGate => code == planRequired || code == aiNotInPlan;

  factory ApiError.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return ApiError(
        data['message'] as String,
        code: data['code'] as int?,
        status: e.response?.statusCode,
      );
    }
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Kết nối quá thời gian, vui lòng thử lại',
      DioExceptionType.connectionError => 'Không thể kết nối máy chủ',
      _ => 'Đã có lỗi xảy ra, vui lòng thử lại',
    };
    return ApiError(message, status: e.response?.statusCode);
  }

  @override
  String toString() => message;
}
