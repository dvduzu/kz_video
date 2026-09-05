import 'package:dio/dio.dart';
import 'wbi_sign.dart';

class WbiService {
  final Dio dio;

  WbiService(this.dio);

  String? _mixinKey;
  int _mixinFetchedAt = 0;

  Future<String> getMixinKey() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mixinKey == null || now - _mixinFetchedAt > 12 * 3600 * 1000) {
      final resp = await dio.get('/x/web-interface/nav');
      final wbiImg = resp.data['data']?['wbi_img'];
      final imgUrl = wbiImg?['img_url'] as String? ?? '';
      final subUrl = wbiImg?['sub_url'] as String? ?? '';
      final imgKey = imgUrl.split('/').last.split('.').first;
      final subKey = subUrl.split('/').last.split('.').first;
      if (imgKey.isEmpty || subKey.isEmpty) throw Exception('WBI key empty');
      _mixinKey = WbiSign.getMixinKey(imgKey + subKey);
      _mixinFetchedAt = now;
    }
    return _mixinKey!;
  }

  Future<Map<String, dynamic>> sign(Map<String, dynamic> params) async {
    final signed = Map<String, dynamic>.from(params);
    WbiSign.sign(signed, await getMixinKey());
    return signed;
  }
}