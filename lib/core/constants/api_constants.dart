class ApiConstants {
  // Android emulator → 10.0.2.2, iOS simulator → localhost, real device → LAN IP
  // Override khi chạy local: flutter run --dart-define=API_BASE_URL=http://localhost:8080
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://folkify-backend.onrender.com');
}
