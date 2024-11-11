import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double starSize;
  final Color color;
  final int maxRating;

  const StarRating({
    Key? key,
    required this.rating,
    this.starSize = 20.0,
    this.color = Colors.amber,
    this.maxRating = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _buildStars(),
    );
  }

  List<Widget> _buildStars() {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    for (int i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: color, size: starSize));
    }

    if (hasHalfStar) {
      stars.add(Icon(Icons.star_half, color: color, size: starSize));
    }

    while (stars.length < maxRating) {
      stars.add(Icon(Icons.star_border, color: color, size: starSize));
    }

    return stars;
  }
}
