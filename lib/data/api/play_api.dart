import '../api_exception.dart';
import '../api_endpoints.dart';
import 'api_base.dart';

class PlayApi extends ApiBase {
  PlayApi(super.client);

  Future<({String videoUrl, String? audioUrl})> getPlayUrl(String bvid, {int? qn}) async {
    final viewData = await wbiGet(ApiEndpoints.view, {'bvid': bvid});
    final cid = viewData['data']?['cid'];
    if (cid == null) throw const BilibiliApiException('获取视频信息失败', path: ApiEndpoints.view);
    final target = qn ?? 80;
    final errors = <String>[];
    for (final fnval in [4048, 16]) {
      try {
        final playData = await wbiGet(ApiEndpoints.playUrl, {
          'bvid': bvid,
          'cid': cid,
          'qn': target,
          'fnval': fnval,
          'fnver': 0,
          'fourk': 1,
          'try_look': 1,
          'web_location': 1315873,
          ...dmImgParams(),
        });
        final data = playData['data'] as Map<String, dynamic>?;
        final dash = data?['dash'] as Map<String, dynamic>?;
        if (dash != null) {
          final videos = (dash['video'] as List?) ?? [];
          final audios = (dash['audio'] as List?) ?? [];
          if (videos.isNotEmpty) {
            Map<String, dynamic>? chosen;
            for (final v in videos.cast<Map<String, dynamic>>()) {
              if (v['id'] == target) { chosen = v; break; }
            }
            chosen ??= videos.first as Map<String, dynamic>;
            final vUrl = _pickStreamUrl(chosen);
            final aUrl = audios.isNotEmpty ? _pickStreamUrl(audios.first as Map<String, dynamic>) : null;
            if (vUrl != null && vUrl.isNotEmpty) {
              return (videoUrl: vUrl, audioUrl: aUrl);
            }
          }
        }
        final durl = data?['durl'] as List?;
        if (durl != null && durl.isNotEmpty) {
          final u = (durl.first as Map<String, dynamic>)['url'] as String?;
          if (u != null && u.isNotEmpty) return (videoUrl: u, audioUrl: null);
        }
      } catch (e) {
        errors.add('fnval=$fnval: $e');
      }
    }
    throw BilibiliApiException('获取播放地址失败：${errors.join(' | ')}', path: ApiEndpoints.playUrl);
  }

  String? _pickStreamUrl(Map<String, dynamic> track) {
    final base = (track['baseUrl'] ?? track['base_url']) as String?;
    final backups = ((track['backupUrl'] ?? track['backup_url']) as List?)?.whereType<String>().toList() ?? const <String>[];
    final candidates = <String>[
      if (base != null && base.isNotEmpty) base,
      ...backups.where((s) => s.isNotEmpty),
    ];
    if (candidates.isEmpty) return null;
    final upos = candidates.where((u) => u.contains('upos') && u.contains('bilivideo.com'));
    if (upos.isNotEmpty) return upos.first;
    final nonMcdn = candidates.where((u) => !u.contains('mcdn'));
    if (nonMcdn.isNotEmpty) return nonMcdn.first;
    return candidates.first;
  }
}
