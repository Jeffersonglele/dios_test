import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../services/chat_api_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swirling_loader.dart';

// ═══════════════════════════════════════════════════════════════
// Textes propres à cet écran (à migrer vers vos fichiers l10n si besoin)
// ═══════════════════════════════════════════════════════════════
class _T {
  static const camera = 'Appareil photo';
  static const gallery = 'Galerie';
  static const recording = 'Enregistrement…';
  static const micDenied = 'Autorisez le micro pour envoyer des notes vocales.';
  static const cameraDenied = 'Autorisez la caméra pour prendre une photo.';
  static const settings = 'Réglages';
  static const sendFailed = "Échec de l'envoi. Réessayez.";
  static const loadFailed = 'Impossible de charger la conversation.';
  static const retry = 'Réessayer';
  static const photo = 'Photo';
  static const voice = 'Message vocal';
}

// ═══════════════════════════════════════════════════════════════
// Couleurs (thème clair / sombre)
// ═══════════════════════════════════════════════════════════════
class _C {
  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  static Color get warm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  static Color get card =>
      AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get muted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  static Color get subtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  static Color get error =>
      AppColors.resolve(AppColors.error, AppDarkColors.error);
}

// ═══════════════════════════════════════════════════════════════
// ADAPTATEURS — seul endroit qui connaît la forme exacte de vos services.
// Si votre SocketService / Message diffère, ne modifiez que ce bloc.
// ═══════════════════════════════════════════════════════════════

/// Lit un champ d'une réponse (Map ou objet) sans planter.
dynamic _read(dynamic res, String key) {
  if (res == null) return null;
  if (res is Map) return res[key];
  try {
    switch (key) {
      case 'url':
        return res.url;
      case 'mimeType':
        return res.mimeType;
      case 'size':
        return res.size;
    }
  } catch (_) {}
  return null;
}

/// Convertit un `Message` (objet ou Map) en Map, quelle que soit sa forme.
Map<String, dynamic> _toMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  try {
    final m = raw.toJson();
    if (m is Map) return Map<String, dynamic>.from(m);
  } catch (_) {}
  try {
    final m = raw.toMap();
    if (m is Map) return Map<String, dynamic>.from(m);
  } catch (_) {}
  final out = <String, dynamic>{};
  void t(String k, dynamic Function() f) {
    try {
      final v = f();
      if (v != null) out[k] = v;
    } catch (_) {}
  }

  t('id', () => raw.id);
  t('orderId', () => raw.orderId);
  t('fromUserId', () => raw.fromUserId);
  t('text', () => raw.text);
  t('messageType', () => raw.messageType);
  t('mediaUrl', () => raw.mediaUrl);
  t('mediaDuration', () => raw.mediaDuration);
  t('createdAt', () => raw.createdAt);
  return out;
}

/// Transport temps réel (Socket.io) — branché sur `SocketService.instance`.
class _ChatTransport {
  _ChatTransport(this.orderId);
  final int orderId;

  dynamic get _socket {
    final dynamic svc = SocketService();
    try {
      final s = svc.socket;
      if (s != null) return s;
    } catch (_) {}
    return svc;
  }

  void connect() {
    final dynamic svc = SocketService();
    try {
      svc.connect();
    } catch (_) {}
    try {
      if (_socket.connected != true) _socket.connect();
    } catch (_) {}
  }

  void on(String event, dynamic Function(dynamic) handler) {
    try {
      _socket.on(event, handler);
    } catch (_) {}
  }

  void off(String event, dynamic Function(dynamic) handler) {
    try {
      _socket.off(event, handler);
    } catch (_) {}
  }

  void emit(String event, Map<String, dynamic> payload) {
    _socket.emit(event, payload);
  }

  void join() => emit('join_order_chat', {'orderId': orderId});
  void leave() => emit('leave_order_chat', {'orderId': orderId});

