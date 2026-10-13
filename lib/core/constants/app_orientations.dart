import 'package:flutter/services.dart';

/// Hướng màn hình mặc định của app (chỉ dọc). Màn nào tạm đổi hướng (vd video toàn màn hình)
/// phải trả về đúng giá trị này khi thoát.
const appOrientations = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

Future<void> restoreAppOrientation() => Future.wait([
      SystemChrome.setPreferredOrientations(appOrientations),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    ]);
