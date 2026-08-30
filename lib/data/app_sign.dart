import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart';

abstract final class AppSign {
  static const appKey = 'dfca71928277209b';
  static const appSec = 'b5475a8825547a4fc26c7d518eaaa02e';

  static void appSign(Map<String, dynamic> params, {String appkey = appKey, String appsec = appSec}) {
    params['appkey'] = appkey;
    params['ts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sorted = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    params['sign'] = md5.convert(utf8.encode(_makeQuery(sorted) + appsec)).toString();
  }

  static String _makeQuery(List<MapEntry<String, dynamic>> params) {
    final result = StringBuffer();
    var sep = '';
    for (final i in params) {
      result.write(sep);
      sep = '&';
      result.write(Uri.encodeComponent(i.key));
      final v = i.value?.toString();
      if (v != null && v.isNotEmpty) {
        result.write('=');
        result.write(Uri.encodeComponent(v));
      }
    }
    return result.toString();
  }
}