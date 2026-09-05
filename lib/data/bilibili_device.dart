import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'bilibili_auth.dart';
import '../core/logger.dart';

class BilibiliDevice {
  final Dio dio;
  final BilibiliAuth auth;

  BilibiliDevice(this.dio, this.auth);

  bool _buvidReady = false;
  bool _buvidActivated = false;
  bool _biliTicketOk = false;
  int _biliTicketExpires = 0;

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
        KzvLogger.debug('bili_ticket failed: $e');
      }
      cookies.addAll(savedLogin);
      auth.setFullCookies(cookies);
      _buvidReady = true;
      if (!_buvidActivated) {
        _buvidActivated = true;
        await _activateBuvid();
      }
      KzvLogger.debug('buvid ready (${cookies.length} cookies)');
    } catch (e) {
      KzvLogger.debug('ensureBuvid failed: $e');
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
      KzvLogger.debug('buvid activated');
    } catch (e) {
      KzvLogger.debug('buvid activate failed: $e');
    }
  }
}