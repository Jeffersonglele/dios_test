# Dios Délices — application Flutter

Application mobile de Dios Délices (clients, restaurateurs, livreurs, admin).
Elle s'appuie sur le backend Node (`dios_newback`).

## Lancer l'app

Les clés ne sont jamais écrites dans le code : elles sont passées au
lancement depuis un fichier local, non partagé.

1. Copier `dart_defines.example.json` en `dart_defines.json`.
2. Y mettre la clé CARTO (gratuite, demandée sur
   <https://carto.com/basemaps/apikey>).
3. Lancer avec ce fichier :

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Pour un APK ou un App Bundle, ajouter la même option :

```bash
flutter build appbundle --dart-define-from-file=dart_defines.json
```

| Clé | Rôle | Sans la clé |
|---|---|---|
| `CARTO_API_KEY` | Fond de carte CARTO « Voyager » | Tuiles OpenStreetMap standard (moins jolies, usage modéré) |
| `NODE_API_URL` | Adresse du backend | `https://dios-delices.onrender.com` |

## Cartes

- **Fond de carte** : CARTO Voyager, avec l'attribution « © OpenStreetMap
  contributors © CARTO » affichée sur la carte. L'offre gratuite accepte un
  usage commercial jusqu'à 1 million de tuiles par mois ; au-delà, l'offre
  commerciale coûte 500 $/mois.
- **Cache sur le téléphone** : les tuiles déjà vues sont gardées 30 jours
  (4 000 tuiles au plus). Une zone revisitée s'affiche sans réseau et ne
  consomme plus le quota CARTO. Le code est dans `lib/widgets/app_tile_layer.dart` ;
  pour changer de fournisseur, il suffit de modifier `kTileUrl`.
