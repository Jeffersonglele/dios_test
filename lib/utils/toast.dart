import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void Toast(BuildContext context, String message, bool isSuccess) {
  Color backgroundColor = isSuccess ? Colors.green : Colors.red;
  Color textColor = Colors.white;

  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 100.0, // Positionne le toast à 50 pixels du bas
      left: MediaQuery.of(context).size.width * 0.1, // Décalage de 10% à gauche pour centrer
      right: MediaQuery.of(context).size.width * 0.1, // Décalage de 10% à droite pour centrer
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Center(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ),
      ),
    ),
  );

  // Trouver l'Overlay et insérer l'OverlayEntry
  Overlay.of(context)?.insert(overlayEntry);

  // Supprimer le toast après un certain temps
  Future.delayed(Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}
