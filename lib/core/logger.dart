import 'package:flutter/foundation.dart';

class KzvLogger {
  static const bool _debugEnabled = kDebugMode;

  static void debug(String msg) {
    if (_debugEnabled) debugPrint('[kzv] $msg');
  }

  static void info(String msg) {
    if (_debugEnabled) debugPrint('[kzv] $msg');
  }

  static void warning(String msg) {
    debugPrint('[kzv][warn] $msg');
  }

  static void error(String msg) {
    debugPrint('[kzv][error] $msg');
  }
}