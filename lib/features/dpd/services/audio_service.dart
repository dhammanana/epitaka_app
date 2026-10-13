import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();

  static String buildUrl(String lemma, String gender) {
    final clean = lemma.replaceAll(RegExp(r' \d.*$', unicode: true), '');
    return 'https://dpdict.net/audio/${Uri.encodeComponent(clean)}?gender=$gender';
  }

  Future<bool> play(String lemma, String gender) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(buildUrl(lemma, gender)));
      return true;
    } catch (_) {
      return false;
    }
  }
}
