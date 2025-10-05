import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:volume_controller/volume_controller.dart';

import 'models.dart';
import 'denon_cast.dart';

class PlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Track? _currentTrack;
  List<Track> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;

  // Casting
  final DenonCast _cast = DenonCast();
  bool _isCasting = false;

  // Volume (ampli)
  int _currentVolume = 50;
  late final VolumeController _volumeController;

  // Streams pour la timeline côté cast (polling UPnP)
  final _castPosController = StreamController<Duration>.broadcast();
  final _castDurController = StreamController<Duration?>.broadcast();
  Timer? _castPollTimer;

  // 🔹 Nouveau flag : savoir si l’utilisateur a mis pause volontairement
  bool _userPaused = false;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isCasting => _isCasting;
  int get currentVolume => _currentVolume;

  // Streams (local)
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // Streams (cast)
  Stream<Duration> get castPositionStream => _castPosController.stream;
  Stream<Duration?> get castDurationStream => _castDurController.stream;

  PlayerService() {
    _player.playingStream.listen((playing) {
      if (!_isCasting) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _player.processingStateStream.listen((state) async {
      if (_isCasting) return;
      if (state == ProcessingState.completed) {
        next();
      }
    });

    // ✅ Correctifs anti-arrêt intempestif

    // A) Auto-reprise si la lecture s’arrête toute seule avant la fin
    _player.playerStateStream.listen((s) async {
      if (_isCasting) return;

      if (s.processingState == ProcessingState.ready && !s.playing) {
        // Si l'utilisateur n'a pas mis pause et que la piste n'est pas terminée
        final dur = _player.duration;
        final pos = _player.position;
        if (!_userPaused &&
            dur != null &&
            pos < dur - const Duration(seconds: 2)) {
          try {
            await _player.play();
            _isPlaying = true;
            notifyListeners();
          } catch (_) {
            // si erreur, le listener B gérera
          }
        }
      }
    });

    // B) Auto-recovery en cas d'erreur (réseau, micro-coupure)
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) async {
        if (_isCasting) return;
        final t = _currentTrack;
        if (t == null) return;
        final pos = _player.position;
        try {
          await _player.setUrl(t.url);
          await _player.seek(pos);
          if (!_userPaused) {
            await _player.play();
            _isPlaying = true;
            notifyListeners();
          }
        } catch (_) {
          // si la ressource est vraiment indisponible, on reste en pause
        }
      },
    );

    // init volume controller
    _volumeController = VolumeController();
    _volumeController.listener((volume) async {
      if (_isCasting) {
        // volume est un double 0.0 – 1.0 → on convertit en 0–100
        final vol = (volume * 100).round();
        await setVolume(vol);
      }
    });
  }

  Future<List<DenonDevice>> discoverDevices() async {
    return await _cast.discoverAll();
  }

  Future<void> enableCasting(DenonDevice device) async {
    await _cast.connect(device);
    _isCasting = true;
    if (_player.playing) await _player.pause();
    notifyListeners();

    // Volume initial depuis l’ampli
    final vol = await _cast.getVolume();
    if (vol != null) {
      _currentVolume = vol;
      notifyListeners();
    }

    // Démarre polling (position + état lecture)
    _startCastPolling();

    // ⚡ Si une piste est déjà en cours → reprendre à la bonne position
    if (_currentTrack != null) {
      final pos = await _player.position;
      await _cast.playUrl(_currentTrack!.url, startPosition: pos);
      _isPlaying = true;
      notifyListeners();
    }
  }

  // Désactive le casting
  Future<void> disableCasting() async {
    if (_isCasting) {
      _isCasting = false;
      _stopCastPolling();
      notifyListeners();
      if (_currentTrack != null) {
        await _player.setUrl(_currentTrack!.url);
      }
    }
  }

  // Joue une piste spécifique dans une playlist
  Future<void> playList(List<Track> tracks, int index) async {
    _playlist = tracks;
    _currentIndex = index;
    _currentTrack = _playlist[_currentIndex];
    _userPaused = false; // 🔹 reset

    if (_isCasting && _cast.isReady) {
      await _cast.playUrl(_currentTrack!.url, startPosition: Duration.zero);
      _isPlaying = true;
      notifyListeners();
      return;
    }

    await _player.setUrl(_currentTrack!.url);
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  // Bascule entre lecture et pause
  Future<void> togglePlayPause() async {
    if (_isCasting && _cast.isReady) {
      if (_isPlaying) {
        await _cast.pause();
        _isPlaying = false;
        _userPaused = true; // 🔹 ajouté
      } else {
        await _cast.play();
        _isPlaying = true;
        _userPaused = false; // 🔹 ajouté
      }
      notifyListeners();
      return;
    }

    if (_player.playing) {
      await _player.pause();
      _isPlaying = false;
      _userPaused = true; // 🔹 ajouté
    } else {
      await _player.play();
      _isPlaying = true;
      _userPaused = false; // 🔹 ajouté
    }
    notifyListeners();
  }

  // Passe à la piste précédente dans la playlist
  Future<void> previous() async {
    if (_playlist.isNotEmpty && _currentIndex > 0) {
      await playList(_playlist, _currentIndex - 1);
    }
  }

  // Passe à la piste suivante dans la playlist
  Future<void> next() async {
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      await playList(_playlist, _currentIndex + 1);
    }
  }

  Future<void> seek(Duration position) async {
    if (_isCasting) {
      await _cast.seek(position);
      return;
    }
    await _player.seek(position);
  }

  // Modifie le volume de l’ampli (0–100)
  Future<void> setVolume(int vol) async {
    if (_isCasting) {
      _currentVolume = vol.clamp(0, 100);
      notifyListeners();
      await _cast.setVolume(_currentVolume);
    }
  }

  // Active/désactive le mute de l’ampli
  Future<void> mute(bool enable) async {
    if (_isCasting) {
      await _cast.setMute(enable);
    }
  }

  // Récupère l’état mute de l’ampli (null si non casting)
  Future<bool?> isMuted() async {
    if (_isCasting) {
      return await _cast.getMute();
    }
    return null;
  }

  void _startCastPolling() {
    _castPollTimer?.cancel();
    _castPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // --- Position & durée ---
      final info = await _cast.getPositionInfo();
      if (info != null) {
        _castPosController.add(info.position);
        _castDurController.add(info.duration);
      }

      // --- État lecture (Play/Pause) ---
      final state = await _cast.getTransportState();
      if (state != null) {
        final isNowPlaying = state.toUpperCase() == "PLAYING";
        if (_isPlaying != isNowPlaying) {
          _isPlaying = isNowPlaying;
          notifyListeners();
        }
      }
    });
  }

  void _stopCastPolling() {
    _castPollTimer?.cancel();
    _castPollTimer = null;
  }

  @override
  void dispose() {
    _stopCastPolling();
    _castPosController.close();
    _castDurController.close();
    _volumeController.removeListener();
    _player.dispose();
    super.dispose();
  }
}
