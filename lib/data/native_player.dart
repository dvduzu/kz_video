import 'dart:async';
import 'package:flutter/services.dart';
import '../core/logger.dart';

class _PlayerStreams {
  final playingCtrl = StreamController<bool>.broadcast();
  final positionCtrl = StreamController<Duration>.broadcast();
  final durationCtrl = StreamController<Duration>.broadcast();
  final completedCtrl = StreamController<void>.broadcast();
  final errorCtrl = StreamController<Object?>.broadcast();

  Stream<bool> get playing => playingCtrl.stream;
  Stream<Duration> get position => positionCtrl.stream;
  Stream<Duration> get duration => durationCtrl.stream;
  Stream<void> get completed => completedCtrl.stream;
  Stream<Object?> get error => errorCtrl.stream;
}

class _PlayerState {
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  bool buffering = false;
  int videoWidth = 0;
  int videoHeight = 0;
}

class NativePlayer {
  static const _method = MethodChannel('kz/exoplayer');
  static const _events = EventChannel('kz/exoplayer/events');

  static NativePlayer? _instance;
  static NativePlayer get instance => _instance ??= NativePlayer._();
  NativePlayer._();

  final _PlayerStreams stream = _PlayerStreams();
  final _PlayerState state = _PlayerState();
  StreamSubscription<dynamic>? _sub;
  bool _endedEmitted = false;
  int? _textureId;

  int? get textureId => _textureId;

  double get aspectRatio {
    final w = state.videoWidth;
    final h = state.videoHeight;
    return (w > 0 && h > 0) ? w / h : 16 / 9;
  }

  Future<void> loadTextureId() async {
    if (_textureId != null) return;
    try {
      _textureId = await _method.invokeMethod<int>('textureId');
    } catch (e) {
      KzvLogger.debug('load textureId failed: $e');
    }
  }

  void _ensureSubscribed() {
    _sub ??= _events.receiveBroadcastStream().listen(_onEvent, onError: (e) {
      stream.errorCtrl.add(e);
    });
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    if (event['event'] == 'error') {
      stream.errorCtrl.add(event['message']);
      return;
    }
    final playing = event['playing'] == true;
    final pos = Duration(milliseconds: (event['position'] as num?)?.toInt() ?? 0);
    final dur = Duration(milliseconds: (event['duration'] as num?)?.toInt() ?? 0);
    final buffering = event['buffering'] == true;
    state.position = pos;
    state.duration = dur;
    state.playing = playing;
    state.buffering = buffering;
    state.videoWidth = (event['videoWidth'] as num?)?.toInt() ?? state.videoWidth;
    state.videoHeight = (event['videoHeight'] as num?)?.toInt() ?? state.videoHeight;
    stream.positionCtrl.add(pos);
    stream.durationCtrl.add(dur);
    stream.playingCtrl.add(playing);
    if (event['ended'] == true) {
      if (!_endedEmitted) {
        _endedEmitted = true;
        stream.completedCtrl.add(null);
      }
    } else {
      _endedEmitted = false;
    }
  }

  Future<void> open(String url, {String? audio, Map<String, String>? headers, String? title, String? artist, String? artwork}) async {
    _ensureSubscribed();
    await loadTextureId();
    await _method.invokeMethod('setUrl', {
      'url': url,
      'audioUrl': audio,
      'headers': headers ?? <String, String>{},
      'title': title,
      'artist': artist,
      'artwork': artwork,
    });
  }

  Future<void> play() => _method.invokeMethod('play');
  Future<void> pause() => _method.invokeMethod('pause');
  Future<void> stop() => _method.invokeMethod('stop');
  Future<void> seek(Duration position) => _method.invokeMethod('seek', {'position': position.inMilliseconds});
  Future<void> setRate(double rate) => _method.invokeMethod('setRate', {'rate': rate});
  Future<void> dispose() async {
    await _method.invokeMethod('stop');
    await _sub?.cancel();
    _sub = null;
  }
}
