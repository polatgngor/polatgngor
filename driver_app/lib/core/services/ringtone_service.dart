import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

part 'ringtone_service.g.dart';

@Riverpod(keepAlive: true)
RingtoneService ringtoneService(Ref ref) {
  return RingtoneService();
}

class RingtoneService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playRingtone() async {
    if (_isPlaying) return;

    try {
      // Ensure loud volume
      await _audioPlayer.setVolume(1.0);
      
      // Release mode: Loop the ringtone
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Force Audio Context (Android specific tuning)
      // This ensures we play even if media volume is weird, and we respect silent mode preferences if needed,
      // but for a "Ringtone" we want it audible.
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
           isSpeakerphoneOn: true,
           stayAwake: true,
           contentType: AndroidContentType.music,
           usageType: AndroidUsageType.notificationRingtone,
           audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
           category: AVAudioSessionCategory.playback,
           options: {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.mixWithOthers}, 
        ),
      ));

      // Play from assets
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      _isPlaying = true;
      debugPrint('Ringtone Playing... (Loop Mode)');
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  Future<void> stopRingtone() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }
}
