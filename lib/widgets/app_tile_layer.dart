import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/app_config.dart';

/// Fond de carte CARTO « Voyager » (clé gratuite, usage commercial accepté
/// jusqu'à 1 million de tuiles par mois). La clé est passée au lancement :
/// `--dart-define=CARTO_API_KEY=xxxx`. Sans clé, CARTO renvoie une image
/// « API KEY REQUIRED » : on utilise alors les tuiles OpenStreetMap standard.
bool get _hasCartoKey => AppConfig.cartoApiKey.trim().isNotEmpty;

String get kTileUrl => _hasCartoKey
    ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=${AppConfig.cartoApiKey.trim()}'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Identifiant envoyé aux serveurs de tuiles (politique d'usage OSM).
const String kTileUserAgent = 'com.diosdelices.app';

/// Crédit obligatoire à afficher avec la carte.
String get kTileAttribution => _hasCartoKey
    ? '© OpenStreetMap contributors © CARTO'
    : '© OpenStreetMap contributors';

/// Dernier zoom pour lequel les serveurs ont de vraies tuiles : au-delà,
/// flutter_map agrandit ces tuiles au lieu d'en demander de nouvelles.
const int kTileMaxNativeZoom = 19;

/// Cache disque des tuiles : une zone déjà vue s'affiche sans réseau et
/// ne consomme plus le quota CARTO. Les tuiles sont gardées 30 jours, dans
/// la limite de 4 000 fichiers (environ 60 à 100 Mo).
final CacheManager _tileCache = CacheManager(
  Config(
    'dios_map_tiles',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 4000,
  ),
);

/// Charge chaque tuile via le cache disque (sinon réseau, puis mise en cache).
class CachedTileProvider extends TileProvider {
  CachedTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    // La clé de cache ignore la clé d'API : changer de clé ne vide pas le cache.
    final cacheKey = url.split('?').first;
    return CachedNetworkImageProvider(
      url,
      cacheKey: cacheKey,
      cacheManager: _tileCache,
      headers: headers,
    );
  }
}

/// Couche de tuiles partagée par tous les écrans de carte.
TileLayer appTileLayer() => TileLayer(
      urlTemplate: kTileUrl,
      userAgentPackageName: kTileUserAgent,
      tileProvider: CachedTileProvider(),
      // Tuiles « @2x » sur écran haute densité (plus nettes, même quota).
      retinaMode: _hasCartoKey,
      maxNativeZoom: kTileMaxNativeZoom,
      maxZoom: 20,
      // une tuile en erreur est redemandée dès qu'elle revient à l'écran
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
    );
