import 'dart:async';
import 'dart:math' as math;

import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/socket_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../orders/commande_details_page.dart';

/// Fond de carte épuré « Positron » de CARTO.
const String kTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const List<String> kTileSubdomains = ['a', 'b', 'c', 'd'];

/// Identifiant envoyé aux serveurs de tuiles (à remplacer par votre applicationId).
const String kTileUserAgent = 'com.diosdelices.app';

/// Centre de repli (Cotonou) tant qu'aucune position n'est connue.
const LatLng _kFallbackCenter = LatLng(6.3703, 2.3912);

/// Vitesse moyenne supposée d'une moto en ville, pour estimer l'arrivée.
const double _kMinutesPerKm = 3.0; // ≈ 20 km/h

const Distance _geo = Distance(roundResult: false);

class LivreurMapPage extends StatefulWidget {
  const LivreurMapPage({
    super.key,
    this.commande,
    this.courierMode = false,
    this.destination,
    this.courierName,
    this.onCallCourier,
  });

  final Commande? commande;

  /// `true` : l'écran est ouvert par le livreur (GPS du téléphone).
  final bool courierMode;

  /// Point de livraison du client si vous le connaissez déjà
  /// (sinon lu sur la commande, puis GPS du client en mode client).
  final LatLng? destination;

  /// Nom affiché du livreur (sinon lu sur la commande, sinon « Livreur #id »).
  final String? courierName;

  /// Si fourni, affiche le bouton « Appeler » (ex. url_launcher `tel:`).
  final VoidCallback? onCallCourier;

  @override
  State<LivreurMapPage> createState() =>
      _LivreurMapPageState();
}

