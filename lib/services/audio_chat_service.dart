import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioChatService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Stream pour l'état d'enregistrement
  final StreamController<bool> _recordingStateController = StreamController<bool>.broadcast();
  Stream<bool> get onRecordingStateChanged => _recordingStateController.stream;

  // Stream pour la progression de lecture
  final StreamController<Duration> _playerProgressController = StreamController<Duration>.broadcast();
  Stream<Duration> get onPlayerProgress => _playerProgressController.stream;

  // Stream pour l'état de lecture
  final StreamController<PlayerState> _playerStateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get onPlayerStateChanged => _playerStateController.stream;

  String? _currentlyPlayingUrl;
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;
  bool get isRecording => _isRecording;

  AudioChatService() {
    _audioPlayer.onPositionChanged.listen((pos) {
      _playerProgressController.add(pos);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _playerStateController.add(state);
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _currentlyPlayingUrl = null;
      }
    });
  }

  /// Demander les autorisations microphone
  Future<bool> checkAndRequestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Démarrer l'enregistrement vocal
  Future<bool> startRecording() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      print('[AudioChatService] Permission micro refusée');
      return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;
      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _recordingStateController.add(true);
      return true;
    } catch (e) {
      print('[AudioChatService] Erreur startRecording: $e');
      _isRecording = false;
      _recordingStateController.add(false);
      return false;
    }
  }

  /// Arrêter l'enregistrement vocal et retourner le fichier et la durée en secondes
  Future<({File? file, int durationSeconds})> stopRecording() async {
    if (!_isRecording) {
      return (file: null, durationSeconds: 0);
    }

    try {
      final path = await _audioRecorder.stop();
      final durationSeconds = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;

      _isRecording = false;
      _recordingStateController.add(false);
      _recordingStartTime = null;

      if (path != null && File(path).existsSync()) {
        return (file: File(path), durationSeconds: durationSeconds < 1 ? 1 : durationSeconds);
      }
    } catch (e) {
      print('[AudioChatService] Erreur stopRecording: $e');
      _isRecording = false;
      _recordingStateController.add(false);
    }
    return (file: null, durationSeconds: 0);
  }

  /// Annuler et supprimer l'enregistrement en cours
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStateController.add(false);
      _recordingStartTime = null;

      if (path != null) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (f.existsSync()) await f.delete();
      }
    } catch (e) {
      print('[AudioChatService] Erreur cancelRecording: $e');
    }
  }

  /// Jouer / Mettre en pause une note vocale depuis une URL ou un fichier local
  Future<void> togglePlay(String urlOrPath) async {
    try {
      if (_currentlyPlayingUrl == urlOrPath && _audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.pause();
      } else if (_currentlyPlayingUrl == urlOrPath && _audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.stop();
        _currentlyPlayingUrl = urlOrPath;
        if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
          await _audioPlayer.play(UrlSource(urlOrPath));
        } else {
          await _audioPlayer.play(DeviceFileSource(urlOrPath));
        }
      }
    } catch (e) {
      print('[AudioChatService] Erreur togglePlay: $e');
    }
  }

  /// Arrêter la lecture
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    _currentlyPlayingUrl = null;
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingStateController.close();
    _playerProgressController.close();
    _playerStateController.close();
  }
}
