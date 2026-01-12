import 'package:get/get.dart';

import '../core/network/http_client.dart';

/// 全局依赖绑定
class AppBinding extends Bindings {
  @override
  void dependencies() {
    // 网络客户端
    Get.put<HttpClient>(HttpClient(), permanent: true);
  }
}