class _LivreurMapPageState extends State<LivreurMapPage>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _follow = true; // la caméra suit tant que l'utilisateur ne la touche pas
  bool _expanded = false;

  // ── Données de course ────────────────────────────────────
  String _status = 'assigned'; // Valeur par défaut quand commande est null
  LatLng? _restaurantPos;
  String? _restaurantName;
  String? _restaurantAddress;
  LatLng? _destination;

  // ── Position animée du livreur ───────────────────────────
  late final AnimationController _move = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat();
  late final Listenable _anims = Listenable.merge([_move, _pulse]);

  LatLng? _from;
  LatLng? _to;
  double _bearingFrom = 0;
  double _bearingTo = 0;
  final List<LatLng> _trail = [];

  StreamSubscription<Map<String, dynamic>>? _movedSub;
  StreamSubscription<Map<String, dynamic>>? _driverLocSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<Position>? _gpsSub;
  SocketService? _socket;
  bool _socketConnectedLocally = false;
  String? _gpsProblem; // message affiché si le GPS est refusé / coupé

  // ═════════════════════════════════════════════════════════
  // Cycle de vie
  // ═════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    // à chaque image de l'animation, la caméra suit le marqueur (auto-follow)
    _move.addListener(_followTick);
    if (widget.commande != null) {
      _status = DeliveryStatus.normalize(widget.commande!.deliveryStatus);
      _destination = widget.destination ?? _coordsOf(widget.commande!, _destKeys);

      // position connue au moment d'ouvrir l'écran
      final la = _num(() => (widget.commande! as dynamic).livreurLat);
      final lo = _num(() => (widget.commande! as dynamic).livreurLng);
      final start = _valid(la, lo);
      if (start != null && !widget.courierMode) _onCourierPosition(start);

      _loadRestaurant();
      if (widget.courierMode) {
        _startGps();
      } else {
        _startSocket();
        _resolveClientPosition();
      }
    }
  }

  @override
  void dispose() {
    _movedSub?.cancel();
    _driverLocSub?.cancel();
    _statusSub?.cancel();
    _gpsSub?.cancel();
    if (_socket != null && widget.commande != null) {
      final id = widget.commande!.commandeID.toString();
      _socket?.leaveOrderRoom(id);
      _socket?.leaveOrderTracking(id);
    }
    _move.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════
  // Sources de données
  // ═════════════════════════════════════════════════════════
  Future<void> _loadRestaurant() async {
    if (widget.commande == null) return;
    try {
      final restos = await Restaurant.fetchRestaurantsFromDB();
      for (final r in restos) {
        if (r.restaurantID == widget.commande!.restauID) {
          if (!mounted) return;
          setState(() {
            _restaurantPos = _coordsOf(r, _restoKeys);
            _restaurantName = r.name;
            _restaurantAddress = _str(() => (r as dynamic).adresse) ??
                _str(() => (r as dynamic).address);
          });
          _fit();
          return;
        }
      }
    } catch (_) {}
  }

  /// Mode client : temps réel via Socket.io.
  Future<void> _startSocket() async {
    if (widget.commande == null) return;
    final socket = SocketService();
    _socket = socket;
    try {
      await socket.connect();
      _socketConnectedLocally = true;
    } catch (_) {}
    final id = widget.commande!.commandeID.toString();
    socket.joinOrderRoom(id);
    socket.joinOrderTracking(id);
    // évènement hérité « courier_moved » (clé latitude/longitude)
    _movedSub = socket.onCourierMoved.listen((data) {
      if (data['orderId']?.toString() != id) return;
      final p = _valid(
        (data['latitude'] as num?)?.toDouble(),
        (data['longitude'] as num?)?.toDouble(),
      );
      if (p != null && mounted) _onCourierPosition(p);
    });
    // évènement spec v2 « driver_location_updated » (clé lat/lng + heading)
    _driverLocSub = socket.onDriverLocationUpdated.listen((data) {
      if (data['orderId']?.toString() != id) return;
      final p = _valid(
        (data['lat'] as num?)?.toDouble() ??
            (data['latitude'] as num?)?.toDouble(),
        (data['lng'] as num?)?.toDouble() ??
            (data['longitude'] as num?)?.toDouble(),
      );
      final heading = (data['heading'] as num?)?.toDouble();
      if (p != null && mounted) _onCourierPosition(p, heading: heading);
    });
    _statusSub = socket.onDeliveryStatusChanged.listen((data) {
      if (data['orderId']?.toString() != id) return;
      final s = data['status']?.toString();
      if (s != null && mounted) {
        setState(() => _status = DeliveryStatus.normalize(s));
        _fit();
      }
    });
  }

  /// Vérifie service + permission de localisation (message affiché sinon).
  Future<bool> _ensureLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setGpsProblem('Activez la localisation du téléphone');
        return false;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _setGpsProblem('Autorisez la localisation pour partager votre position');
        return false;
      }
      return true;
    } catch (_) {
      return true; // on tente quand même
    }
  }

  void _setGpsProblem(String m) {
    if (mounted) setState(() => _gpsProblem = m);
  }

  /// Mode livreur : GPS réel du téléphone → carte locale + WebSocket serveur.
  Future<void> _startGps() async {
    final orderId = widget.commande?.commandeID.toString();
    try {
      final s = SocketService();
      _socket = s;
      await s.connect();
      _socketConnectedLocally = true;
      if (orderId != null) {
        s.joinOrderRoom(orderId);
        s.joinOrderTracking(orderId);
      }
    } catch (_) {}
    if (!mounted) return;
    if (!await _ensureLocationPermission() || !mounted) return;

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // mètres
      ),
    ).listen((pos) {
      final p = LatLng(pos.latitude, pos.longitude);
      // le cap n'est fiable qu'en mouvement (à l'arrêt il vaut souvent 0)
      final reliable =
          pos.speed > 1.0 && pos.heading >= 0 && pos.heading <= 360;
      if (mounted) {
        if (_gpsProblem != null) setState(() => _gpsProblem = null);
        _onCourierPosition(p, heading: reliable ? pos.heading : null);
      }
      if (orderId != null) {
        _socket?.emitUpdateLocation(
          orderId: orderId,
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading,
        );
      }
    }, onError: (_) => _setGpsProblem('Signal GPS indisponible'));
  }

  /// Mode client sans adresse GPS sur la commande : on utilise le téléphone.
  Future<void> _resolveClientPosition() async {
    if (_destination != null) return;
    try {
      Position? p = await Geolocator.getLastKnownPosition();
      p ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() => _destination = LatLng(p!.latitude, p.longitude));
      _fit();
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════
  // Mouvement du livreur (interpolé entre deux positions GPS)
  // ═════════════════════════════════════════════════════════
  void _onCourierPosition(LatLng p, {double? heading}) {
    final prev = _to;
    if (prev == null) {
      _from = _to = p;
      _trail
        ..clear()
        ..add(p);
      if (heading != null && heading >= 0 && heading <= 360) {
        _bearingFrom = _bearingTo = heading;
      }
      if (mounted) setState(() {});
      _fit();
      return;
    }
    final movedM = _geo.distance(prev, p);
    if (movedM < 2) return; // bruit GPS

    _from = _animatedPos();
    _bearingFrom = _animatedBearing();
    _to = p;
    if (heading != null && heading >= 0 && heading <= 360) {
      _bearingTo = heading;
    } else if (movedM > 3) {
      _bearingTo = _bearingBetween(prev, p);
    }

    _trail.add(p);
    if (_trail.length > 250) _trail.removeAt(0);

    _move.forward(from: 0); // la caméra suit via _followTick
    if (mounted) setState(() {});
  }

  LatLng? _animatedPos() {
    final a = _from, b = _to;
    if (a == null || b == null) return b;
    final t = Curves.easeInOut.transform(_move.value);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Rotation par le plus court chemin (350° → 10° = +20°, pas −340°).
  double _animatedBearing() {
    final t = Curves.easeInOut.transform(_move.value);
    var d = (_bearingTo - _bearingFrom) % 360;
    if (d > 180) d -= 360;
    return (_bearingFrom + d * t) % 360;
  }

  double _bearingBetween(LatLng s, LatLng e) {
    final lat1 = s.latitude * math.pi / 180;
    final lat2 = e.latitude * math.pi / 180;
    final dLng = (e.longitude - s.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ═════════════════════════════════════════════════════════
  // Cible, distance, ETA, caméra
  // ═════════════════════════════════════════════════════════
  bool get _beforePickup =>
      _status == DeliveryStatus.assigned || _status == DeliveryStatus.atPickup;

  bool get _delivered => _status == DeliveryStatus.delivered;

  /// Le livreur va d'abord au restaurant, puis chez le client.
  LatLng? get _target =>
      _beforePickup ? (_restaurantPos ?? _destination) : _destination;

  double? get _distanceKm {
    final c = _to, t = _target;
    if (c == null || t == null) return null;
    return _geo.distance(_animatedPos() ?? c, t) / 1000;
  }

  int? get _etaMin {
    final d = _distanceKm;
    return d == null ? null : math.max(1, (d * _kMinutesPerKm).ceil());
  }

  /// Auto-follow : garde le livreur centré pendant la transition douce.
  void _followTick() {
    if (!_mapReady || !_follow || !mounted || _to == null) return;
    final p = _animatedPos();
    if (p == null) return;
    _map.move(p, _map.camera.zoom);
  }

  void _fit() {
    if (!_mapReady || !_follow || !mounted) return;
    final pts = <LatLng>[
      if (_to != null) _to!,
      if (_target != null) _target!,
      if (_to == null && _restaurantPos != null) _restaurantPos!,
      if (_to == null && _destination != null) _destination!,
    ];
    if (pts.isEmpty) return;
    final h = MediaQuery.of(context).size.height;
    if (pts.length == 1 || _geo.distance(pts.first, pts.last) < 30) {
      _map.move(pts.first, 16);
      return;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: EdgeInsets.fromLTRB(56, 150, 56, h * (_expanded ? 0.55 : 0.40)),
      maxZoom: 17,
    ));
  }

  void _recenter() {
    setState(() => _follow = true);
    _fit();
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(10, 18).toDouble());
    if (_follow) setState(() => _follow = false);
  }

  // ═════════════════════════════════════════════════════════
  // Lecture tolérante des modèles (champs inconnus)
  // ═════════════════════════════════════════════════════════
  static const _destKeys = <List<String>>[
    ['deliveryLat', 'deliveryLng'],
    ['clientLat', 'clientLng'],
    ['destLat', 'destLng'],
    ['destinationLat', 'destinationLng'],
    ['adresseLat', 'adresseLng'],
    ['latitude', 'longitude'],
    ['lat', 'lng'],
  ];
  static const _restoKeys = <List<String>>[
    ['latitude', 'longitude'],
    ['lat', 'lng'],
    ['lat', 'lon'],
    ['restaurantLat', 'restaurantLng'],
    ['pickupLat', 'pickupLng'],
  ];

  double? _num(dynamic Function() read) {
    try {
      final v = read();
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  String? _str(dynamic Function() read) {
    try {
      final s = read()?.toString().trim();
      return (s == null || s.isEmpty || s == 'null') ? null : s;
    } catch (_) {
      return null;
    }
  }

  LatLng? _valid(double? la, double? lo) {
    if (la == null || lo == null) return null;
    if (la.abs() > 90 || lo.abs() > 180 || (la == 0 && lo == 0)) return null;
    return LatLng(la, lo);
  }

  /// Lit `o.<champLat>` / `o.<champLng>` sans connaître le nom exact : on passe
  /// par noSuchMethod dynamique, chaque essai étant protégé.
  LatLng? _coordsOf(dynamic o, List<List<String>> keys) {
    for (final k in keys) {
      final la = _dyn(o, k[0]);
      final lo = _dyn(o, k[1]);
      final p = _valid(la, lo);
      if (p != null) return p;
    }
    return null;
  }

  double? _dyn(dynamic o, String field) {
    // Dart ne permet pas o.$field : on énumère les noms attendus.
    return _num(() {
      switch (field) {
        case 'deliveryLat': return o.deliveryLat;
        case 'deliveryLng': return o.deliveryLng;
        case 'clientLat': return o.clientLat;
        case 'clientLng': return o.clientLng;
        case 'destLat': return o.destLat;
        case 'destLng': return o.destLng;
        case 'destinationLat': return o.destinationLat;
        case 'destinationLng': return o.destinationLng;
        case 'adresseLat': return o.adresseLat;
        case 'adresseLng': return o.adresseLng;
        case 'latitude': return o.latitude;
        case 'longitude': return o.longitude;
        case 'lat': return o.lat;
        case 'lng': return o.lng;
        case 'lon': return o.lon;
        case 'restaurantLat': return o.restaurantLat;
        case 'restaurantLng': return o.restaurantLng;
        case 'pickupLat': return o.pickupLat;
        case 'pickupLng': return o.pickupLng;
      }
      return null;
    });
  }

  // ═════════════════════════════════════════════════════════
  // Couleurs (thème clair/sombre) — fond de carte toujours clair
  // ═════════════════════════════════════════════════════════
  Color get _ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  Color get _muted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  Color get _cardBg => AppColors.resolve(AppColors.card, AppDarkColors.card);
  Color get _warm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  Color get _line => AppColors.resolve(AppColors.border, AppDarkColors.border);
  Color get _brandC => AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  Color get _accentC =>
      AppColors.resolve(AppColors.accent, AppDarkColors.accent);
  static const Color _blue = Color(0xFF2563EB);

  String get _statusLabel {
    final l10n = AppLocalizations.of(context)!;
    if (_status == DeliveryStatus.atPickup) return 'Au restaurant';
    if (_status == DeliveryStatus.pickedUp) {
      return l10n.delivery_status_picked_up;
    }
    if (_status == DeliveryStatus.inTransit) {
      return l10n.delivery_status_in_transit;
    }
    if (_status == DeliveryStatus.delivered) {
      return l10n.delivery_status_delivered;
    }
    return l10n.delivery_status_assigned;
  }

  String get _courierDisplayName {
    if (widget.courierName != null) return widget.courierName!;
    if (widget.commande == null) return 'Votre livreur';
    final n = _str(() => (widget.commande! as dynamic).livreurName) ??
        _str(() => (widget.commande! as dynamic).livreurNom) ??
        _str(() => (widget.commande! as dynamic).nomLivreur);
    if (n != null) return n;
    final id = _str(() => (widget.commande! as dynamic).livreurID);
    return (id == null || id == '0') ? 'Votre livreur' : 'Livreur #$id';
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final initial = _to ?? _target ?? _restaurantPos ?? _kFallbackCenter;
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: initial,
              initialZoom: 14.5,
              minZoom: 10,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapReady = true;
                _fit();
              },
              // un geste de l'utilisateur coupe le suivi automatique
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: kTileUserAgent,
                maxZoom: 19,
              ),
              _animated(_buildZoneLayer),
              _animated(_buildRouteLayer),
              _animated(_buildTrailLayer),
              _animated(_buildMarkerLayer),
            ],
          ),
          _buildHeader(),
          _buildBottom(),
        ],
      ),
    );
  }

  Widget _animated(Widget Function() builder) =>
      AnimatedBuilder(animation: _anims, builder: (_, __) => builder());

  // ── Couches de carte ─────────────────────────────────────
  Widget _buildZoneLayer() {
    final d = _destination;
    if (d == null) return const SizedBox.shrink();
    return CircleLayer(circles: [
      CircleMarker(
        point: d,
        radius: 120,
        useRadiusInMeter: true,
        color: _blue.withValues(alpha: 0.10),
        borderColor: _blue.withValues(alpha: 0.30),
        borderStrokeWidth: 2,
      ),
    ]);
  }

  /// Trait livreur → prochaine étape (restaurant, puis client).
  Widget _buildRouteLayer() {
    final c = _animatedPos(), t = _target;
    if (c == null || t == null || _delivered) return const SizedBox.shrink();
    return PolylineLayer(polylines: [
      Polyline(
        points: [c, t],
        color: _brandC.withValues(alpha: 0.55),
        strokeWidth: 4,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    ]);
  }

  /// Traînée des dernières positions réelles (dégradé de transparence).
  Widget _buildTrailLayer() {
    final c = _animatedPos();
    if (_trail.length < 2 || c == null) return const SizedBox.shrink();
    final pts = [..._trail.sublist(0, _trail.length - 1), c];
    return PolylineLayer(polylines: [
      Polyline(
        points: pts,
        gradientColors: [
          _accentC.withValues(alpha: 0.15),
          _accentC.withValues(alpha: 0.80),
          _accentC,
        ],
        strokeWidth: 6,
        borderStrokeWidth: 2,
        borderColor: Colors.white.withValues(alpha: 0.5),
      ),
    ]);
  }

  Widget _buildMarkerLayer() {
    final markers = <Marker>[];

    if (_restaurantPos != null) {
      markers.add(Marker(
        point: _restaurantPos!,
        width: 56,
        height: 56,
        child: _pin(
          icon: Icons.storefront_rounded,
          color: _accentC,
          label: _restaurantName,
        ),
      ));
    }
    if (_destination != null) {
      markers.add(Marker(
        point: _destination!,
        width: 56,
        height: 56,
        child: _pin(
          icon: Icons.home_rounded,
          color: _blue,
          label: widget.courierMode ? 'Client' : 'Vous',
          filledLabel: true,
        ),
      ));
    }
    final c = _animatedPos();
    if (c != null) {
      markers.add(Marker(
        point: c,
        width: 64,
        height: 64,
        child: _courierMarker(),
      ));
    }
    return MarkerLayer(markers: markers);
  }

  /// Épingle ronde + étiquette flottante au-dessus (centrée sur le point).
  Widget _pin({
    required IconData icon,
    required Color color,
    String? label,
    bool filledLabel = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        if (label != null && label.isNotEmpty)
          Positioned(
            top: -22,
            left: -40,
            right: -40,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: filledLabel ? color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filledLabel ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Moto animée : halo qui pulse, rotation lissée, bulle « X min ».
  Widget _courierMarker() {
    final bearing = _animatedBearing();
    // l'icône regarde à droite : on la retourne vers l'ouest plutôt que de la
    // laisser la tête en bas
    final west = bearing > 180;
    final angleDeg = (west ? bearing - 270 : bearing - 90);
    final eta = _etaMin;
    final pulse = _pulse.value;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // halo
        Container(
          width: 44 + 26 * pulse,
          height: 44 + 26 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _brandC.withValues(alpha: 0.28 * (1 - pulse)),
          ),
        ),
        // moto
        Transform.rotate(
          angle: angleDeg * math.pi / 180,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _brandC,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _brandC.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.flip(
              flipX: west,
              child: const Icon(Icons.delivery_dining_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ),
        if (eta != null && !_delivered)
          Positioned(
            top: -20,
            left: -30,
            right: -30,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _brandC,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$eta min',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _anims,
          builder: (_, __) {
            final eta = _etaMin;
            final km = _distanceKm;
            final waiting = _to == null;
            final subtitle = _delivered
                ? 'Course terminée'
                : waiting
                    ? (widget.courierMode
                        ? (_gpsProblem ?? 'Recherche de votre position GPS…')
                        : 'En attente de la position du livreur…')
                    : eta == null
                        ? 'Position en direct'
                        : _beforePickup
                            ? 'Au restaurant dans ~$eta min'
                            : 'Arrivée dans ~$eta min';
            final live = !waiting && !_delivered;

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _warm,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: _ink),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: live
                                    ? AppColors.success
                                    : (_delivered
                                        ? AppColors.success
                                        : _muted),
                                shape: BoxShape.circle,
                                boxShadow: live
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success
                                              .withValues(alpha: 0.5),
                                          blurRadius: 4,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: _muted)),
                      ],
                    ),
                  ),
                  if (km != null && !_delivered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _brandC.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fmtKm(km),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _brandC,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _fmtKm(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  // ═════════════════════════════════════════════════════════
  // Panneau inférieur (+ boutons de carte)
  // ═════════════════════════════════════════════════════════
  Widget _buildBottom() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // contrôles de carte, toujours juste au-dessus du panneau
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Column(
              children: [
                _mapButton(Icons.add_rounded, () => _zoom(1)),
                const SizedBox(height: 8),
                _mapButton(Icons.remove_rounded, () => _zoom(-1)),
                const SizedBox(height: 8),
                _mapButton(
                  _follow
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  _recenter,
                  highlighted: !_follow,
                ),
              ],
            ),
          ),
          _buildPanel(),
        ],
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap,
      {bool highlighted = false}) {
    return Material(
      color: highlighted ? _brandC : _cardBg,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: highlighted ? Colors.white : _brandC),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    if (widget.commande == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final c = widget.commande!;
    final personName =
        widget.courierMode ? 'Client #${c.userID}' : _courierDisplayName;
    final destAddress = _str(() => (c as dynamic).adresseLivraison) ??
        _str(() => (c as dynamic).deliveryAddress) ??
        _str(() => (c as dynamic).adresse) ??
        (widget.courierMode ? 'Adresse du client' : 'Votre position');

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // poignée : tap ou glisser pour déplier
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _expanded = !_expanded);
                _fit();
              },
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 120) return;
                setState(() => _expanded = v < 0);
                _fit();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                children: [
                  // ── Livreur (ou client en mode livreur) ──
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _brandC,
                            Color.lerp(_brandC, Colors.black, 0.28)!,
                          ]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.courierMode
                              ? Icons.person_rounded
                              : Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _brandC.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _brandC,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _roundAction(
                        Icons.chat_bubble_outline_rounded,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              orderId: c.commandeID,
                              recipientName: personName,
                            ),
                          ),
                        ),
                      ),
                      if (widget.onCallCourier != null) ...[
                        const SizedBox(width: 8),
                        _roundAction(Icons.phone_rounded, widget.onCallCourier!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Chiffres clés ──
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          Icons.schedule_rounded,
                          'Temps',
                          _etaMin == null ? '—' : '$_etaMin min',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoCard(
                          Icons.straighten_rounded,
                          'Distance',
                          _distanceKm == null ? '—' : _fmtKm(_distanceKm!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoCard(
                          Icons.inventory_2_outlined,
                          'Commande',
                          '#${c.commandeID}',
                        ),
                      ),
                    ],
                  ),

                  // ── Détails (repliés par défaut) ──
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    curve: Curves.easeOut,
                    child: _expanded
                        ? Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _warm,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    _addressRow(
                                      Icons.storefront_rounded,
                                      'Point de retrait',
                                      [
                                        _restaurantName ??
                                            'Restaurant #${c.restauID}',
                                        if (_restaurantAddress != null)
                                          _restaurantAddress!,
                                      ].join(' · '),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Divider(
                                          height: 1,
                                          color: _line.withValues(alpha: 0.7)),
                                    ),
                                    _addressRow(
                                      Icons.home_rounded,
                                      'Destination',
                                      destAddress,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CommandeDetailsPage(commande: c),
                                    ),
                                  ),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: Text(
                                    l10n.user_orders_see_detail,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _brandC,
                                    side: BorderSide(color: _brandC, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),

                  const SizedBox(height: 10),
                  // crédit obligatoire du fond de carte (Esri Light Gray)
                  Text(
                    'Tiles © Esri — Esri, HERE, Garmin, © OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: _brandC.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _brandC, size: 21),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _brandC, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, String title, String address) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandC.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _brandC, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}