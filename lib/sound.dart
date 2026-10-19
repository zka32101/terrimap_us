import 'package:audioplayers/audioplayers.dart';

/// 効果音とBGM。テストでは何もしない [NoopSound] を使う。
abstract class Sound {
  const Sound();
  Future<void> play(String name); // assets/sound/<name>.wav
  Future<void> setBgm(bool on);
}

class NoopSound extends Sound {
  const NoopSound();
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> setBgm(bool on) async {}
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
  Future<void> setBgm(bool on) async {
    try {
      on ? await _bgm.play(AssetSource('sound/bgm.wav')) : await _bgm.stop();
    } catch (_) {}
  }
}