  void sendMessage({
    required String text,
    required String messageType,
    String? mediaUrl,
    int? mediaDuration,
    String? mediaMimeType,
    int? mediaSize,
  }) {
    emit('send_message', {
      'orderId': orderId,
      'text': text,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'mediaDuration': mediaDuration,
      'mediaMimeType': mediaMimeType,
      'mediaSize': mediaSize,
    });
  }
}

// ═══════════════════════════════════════════════════════════════
// Modèle d'affichage
// ═══════════════════════════════════════════════════════════════
class _ChatMsg {
  _ChatMsg({
    this.id,
    required this.localId,
    required this.fromUserId,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.localPath,
    this.durationSec,
    required this.createdAt,
    this.local = false,
    this.uploading = false,
  });

  final String? id;
  final String localId;
  final int fromUserId;
  final String type; // TEXT | IMAGE | AUDIO
  final String text;
  final String? mediaUrl;
  final String? localPath;
  final int? durationSec;
  final DateTime createdAt;
  final bool local; // message créé ici, en attente de l'écho serveur
  final bool uploading;

  String get key => id ?? localId;

  _ChatMsg copyWith({bool? uploading}) => _ChatMsg(
        id: id,
        localId: localId,
        fromUserId: fromUserId,
        type: type,
        text: text,
        mediaUrl: mediaUrl,
        localPath: localPath,
        durationSec: durationSec,
        createdAt: createdAt,
        local: local,
        uploading: uploading ?? this.uploading,
      );

  static int _int(dynamic v, [int d = 0]) =>
      v == null ? d : (int.tryParse(v.toString()) ?? d);

  static DateTime _date(dynamic v) {
    if (v is DateTime) return v.toLocal();
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v < 100000000000 ? v * 1000 : v);
    }
    if (v is String) return (DateTime.tryParse(v) ?? DateTime.now()).toLocal();
    return DateTime.now();
  }

  factory _ChatMsg.from(dynamic raw) {
    final m = _toMap(raw);
    final from = m['fromUserId'] ?? m['fromUserID'] ?? m['senderId'];
    final type = (m['messageType'] ?? m['type'] ?? 'TEXT').toString();
    final url = m['mediaUrl']?.toString();
    final dur = m['mediaDuration'];
    final id = m['id']?.toString();
    return _ChatMsg(
      id: id,
      localId: id ?? 'srv_${DateTime.now().microsecondsSinceEpoch}',
      fromUserId: _int(from),
      type: type.toUpperCase(),
      text: (m['text'] ?? m['content'] ?? '').toString(),
      mediaUrl: (url == null || url.isEmpty || url == 'null') ? null : url,
      durationSec: dur == null ? null : _int(dur),
      createdAt: _date(m['createdAt'] ?? m['timestamp']),
    );
  }
}

class _AudioState {
  const _AudioState({
    this.id,
    this.playing = false,
    this.position = Duration.zero,
    this.total,
  });
  final String? id;
  final bool playing;
  final Duration position;
  final Duration? total;
}

