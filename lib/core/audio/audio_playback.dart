import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Plays synthesised speech audio. Writes the TTS bytes to a temp file and
/// plays them back, completing only when playback finishes so the caller can
/// keep the mic muted for the whole spoken segment (echo avoidance).
class AudioPlayback {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playBytes(Uint8List bytes, {required String format}) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'jarvis_tts_${DateTime.now().millisecondsSinceEpoch}.$format'),
    );
    await file.writeAsBytes(bytes, flush: true);

    await _player.play(DeviceFileSource(file.path));
    await _player.onPlayerComplete.first;
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
