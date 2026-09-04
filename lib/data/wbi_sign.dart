import 'dart:convert';
import 'package:crypto/crypto.dart';

class WbiSign {
  static const _mixinKeyEncTab = <int>[
    46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,
    33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,
    61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,
    36,20,34,44,52,
  ];
  static final _chrFilter = RegExp(r"[!\'\(\)\*]");

  static String getMixinKey(String orig) {
    final codeUnits = orig.codeUnits;
    return String.fromCharCodes(_mixinKeyEncTab.map((i) => codeUnits[i]));
  }

  static void sign(Map<String, dynamic> params, String mixinKey) {
    params['wts'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final keys = params.keys.toList()..sort();
    final queryStr = keys.map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k].toString().replaceAll(_chrFilter, ''))}').join('&');
    params['w_rid'] = md5.convert(utf8.encode(queryStr + mixinKey)).toString();
  }
}