// ═══════════════════════════════════════════════════════════════
// ChatScreen
// ═══════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final int orderId;
  final String recipientName;
  final String? recipientRole;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.recipientName,
    this.recipientRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  // données
  final List<_ChatMsg> _msgs = [];
  int _myUserId = 0;
  bool _loading = true;
  bool _loadFailed = false;

  // saisie
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  // socket
  late final _ChatTransport _socket;
  late final dynamic Function(dynamic) _onNewMessage = _handleNewMessage;
  late final dynamic Function(dynamic) _onConnect = _handleConnect;

  // audio (lecture)
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<_AudioState> _audio =
      ValueNotifier(const _AudioState());
  final List<StreamSubscription<dynamic>> _subs = [];

  // audio (enregistrement)
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  String? _recordPath;
  final Stopwatch _recWatch = Stopwatch();
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final _picker = ImagePicker();
  int _localCounter = 0;

  @override
  void initState() {
    super.initState();
    _socket = _ChatTransport(widget.orderId);
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _initAudioPlayer();
    _init();
  }

  @override
  void dispose() {
    try {
      _socket.leave();
    } catch (_) {}
    _socket.off('new_message', _onNewMessage);
    _socket.off('connect', _onConnect);
    for (final s in _subs) {
      s.cancel();
    }
    _player.stop();
    _player.dispose();
    _recTimer?.cancel();
    _pulse.dispose();
    () async {
      try {
        if (_recording) await _recorder.cancel();
        await _recorder.dispose();
      } catch (_) {}
    }();
    _audio.dispose();
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Initialisation ────────────────────────────────────────
  Future<void> _init() async {
    final session = await SessionService.readSession();
    _myUserId = session.userId;

    // 1) historique
    await _loadHistory();

    // 2) temps réel
    _socket.on('new_message', _onNewMessage);
    _socket.on('connect', _onConnect); // ré-entre dans la salle après coupure
    _socket.connect();
    try {
      _socket.join();
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loadFailed = false);
    try {
      final res = await ChatApiService.getMessages(widget.orderId);
      final list = <_ChatMsg>[];
      for (final r in res) {
        list.add(_ChatMsg.from(r));
      }
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      setState(() {
        // garde d'éventuels messages arrivés pendant le chargement
        final known = list.map((e) => e.id).whereType<String>().toSet();
        final extra = _msgs.where((m) => m.id == null || !known.contains(m.id));
        _msgs
          ..clear()
          ..addAll(list)
          ..addAll(extra);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = _msgs.isEmpty;
      });
    }
  }

  dynamic _handleConnect(dynamic _) {
    try {
      _socket.join();
    } catch (_) {}
    return null;
  }

  dynamic _handleNewMessage(dynamic data) {
    if (!mounted) return null;
    var payload = data;
    if (payload is List && payload.isNotEmpty) payload = payload.first;
    if (payload is Map && payload['message'] is Map) {
      payload = payload['message'];
    }
    final map = _toMap(payload);
    final oid = map['orderId'];
    if (oid != null && int.tryParse(oid.toString()) != widget.orderId) {
      return null; // message d'une autre commande
    }
    _mergeIncoming(_ChatMsg.from(payload));
    return null;
  }

  /// Ajoute le message reçu — ou remplace notre message local correspondant.
  void _mergeIncoming(_ChatMsg m) {
    setState(() {
      if (m.id != null && _msgs.any((e) => e.id == m.id)) return;
      if (m.fromUserId == _myUserId) {
        final i = _msgs.indexWhere((e) =>
            e.local &&
            !e.uploading &&
            e.type == m.type &&
            (e.type != 'TEXT' || e.text == m.text));
        if (i >= 0) {
          _msgs[i] = m;
          return;
        }
      }
      _msgs.add(m);
    });
  }

  // ── Envoi ─────────────────────────────────────────────────
  _ChatMsg _localMsg({
    required String type,
    String text = '',
    String? localPath,
    int? durationSec,
    bool uploading = false,
  }) {
    return _ChatMsg(
      localId: 'local_${_localCounter++}_${DateTime.now().microsecondsSinceEpoch}',
      fromUserId: _myUserId,
      type: type,
      text: text,
      localPath: localPath,
      durationSec: durationSec,
      createdAt: DateTime.now(),
      local: true,
      uploading: uploading,
    );
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final msg = _localMsg(type: 'TEXT', text: text);
    setState(() => _msgs.add(msg));
    try {
      _socket.sendMessage(text: text, messageType: 'TEXT');
    } catch (_) {
      setState(() => _msgs.removeWhere((m) => m.localId == msg.localId));
      _snack(_T.sendFailed);
    }
  }

  /// Upload d'un fichier puis envoi sur le socket.
  Future<void> _sendMedia({
    required File file,
    required String type, // IMAGE | AUDIO
    int? durationSec,
  }) async {
    final msg = _localMsg(
      type: type,
      localPath: file.path,
      durationSec: durationSec,
      uploading: true,
    );
    setState(() => _msgs.add(msg));
    try {
      final res = await ChatApiService.uploadChatMedia(file);
      final url = _read(res, 'url')?.toString();
      if (url == null || url.isEmpty) throw Exception('url manquante');
      final mime = _read(res, 'mimeType')?.toString();
      final sizeRaw = _read(res, 'size');
      final size = sizeRaw == null ? null : int.tryParse(sizeRaw.toString());

      _socket.sendMessage(
        text: '',
        messageType: type,
        mediaUrl: url,
        mediaDuration: durationSec,
        mediaMimeType: mime,
        mediaSize: size,
      );
      if (!mounted) return;
      setState(() {
        final i = _msgs.indexWhere((m) => m.localId == msg.localId);
        if (i >= 0) _msgs[i] = _msgs[i].copyWith(uploading: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _msgs.removeWhere((m) => m.localId == msg.localId));
      _snack(_T.sendFailed);
    }
  }

  // ── Photos ────────────────────────────────────────────────
  Future<void> _attach() async {
    _focus.unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachSheet(),
    );
    if (source == null) return;

    if (source == ImageSource.camera) {
      final st = await Permission.camera.request();
      if (!st.isGranted) {
        _snack(_T.cameraDenied, settings: st.isPermanentlyDenied);
        return;
      }
    }
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (x == null) return;
      await _sendMedia(file: File(x.path), type: 'IMAGE');
    } catch (_) {
      _snack(_T.sendFailed);
    }
  }

  // ── Note vocale : enregistrement ──────────────────────────
  Future<void> _startRecording() async {
    final st = await Permission.microphone.request();
    if (!st.isGranted) {
      _snack(_T.micDenied, settings: st.isPermanentlyDenied);
      return;
    }
    try {
      final path =
          '${Directory.systemTemp.path}/chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _recordPath = path;
      _recWatch
        ..reset()
        ..start();
      _recElapsed = Duration.zero;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() => _recElapsed = _recWatch.elapsed);
        if (_recWatch.elapsed >= const Duration(minutes: 5)) {
          _finishRecording(send: true); // limite de sécurité
        }
      });
      _pulse.repeat(reverse: true);
      setState(() => _recording = true);
    } catch (_) {
      _snack(_T.sendFailed);
    }
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _recTimer?.cancel();
    _pulse.stop();
    _recWatch.stop();
    final seconds = (_recWatch.elapsedMilliseconds / 1000).round();
    if (mounted) setState(() => _recording = false);

    try {
      if (!send || seconds < 1) {
        await _recorder.cancel();
        return;
      }
      final path = await _recorder.stop() ?? _recordPath;
      if (path == null) return;
      await _sendMedia(
        file: File(path),
        type: 'AUDIO',
        durationSec: seconds,
      );
    } catch (_) {
      _snack(_T.sendFailed);
    }
  }

  // ── Note vocale : lecture (un seul lecteur partagé) ───────
  void _initAudioPlayer() {
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      final cur = _audio.value;
      _audio.value = _AudioState(
        id: cur.id,
        playing: s == PlayerState.playing,
        position: cur.position,
        total: cur.total,
      );
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      final cur = _audio.value;
      _audio.value = _AudioState(
        id: cur.id,
        playing: cur.playing,
        position: p,
        total: cur.total,
      );
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      final cur = _audio.value;
      _audio.value = _AudioState(
        id: cur.id,
        playing: cur.playing,
        position: cur.position,
        total: d,
      );
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      _audio.value = const _AudioState();
    }));
  }

  Future<void> _toggleAudio(_ChatMsg m) async {
    final src = m.mediaUrl != null
        ? UrlSource(m.mediaUrl!)
        : (m.localPath != null ? DeviceFileSource(m.localPath!) : null);
    if (src == null) return;
    final cur = _audio.value;
    try {
      if (cur.id == m.key) {
        if (cur.playing) {
          await _player.pause();
        } else {
          await _player.resume();
        }
        return;
      }
      await _player.stop();
      _audio.value = _AudioState(
        id: m.key,
        playing: true,
        total: m.durationSec == null ? null : Duration(seconds: m.durationSec!),
      );
      await _player.play(src);
    } catch (_) {
      _audio.value = const _AudioState();
      _snack(_T.sendFailed);
    }
  }

  // ── Divers ────────────────────────────────────────────────
  void _openImage(_ChatMsg m) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _ImageViewer(
          url: m.mediaUrl,
          path: m.localPath,
          heroTag: 'chat_img_${m.key}',
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _snack(String message, {bool settings = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: _C.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white)),
          action: settings
              ? SnackBarAction(
                  label: _T.settings,
                  textColor: Colors.white,
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
  }

  // ═════════════════════════════════════════════════════════
  // Interface
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _focus.unfocus(),
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
            _inputArea(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final name = widget.recipientName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final role = widget.recipientRole?.trim();

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        border: Border(bottom: BorderSide(color: _C.border, width: 0.6)),
        boxShadow: [
          BoxShadow(
            color: _C.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_rounded, color: _C.ink),
              ),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_C.brand, _C.brand.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? AppLocalizations.of(context)!.messages
                          : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(color: _C.ink)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    if (role != null && role.isNotEmpty)
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _C.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.brandSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#${widget.orderId}',
                  style: TextStyle(
                    color: _C.brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: Swirling(size: 56, color: _C.brand));
    }
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: _C.subtle),
            const SizedBox(height: 12),
            Text(_T.loadFailed, style: TextStyle(color: _C.muted)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _loadHistory();
              },
              icon: Icon(Icons.refresh_rounded, color: _C.brand),
              label: Text(_T.retry, style: TextStyle(color: _C.brand)),
            ),
          ],
        ),
      );
    }
    if (_msgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.brandSurface,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 38, color: _C.brand),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.chat_first_message,
              style: AppTypography.bodyMedium(color: _C.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Liste inversée : le bas de la conversation reste collé au clavier.
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _msgs.length,
      itemBuilder: (_, i) {
        final idx = _msgs.length - 1 - i;
        final m = _msgs[idx];
        final prev = idx > 0 ? _msgs[idx - 1] : null;
        final next = idx < _msgs.length - 1 ? _msgs[idx + 1] : null;

        bool sameGroup(_ChatMsg a, _ChatMsg b) =>
            a.fromUserId == b.fromUserId &&
            _sameDay(a.createdAt, b.createdAt) &&
            b.createdAt.difference(a.createdAt).inMinutes.abs() < 5;

        final first = prev == null || !sameGroup(prev, m);
        final last = next == null || !sameGroup(m, next);
        final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);

        return Column(
          children: [
            if (newDay) _DayChip(date: m.createdAt),
            _MessageRow(
              key: ValueKey(m.localId),
              msg: m,
              mine: m.fromUserId == _myUserId,
              first: first,
              last: last,
              audio: _audio,
              onToggleAudio: () => _toggleAudio(m),
              onOpenImage: () => _openImage(m),
            ),
          ],
        );
      },
    );
  }

  // ── Barre de saisie ───────────────────────────────────────
  Widget _inputArea() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        border: Border(top: BorderSide(color: _C.border, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _recording ? _recordingBar() : _composer(),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Row(
      key: const ValueKey('composer'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RoundIconButton(
          icon: Icons.add_photo_alternate_outlined,
          color: _C.muted,
          background: _C.warm,
          onTap: _attach,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _C.warm,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border, width: 0.8),
            ),
            child: TextField(
              controller: _textCtrl,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyLarge(color: _C.ink),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.yourMessage,
                hintStyle: AppTypography.bodyMedium(color: _C.subtle),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: _hasText
              ? _RoundIconButton(
                  key: const ValueKey('send'),
                  icon: Icons.send_rounded,
                  color: Colors.white,
                  background: _C.brand,
                  shadow: true,
                  onTap: _sendText,
                )
              : _RoundIconButton(
                  key: const ValueKey('mic'),
                  icon: Icons.mic_rounded,
                  color: Colors.white,
                  background: _C.brand,
                  shadow: true,
                  onTap: _startRecording,
                ),
        ),
      ],
    );
  }

  Widget _recordingBar() {
    final m = _recElapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_recElapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      key: const ValueKey('recording'),
      children: [
        _RoundIconButton(
          icon: Icons.delete_outline_rounded,
          color: _C.error,
          background: _C.error.withValues(alpha: 0.10),
          onTap: () => _finishRecording(send: false),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _C.warm,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border, width: 0.8),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: Tween(begin: 0.25, end: 1.0).animate(_pulse),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: _C.error, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$m:$s',
                  style: AppTypography.bodyLarge(color: _C.ink).copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _T.recording,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _C.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.send_rounded,
          color: Colors.white,
          background: _C.brand,
          shadow: true,
          onTap: () => _finishRecording(send: true),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Utilitaires
// ═══════════════════════════════════════════════════════════════
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _mmss(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ═══════════════════════════════════════════════════════════════
// Petits composants
// ═══════════════════════════════════════════════════════════════
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.shadow = false,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: background.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final d = date;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _C.warm,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _C.border, width: 0.6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _C.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, ImageSource src) {
      return Expanded(
        child: Material(
          color: _C.warm,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(context, src),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.brandSurface,
                    ),
                    child: Icon(icon, color: _C.brand, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: _C.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                tile(Icons.photo_camera_outlined, _T.camera,
                    ImageSource.camera),
                const SizedBox(width: 12),
                tile(Icons.photo_library_outlined, _T.gallery,
                    ImageSource.gallery),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Ligne de message + bulles
// ═══════════════════════════════════════════════════════════════
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.msg,
    required this.mine,
    required this.first,
    required this.last,
    required this.audio,
    required this.onToggleAudio,
    required this.onOpenImage,
  });

  final _ChatMsg msg;
  final bool mine;
  final bool first;
  final bool last;
  final ValueNotifier<_AudioState> audio;
  final VoidCallback onToggleAudio;
  final VoidCallback onOpenImage;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    const big = Radius.circular(20);
    const small = Radius.circular(5);

    // La « queue » de la bulle n'apparaît que sur le dernier message du groupe.
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: mine ? big : (last ? small : big),
      bottomRight: mine ? (last ? small : big) : big,
    );

    final isImage = msg.type == 'IMAGE';

    final Widget content;
    switch (msg.type) {
      case 'IMAGE':
        content = _ImageContent(
          msg: msg,
          mine: mine,
          radius: radius,
          onTap: onOpenImage,
        );
        break;
      case 'AUDIO':
        content = _AudioContent(
          msg: msg,
          mine: mine,
          audio: audio,
          onToggle: onToggleAudio,
        );
        break;
      default:
        content = _TextContent(msg: msg, mine: mine);
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: isImage ? EdgeInsets.zero : const EdgeInsets.fromLTRB(14, 10, 12, 8),
      decoration: BoxDecoration(
        gradient: mine && !isImage
            ? LinearGradient(
                colors: [_C.brand, _C.brand.withValues(alpha: 0.88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: mine ? (isImage ? _C.brand : null) : _C.card,
        borderRadius: radius,
        border: mine ? null : Border.all(color: _C.border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: (mine ? _C.brand : _C.ink).withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isImage
          ? ClipRRect(borderRadius: radius, child: content)
          : content,
    );

    return Padding(
      padding: EdgeInsets.only(top: first ? 6 : 2, bottom: last ? 4 : 0),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.msg, required this.mine, this.onMedia = false});
  final _ChatMsg msg;
  final bool mine;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final base = onMedia
        ? Colors.white
        : (mine ? Colors.white.withValues(alpha: 0.78) : _C.subtle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _hhmm(msg.createdAt),
          style: TextStyle(color: base, fontSize: 10.5),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          Icon(
            msg.uploading || (msg.local && msg.id == null)
                ? Icons.access_time_rounded
                : Icons.done_all_rounded,
            size: 14,
            color: base,
          ),
        ],
      ],
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.msg, required this.mine});
  final _ChatMsg msg;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            msg.text,
            style: AppTypography.bodyLarge(
              color: mine ? Colors.white : _C.ink,
            ).copyWith(height: 1.35),
          ),
        ),
        const SizedBox(height: 3),
        _TimeRow(msg: msg, mine: mine),
      ],
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.msg,
    required this.mine,
    required this.radius,
    required this.onTap,
  });

  final _ChatMsg msg;
  final bool mine;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.62).clamp(180.0, 280.0);
    final Widget image;
    if (msg.mediaUrl != null) {
      image = CachedNetworkImage(
        imageUrl: msg.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: _C.warm,
          child: Center(child: Swirling(size: 36, color: _C.brand)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: _C.warm,
          child: Icon(Icons.broken_image_outlined, color: _C.subtle, size: 36),
        ),
      );
    } else if (msg.localPath != null) {
      image = Image.file(File(msg.localPath!), fit: BoxFit.cover);
    } else {
      image = Container(color: _C.warm);
    }

    return GestureDetector(
      onTap: msg.uploading ? null : onTap,
      child: Hero(
        tag: 'chat_img_${msg.key}',
        child: SizedBox(
          width: w,
          height: w * 1.05,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (msg.uploading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Swirling(size: 44, color: Colors.white),
                  ),
                ),
              // dégradé + heure
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _TimeRow(msg: msg, mine: mine, onMedia: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioContent extends StatelessWidget {
  const _AudioContent({
    required this.msg,
    required this.mine,
    required this.audio,
    required this.onToggle,
  });

  final _ChatMsg msg;
  final bool mine;
  final ValueNotifier<_AudioState> audio;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : _C.brand;
    final track = mine
        ? Colors.white.withValues(alpha: 0.30)
        : _C.brand.withValues(alpha: 0.18);
    final btnBg = mine ? Colors.white.withValues(alpha: 0.22) : _C.brandSurface;

    return SizedBox(
      width: 220,
      child: ValueListenableBuilder<_AudioState>(
        valueListenable: audio,
        builder: (_, st, __) {
          final active = st.id == msg.key;
          final playing = active && st.playing;
          final knownTotal = msg.durationSec ??
              (active ? st.total?.inSeconds : null) ??
              0;
          final totalMs = (active && st.total != null)
              ? st.total!.inMilliseconds
              : knownTotal * 1000;
          final progress = (active && totalMs > 0)
              ? (st.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
              : 0.0;
          final shown = active && st.position > Duration.zero
              ? st.position.inSeconds
              : knownTotal;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Material(
                    color: btnBg,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: msg.uploading ? null : onToggle,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: msg.uploading
                            ? Center(child: Swirling(size: 24, color: fg))
                            : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: fg,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: track,
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _mmss(shown),
                          style: TextStyle(
                            color: mine
                                ? Colors.white.withValues(alpha: 0.85)
                                : _C.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              _TimeRow(msg: msg, mine: mine),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Image plein écran (zoom + fermeture)
// ═══════════════════════════════════════════════════════════════
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({this.url, this.path, required this.heroTag});
  final String? url;
  final String? path;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final Widget image = url != null
        ? CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                Center(child: Swirling(size: 56, color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 56,
            ),
          )
        : (path != null
            ? Image.file(File(path!), fit: BoxFit.contain)
            : const SizedBox.shrink());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: image,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}