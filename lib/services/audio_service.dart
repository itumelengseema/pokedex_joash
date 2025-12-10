import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';


/// FIX #13: Prevents multiple AudioService instances
/// FIX #16: Proper state management for theme music with ChangeNotifier
/// FIX #10, #11: Evolution chain sound and theme song glitches resolved
class AudioService extends ChangeNotifier {
  // Singleton pattern (fixes #13 - Multiple AudioService Instances)
  static AudioService? _instance;

  static AudioService get instance {
    _instance ??= AudioService._internal();
    return _instance!;
  }

  // Private constructor
  AudioService._internal() {
    _initializeListeners();
  }

  // Separate audio players for theme and sound effects
  final AudioPlayer _themePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // State management (fixes #16 - State Not Updated After Theme Music Playback Changes)
  bool _isThemePlaying = false;
  bool _isSfxPlaying = false;
  bool _isMuted = false;
  double _volume = 0.5;

  // Getters
  bool get isThemePlaying => _isThemePlaying;
  bool get isSfxPlaying => _isSfxPlaying;
  bool get isMuted => _isMuted;
  double get volume => _volume;

  /// Initialize player state listeners
  void _initializeListeners() {
    _themePlayer.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isThemePlaying;
      _isThemePlaying = state == PlayerState.playing;

      // Only notify if state actually changed
      if (wasPlaying != _isThemePlaying) {
        notifyListeners();
      }
    });

    _sfxPlayer.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isSfxPlaying;
      _isSfxPlaying = state == PlayerState.playing;

      // Only notify if state actually changed
      if (wasPlaying != _isSfxPlaying) {
        notifyListeners();
      }
    });

    // Listen for completion to update state
    _themePlayer.onPlayerComplete.listen((_) {
      _isThemePlaying = false;
      notifyListeners();
    });
  }

  /// Play Pokemon theme music (looping)
  /// FIX #11: Proper error handling prevents theme song glitches
  Future<void> playThemeMusic() async {
    if (_isMuted) return;

    try {
      await _themePlayer.stop();
      await _themePlayer.setVolume(_volume);
      await _themePlayer.setReleaseMode(ReleaseMode.loop);
      await _themePlayer.play(AssetSource(AppConstants.themeMusicPath));

      _isThemePlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing theme music: $e');
      _isThemePlaying = false;
      notifyListeners();
    }
  }

  /// Stop theme music
  Future<void> stopThemeMusic() async {
    try {
      await _themePlayer.stop();
      _isThemePlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping theme music: $e');
    }
  }

  /// Pause theme music
  Future<void> pauseThemeMusic() async {
    try {
      await _themePlayer.pause();
      _isThemePlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing theme music: $e');
    }
  }

  /// Resume theme music
  Future<void> resumeThemeMusic() async {
    if (_isMuted) return;

    try {
      await _themePlayer.resume();
      _isThemePlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming theme music: $e');
    }
  }

  /// Play sound effect (evolution, click, etc.)
  /// FIX #10: Proper error handling for evolution chain sound
  Future<void> playSoundEffect(String assetPath) async {
    if (_isMuted) return;

    try {
      // Stop any currently playing sound effect
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_volume);
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound effect: $e');
    }
  }

  /// Play evolution sound
  Future<void> playEvolutionSound() async {
    await playSoundEffect(AppConstants.evolutionSoundPath);
  }

  /// Play click sound
  Future<void> playClickSound() async {
    await playSoundEffect(AppConstants.clickSoundPath);
  }

  /// Toggle mute/unmute
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;

    if (_isMuted) {
      await _themePlayer.setVolume(0);
      await _sfxPlayer.setVolume(0);
    } else {
      await _themePlayer.setVolume(_volume);
      await _sfxPlayer.setVolume(_volume);
    }

    notifyListeners();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    if (!_isMuted) {
      await _themePlayer.setVolume(_volume);
      await _sfxPlayer.setVolume(_volume);
    }

    notifyListeners();
  }

  /// Reset audio service (useful for testing)
  Future<void> reset() async {
    await stopThemeMusic();
    await _sfxPlayer.stop();
    _isMuted = false;
    _volume = 0.5;
    notifyListeners();
  }

  /// Dispose audio players
  @override
  void dispose() {
    _themePlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }
}
