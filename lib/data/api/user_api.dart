import 'package:dio/dio.dart';
import '../app_sign.dart';
import '../api_endpoints.dart';
import '../bilibili_constants.dart';
import '../../core/logger.dart';
import 'api_base.dart';

class UserApi extends ApiBase {
  UserApi(super.client);

  Future<({String name, String face, int fans, String banner})?> getUserInfo(int mid) async {
    final appF = _getUserInfoApp(mid);
    final cardF = _getUserCard(mid);
    final wbiF = _getUserInfoWeb(mid);
    final app = await appF;
    final results = [app, await wbiF, await cardF].whereType<({String name, String face, int fans, String banner})>().toList();
    if (results.isEmpty) return null;
    final name = results.map((e) => e.name).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final face = results.map((e) => e.face).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final fans = results.map((e) => e.fans).firstWhere((n) => n > 0, orElse: () => 0);
    final banner = results.map((e) => e.banner).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return (name: name, face: face, fans: fans, banner: banner);
  }

  Future<({String name, String face, int fans, String banner})?> _getUserInfoApp(int mid) async {
    try {
      final params = <String, dynamic>{
        'vmid': mid,
        'mobi_app': 'android',
        'platform': 'android',
        'build': 8430300,
        'version': '8.43.0',
        'channel': 'master',
        'c_locale': 'zh_CN',
        's_locale': 'zh_CN',
      };
      AppSign.appSign(params);
      final resp = await dio.get(ApiEndpoints.space, queryParameters: params, options: Options(headers: {
        'User-Agent': BiliConstants.appUserAgent,
        'Referer': 'https://www.bilibili.com/',
      }));
      final data = resp.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final card = data['card'] as Map<String, dynamic>? ?? const {};
      final images = data['images'] as Map<String, dynamic>? ?? const {};
      return (
        name: card['name'] as String? ?? '',
        face: ((card['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: card['fans'] as int? ?? 0,
        banner: ((images['imgUrl'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      KzvLogger.debug('getUserInfoApp failed: $e');
      return null;
    }
  }

  Future<({String name, String face, int fans, String banner})?> _getUserCard(int mid) async {
    try {
      await client.device.ensureBuvid();
      final resp = await dio.get(ApiEndpoints.card, queryParameters: {'mid': mid, 'photo': true}, options: Options(headers: client.auth.requestHeaders()));
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final card = data?['card'] as Map<String, dynamic>?;
      if (card == null) return null;
      final space = card['space'] as Map<String, dynamic>?;
      return (
        name: card['name'] as String? ?? '',
        face: ((card['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: (card['fans'] as int?) ?? (data?['follower'] as int?) ?? 0,
        banner: ((space?['l_img'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      KzvLogger.debug('getUserCard failed: $e');
      return null;
    }
  }

  Future<({String name, String face, int fans, String banner})?> _getUserInfoWeb(int mid) async {
    try {
      final data = await wbiGet(ApiEndpoints.spaceAccInfo, {
        'mid': mid,
        'token': '',
        'platform': 'web',
        'web_location': '1550101',
        ...dmImgParams(),
      });
      final card = data['data'] as Map<String, dynamic>?;
      if (card == null) return null;
      return (
        name: card['name'] as String? ?? '',
        face: ((card['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: card['fans'] as int? ?? 0,
        banner: ((card['top_photo'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      KzvLogger.debug('getUserInfoWeb failed: $e');
      return null;
    }
  }
}
