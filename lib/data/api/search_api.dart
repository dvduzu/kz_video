import 'package:dio/dio.dart';
import '../api_exception.dart';
import '../api_endpoints.dart';
import '../models.dart';
import 'api_base.dart';

class SearchApi extends ApiBase {
  SearchApi(super.client);

  Future<List<SearchUser>> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    await client.device.ensureBuvid();
    final params = <String, dynamic>{
      'search_type': 'bili_user',
      'keyword': keyword,
      'page': 1,
      'page_size': 20,
      'platform': 'pc',
      'web_location': 1430654,
    };
    final signed = await client.wbi.sign(params);
    final enc = Uri.encodeComponent(keyword);
    final resp = await dio.get(ApiEndpoints.searchType,
      queryParameters: signed,
      options: Options(headers: client.auth.requestHeaders(extra: {
        'origin': 'https://search.bilibili.com',
        'referer': 'https://search.bilibili.com/bili_user?keyword=$enc',
      })));
    final body = resp.data as Map<String, dynamic>;
    final voucher = (body['data'] as Map<String, dynamic>?)?['v_voucher'] as String?;
    if (voucher != null && voucher.isNotEmpty) {
      throw const RiskControlException('搜索触发风控，请登录后重试');
    }
    if (body['code'] is int && body['code'] != 0) {
      throw BilibiliApiException('${body['message'] ?? body['code']}', code: body['code'] as int?);
    }
    final result = body['data']?['result'] as List? ?? [];
    return result.map((e) {
      final m = e as Map<String, dynamic>;
      return SearchUser(
        mid: m['mid'] as int? ?? 0,
        uname: m['uname'] as String? ?? '',
        sign: m['usign'] as String? ?? '',
        fans: m['fans'] as int? ?? 0,
        face: ((m['upic'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    }).where((u) => u.mid > 0).toList();
  }
}
