import 'package:flutter/material.dart';

class RatingTag {
  final String label;
  final IconData icon;

  const RatingTag(this.label, this.icon);
}

const platTags = [
  RatingTag('Bien présenté', Icons.restaurant),
  RatingTag('Savoureux', Icons.thumb_up_alt_outlined),
  RatingTag('Bon rapport qualité-prix', Icons.monetization_on_outlined),
  RatingTag('Frais', Icons.eco_outlined),
  RatingTag('Généreux', Icons.dinner_dining_outlined),
  RatingTag('Bien assaisonné', Icons.spoke_outlined),
  RatingTag('Original', Icons.auto_awesome_outlined),
  RatingTag('Texture parfaite', Icons.blur_on_outlined),
];

const restaurantTags = [
  RatingTag('Réactif', Icons.flash_on_outlined),
  RatingTag('Respect des horaires', Icons.schedule_outlined),
  RatingTag('Propre', Icons.cleaning_services_outlined),
  RatingTag('Accueillant', Icons.emoji_emotions_outlined),
  RatingTag('Service rapide', Icons.rocket_launch_outlined),
  RatingTag('Bonne communication', Icons.chat_outlined),
  RatingTag('Emballage soigné', Icons.inventory_2_outlined),
  RatingTag('Professionnel', Icons.work_outline_outlined),
];

const livreurTags = [
  RatingTag('Souriant', Icons.face_outlined),
  RatingTag('Ponctuel', Icons.access_time_filled_outlined),
  RatingTag('Professionnel', Icons.badge_outlined),
  RatingTag('Rapide', Icons.speed_outlined),
  RatingTag('Courtois', Icons.handshake_outlined),
  RatingTag('Soigneux', Icons.shield_outlined),
  RatingTag('Serviable', Icons.help_outline_outlined),
  RatingTag('Bon contact', Icons.contact_phone_outlined),
];

List<RatingTag> tagsForTargetType(int targetType) {
  switch (targetType) {
    case 1:
      return restaurantTags;
    case 2:
      return platTags;
    case 3:
      return livreurTags;
    default:
      return [];
  }
}
