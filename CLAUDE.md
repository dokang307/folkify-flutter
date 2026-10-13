# Folkify Flutter

App học nhạc cụ dân tộc Việt Nam — Flutter mobile app, deploy CH Play + App Store.

## Nguồn gốc

Port từ web app React tại `~/Desktop/Desktop - Nhật's MacBook Pro/Mobile app for learning instruments`.
Hội thoại thiết kế ban đầu nằm trong project đó (working dir của web app).

## Stack

- Flutter 3.47 / Dart 3.12 (`pubspec.yaml` `sdk: ^3.12.0`)
- State: **flutter_riverpod** (`lib/core/providers/`)
- Navigation: **go_router** (`lib/core/router/app_router.dart`) — có auth redirect guard
- Theme: Material 3 dark, màu chủ đạo amber `#D97706`, font Be Vietnam Pro
- HTTP: **dio**, tích hợp thật với backend Spring Boot — `lib/core/services/api_client.dart` (Dio instance dùng chung, interceptor tự gắn `Authorization: Bearer` + tự refresh token khi gặp 401) và `lib/core/services/auth_service.dart` (login/register/forgot-password gọi thẳng `/api/auth/**`). Token lưu ở `lib/core/services/token_storage.dart`.
- Auth: không còn mock — `AuthTokens`/`UserInfo` (role, plan, planExpiresAt) lấy trực tiếp từ response backend.

## Cấu trúc nhanh

```
lib/core/
  constants/        → ApiConstants (baseUrl, ...)
  providers/        → Riverpod providers
  router/           → app_router.dart (auth redirect guard)
  services/         → api_client.dart, auth_service.dart, token_storage.dart
  theme/, widgets/
lib/features/
  auth/             → presentation only (login, register, forgot_password) — gọi lib/core/services trực tiếp, không có data/domain layer riêng
  home/             → home_screen
  learn/            → data/ domain/ presentation/ — instruments, instrument_detail (3 tabs), lesson_detail
  practice/         → metronome + tuner placeholder
  sheets/           → bản nhạc + search/filter
  premium/          → plans (Basic 49k, Pro 99k VND), Pay2S checkout
  profile/          → stats, badges, menu, logout
```

Lưu ý: chỉ `learn/` có tách `data/`+`domain/`; các feature khác gọi thẳng `lib/core/services` hoặc dùng static data cục bộ — đừng giả định mọi feature đều có data layer riêng.

## Build & release

- APK release build được lưu lại (không phải source) ở `../folkify_android/` — xem README ở đó cho quy trình rebuild, version hiện tại, và các lưu ý Windows-only (Kotlin incremental cache bug, AGP version pin).
- Backend production: `https://api.folkify.vn` (`ApiConstants.baseUrl`).

## Việc tiếp theo

- [ ] App icon + splash screen (`flutter_launcher_icons`, `flutter_native_splash`)
- [ ] Signing cho store (Apple Developer + Google Play Console)
- [ ] Cân nhắc thay flow Pay2S trong `premium/` bằng bank-QR flow riêng (theo ghi chú trong `folkify_android/README.md`)
