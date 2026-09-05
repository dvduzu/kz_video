import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'bilibili_auth.dart';
import 'wbi_sign.dart';

class BilibiliClient {
  final Dio dio;
  final BilibiliAuth auth;

  BilibiliClient(this.dio) : auth = BilibiliAuth();

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

  String? _mixinKey;
  int _mixinFetchedAt = 0;

  bool _buvidReady = false;
  bool _buvidActivated = false;
  bool _biliTicketOk = false;
  int _biliTicketExpires = 0;

  Future<String> getMixinKey() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mixinKey == null || now - _mixinFetchedAt > 12 * 3600 * 1000) {
      await ensureBuvid();
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

  String _hmacSha256(String key, String message) => Hmac(sha256, utf8.encode(key)).convert(utf8.encode(message)).toString();

  String _hex(int len) {
    final r = Random();
    final b = List<int>.generate(len, (_) => r.nextInt(256));
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  String _genUuid() {
    const map = ['1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','10'];
    final r = Random();
    final sb = StringBuffer();
    final idx = [9,13,17,21];
    for (var i = 0; i < 32; i++) {
      if (idx.contains(i)) sb.write('-');
      sb.write(map[r.nextInt(16)]);
    }
    sb.write('${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}infoc');
    return sb.toString();
  }

  Future<void> ensureBuvid() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_buvidReady && _biliTicketOk && now < _biliTicketExpires) return;
    _buvidReady = false;
    final savedLogin = <String, String>{};
    final full = auth.fullCookies;
    if (full != null) {
      for (final k in ['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5']) {
        final v = full[k];
        if (v != null) savedLogin[k] = v;
      }
    }
    try {
      final spi = await dio.get('https://api.bilibili.com/x/frontend/finger/spi');
      final data = (spi.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final b3 = data['b_3'] as String? ?? '';
      final b4 = data['b_4'] as String? ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final cookies = <String, String>{
        'buvid3': b3,
        'buvid4': b4,
        'b_nut': '$ts',
        'b_lsid': '${_hex(32).toUpperCase()}_${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
        '_uuid': _genUuid(),
        'buvid_fp': _hex(16),
      };
      final hexSign = _hmacSha256('XgwSnGZ1p', 'ts$ts');
      try {
        final tick = await dio.post(
          'https://api.bilibili.com/bapis/bilibili.api.ticket.v1.Ticket/GenWebTicket',
          queryParameters: {'key_id': 'ec02', 'hexsign': hexSign, 'context[ts]': '$ts', 'csrf': ''},
        );
        final td = (tick.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
        final t = td?['ticket'] as String?;
        if (t != null && t.isNotEmpty) {
          cookies['bili_ticket'] = t;
          final created = (td?['created_at'] as int?) ?? ts;
          final ttl = (td?['ttl'] as int?) ?? 1800;
          _biliTicketExpires = created + ttl;
          _biliTicketOk = true;
        }
      } catch (e) {
        // ignore: avoid_print
        print('[kzv] bili_ticket failed: $e');
      }
      cookies.addAll(savedLogin);
      auth.setFullCookies(cookies);
      _buvidReady = true;
      if (!_buvidActivated) {
        _buvidActivated = true;
        await _activateBuvid();
      }
      // ignore: avoid_print
      print('[kzv] full cookies: ${cookies.keys.join(',')}');
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] ensureBuvid failed: $e');
    }
  }

  Future<void> _activateBuvid() async {
    try {
      final jsonData = jsonEncode({
        '3064': 1,
        '39c8': '333.1387.fp.risk',
        '3c43': {
          'adca': 'Linux',
          'bfe9': '${_hex(24)}IEND${_hex(4)}',
        },
      });
      await dio.post(
        '/x/internal/gaia-gateway/ExClimbWuzhi',
        data: {'payload': jsonData},
        options: Options(headers: auth.fullLoginHeaders()),
      );
      // ignore: avoid_print
      print('[kzv] buvid activated');
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] buvid activate failed: $e');
    }
  }

  Future<Map<String, dynamic>> wbiGet(String path, Map<String, dynamic> params) async {
    await ensureBuvid();
    final mixinKey = await getMixinKey();
    final signed = Map<String, dynamic>.from(params);
    WbiSign.sign(signed, mixinKey);
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