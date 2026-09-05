import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'bilibili_auth.dart';
import 'bilibili_device.dart';
import 'wbi_service.dart';

class BilibiliClient {
  final Dio dio;
  final BilibiliAuth auth;
  late final BilibiliDevice device;
  late final WbiService wbi;

  BilibiliClient(this.dio) : auth = BilibiliAuth() {
    device = BilibiliDevice(dio, auth);
    wbi = WbiService(dio, onEnsureDevice: () => device.ensureBuvid());
  }

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.bilibili.com',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
        'env': 'prod',
        'app-key': 'android64',
        'x-bili-aurora-zone': 'sh001',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false, requestHeader: false));
    return dio;
  }

  Future<Map<String, dynamic>> wbiGet(String path, Map<String, dynamic> params) async {
    await device.ensureBuvid();
    final signed = await wbi.sign(params);
    final resp = await dio.get(path, queryParameters: signed, options: Options(headers: auth.requestHeaders()));
    final body = resp.data as Map<String, dynamic>;
    final code = body['code'];
    if (code is int && code != 0) {
      // ignore: avoid_print
      print('[kzv] wbi error $path code=$code msg=${body['message']}');
      throw BilibiliApiException('${body['message'] ?? code}', code: code, path: path);
    }
    return body;
  }
}