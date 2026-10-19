import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 声音：一声「啵」的点击音 + 两段笑声。总音量由设置里的滑杆控制。
class AudioService {
  final AudioPlayer _sfx = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _laugh = AudioPlayer(playerId: 'laugh');

  double _volume = 0.7;
  bool _ready = false;

  bool get isMuted => _volume <= 0;

  Future<void> init() async {
    try {
      await _sfx.setReleaseMode(ReleaseMode.stop);
      await _laugh.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (e) {
      debugPrint('audio init failed: $e');
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (!_ready) return;
    try {
      await _sfx.setVolume(_volume);
      await _laugh.setVolume(_volume);
    } catch (_) {}
  }

  /// 浏览器在用户手势前禁止出声，第一次点奶龙时用它解锁。
  Future<void> unlock() async {
    if (!_ready || kIsWeb == false) return;
    try {
      await _sfx.play(AssetSource('audio/tap.wav'), volume: 0);
      await _sfx.stop();
    } catch (_) {}
  }

  Future<void> tap() async {
    if (!_ready || _volume <= 0) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('audio/tap.wav'), volume: _volume);
    } catch (e) {
      debugPrint('tap sound failed: $e');
    }
  }

  Future<void> laugh({bool full = false}) async {
    if (!_ready || _volume <= 0) return;
    try {
      await _laugh.stop();
      await _laugh.play(
        AssetSource(full ? 'audio/laugh_full.mp3' : 'audio/laugh.mp3'),
        volume: _volume,
      );
    } catch (e) {
      debugPrint('laugh sound failed: $e');
    }
  }

  Future<void> stopLaugh() async {
    try {
      await _laugh.stop();
    } catch (_) {}
  }

  void dispose() {
    _sfx.dispose();
    _laugh.dispose();
  }
}
