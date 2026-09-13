import '../api_endpoints.dart';
import '../models.dart';
import '../../core/logger.dart';
import 'api_base.dart';

class SubtitleApi extends ApiBase {
  SubtitleApi(super.client);

  Future<List<SubtitleCue>?> getSubtitles(String bvid) async {
    try {
      final viewData = await wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final cid = viewData['data']?['cid'];
      if (cid == null) return null;
      final playData = await wbiGet(ApiEndpoints.playV2, {'bvid': bvid, 'cid': cid, 'fnval': 16});
      final subtitle = playData['data']?['subtitle'] as Map<String, dynamic>?;
      final list = subtitle?['subtitles'] as List? ?? [];
      Map<String, dynamic>? zh;
      for (final s in list.cast<Map<String, dynamic>>()) {
        final lan = (s['lan'] as String?) ?? '';
        if (lan.contains('zh')) { zh = s; break; }
      }
      zh ??= list.isNotEmpty ? list.first as Map<String, dynamic> : null;
      if (zh == null) return null;
      final url = (zh['subtitle_url'] as String?) ?? '';
      if (url.isEmpty) return null;
      final resp = await dio.get('https:$url');
      final body = (resp.data as Map<String, dynamic>?)?['body'] as List? ?? [];
      return body.map((e) {
        final m = e as Map<String, dynamic>;
        return SubtitleCue(
          from: (m['from'] as num).toDouble(),
          to: (m['to'] as num).toDouble(),
          content: (m['content'] as String).trim(),
        );
      }).toList();
    } catch (e) {
      KzvLogger.debug('getSubtitles failed: $e');
      return null;
    }
  }
}
