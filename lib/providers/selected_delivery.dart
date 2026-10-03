import 'package:flutter_riverpod/flutter_riverpod.dart';

const kDeliveryOptionLivraison = 'En Livraison';
const kDeliveryOptionEmporter = 'À Emporter';

final selectedDeliveryProvider =
    StateProvider<String>((ref) => kDeliveryOptionLivraison);
