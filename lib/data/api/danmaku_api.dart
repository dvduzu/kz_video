import '../api_endpoints.dart';
import '../bilibili_constants.dart';
import '../dm_grpc.dart';
import '../models.dart';
import '../../core/logger.dart';
import 'api_base.dart';

class DanmakuApi extends ApiBase {
  final DmGrpc _dmGrpc;
  DanmakuApi(super.client) : _dmGrpc = DmGrpc(DmGrpc.createDio());

  Future<List<DanmakuItem>> getDanmaku(String bvid, {int durationSec = 0}) async {
    try {
      final view = await wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final cid = view['data']?['cid'];
      if (cid == null) return [];
      final segCount = durationSec > 0 ? ((durationSec / 360).ceil() + 1).clamp(1, 30) : 20;
      final headers = <String, String>{
        'User-Agent': BiliConstants.appUserAgent,
        ...client.auth.requestHeaders(),
      };
      final segs = List<int>.generate(segCount, (i) => i + 1);
      final results = await _mapLimited(segs, 4, (seg) => _fetchSeg(cid as int, seg, headers));
      final all = results.expand((e) => e).toList();
      all.sort((a, b) => a.time.compareTo(b.time));
      KzvLogger.debug('danmaku cid=$cid segs=$segCount count=${all.length}');
      return all;
    } catch (e) {
      KzvLogger.debug('getDanmaku failed: $e');
      return [];
    }
  }

  Future<List<T>> _mapLimited<S, T>(List<S> items, int limit, Future<T> Function(S) fn) async {
    final results = <T>[];
    for (var i = 0; i < items.length; i += limit) {
      final end = (i + limit).clamp(0, items.length);
      results.addAll(await Future.wait(items.sublist(i, end).map(fn)));
    }
    return results;
  }

  Future<List<DanmakuItem>> _fetchSeg(int cid, int seg, Map<String, String> headers) async {
    try {
      return await _dmGrpc.segMobile(cid, seg, headers: headers);
    } catch (e) {
      KzvLogger.debug('danmaku grpc seg=$seg failed: $e');
      return [];
    }
  }
}
