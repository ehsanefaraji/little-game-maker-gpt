import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class GameAudio {
  GameAudio._();
  static final GameAudio instance = GameAudio._();
  final AudioPlayer _effects = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  bool _enabled = true;
  bool _musicEnabled = false;

  void configure({required bool sound, required bool music}) {
    _enabled = sound;
    _musicEnabled = music;
    if (!music) {
      _music.stop();
    } else {
      startMusic();
    }
  }

  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(BytesSource(_wave([
      [392, .24], [494, .24], [587, .48], [494, .24],
      [440, .24], [523, .48], [440, .24], [392, .48],
    ])));
  }

  Future<void> effect({int frequency = 660, int durationMs = 100}) async {
    if (!_enabled) return;
    await _effects.stop();
    await _effects.play(BytesSource(_tone(frequency, durationMs / 1000)));
  }

  Future<void> success() => effect(frequency: 880, durationMs: 240);
  Future<void> bump() => effect(frequency: 180, durationMs: 150);
  Future<void> collect() => effect(frequency: 1040, durationMs: 90);

  Uint8List _tone(int frequency, double seconds) {
    return _wave([[frequency, seconds]]);
  }

  Uint8List _wave(List<List<num>> notes) {
    const sampleRate = 22050;
    final samples = <int>[];
    for (var n = 0; n < notes.length; n++) {
      final frequency = notes[n][0].toDouble();
      final duration = notes[n][1].toDouble();
      final count = (sampleRate * duration).round();
      for (var i = 0; i < count; i++) {
        final envelope = math.min(1.0, math.min(i / 180, (count - i) / 350));
        final wave = math.sin(2 * math.pi * frequency * i / sampleRate);
        samples.add((wave * envelope * 9000).round());
      }
    }
    final dataSize = samples.length * 2;
    final bytes = ByteData(44 + dataSize);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
