import 'package:audioplayers/audioplayers.dart';

/// 効果音とBGM。テストでは何もしない [NoopSound] を使う。
abstract class Sound {
  const Sound();
  Future<void> play(String name); // assets/sound/<name>.wav
  Future<void> setBgm(bool on, {String track = 'bgm'}); // track: bgm / boss
}

class NoopSound extends Sound {
  const NoopSound();
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> setBgm(bool on, {String track = 'bgm'}) async {}
}

/// 実機用。音が出せない端末でもアプリは止めない。
class PlayerSound extends Sound {
  final AudioPlayer _bgm = AudioPlayer();
  PlayerSound() {
    _bgm.setReleaseMode(ReleaseMode.loop);
    _bgm.setVolume(0.35);
  }

  @override
  Future<void> play(String name) async {
    try {
      await AudioPlayer().play(AssetSource('sound/$name.wav'), volume: 0.8);
    } catch (_) {}
  }

  @override
  Future<void> setBgm(bool on, {String track = 'bgm'}) async {
    try {
      on ? await _bgm.play(AssetSource('sound/$track.wav')) : await _bgm.stop();
    } catch (_) {}
  }
}

/// 同じ効果音を短い間に何度も鳴らさないための間引き(撃破が続いても、プレイヤーを増やしすぎない)。
class SfxThrottle {
  final Map<String, Duration> minGap;
  final Map<String, DateTime> _last = {};
  SfxThrottle({this.minGap = const {'kill': Duration(milliseconds: 140), 'breach': Duration(milliseconds: 300), 'boss_appear': Duration(seconds: 2)}});

  /// いま鳴らしてよいか。鳴らしてよければ、鳴らした時刻として覚える。
  bool allow(String name, DateTime now) {
    final gap = minGap[name] ?? Duration.zero;
    final last = _last[name];
    if (last != null && now.difference(last) < gap) return false;
    _last[name] = now;
    return true;
  }
}
