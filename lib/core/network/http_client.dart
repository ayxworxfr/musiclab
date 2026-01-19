import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../shared/constants/api_constants.dart';
import 'api_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/log_interceptor.dart';

/// HTTP 客户端封装
///
/// 基于 Dio 封装，提供统一的网络请求接口
class HttpClient extends GetxService {
  late final Dio _dio;

  /// 获取 Dio 实例（供特殊场景使用）
  Dio get dio => _dio;

  @override
  void onInit() {
    super.onInit();
    _initDio();
  }

  /// 初始化 Dio
  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeout),
        sendTimeout: Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器（顺序很重要）
    _dio.interceptors.addAll([
      AuthInterceptor(),
      ErrorInterceptor(),
      AppLogInterceptor(),
    ]);
  }

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// 上传文件
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// 下载文件
  Future<Response> download(
    String url,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  /// 从 DioException 中提取自定义异常
  ApiException _extractException(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException.unknown(e.message, e);
  }
}
