import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OrderTrackingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Suivi de Commande')),
      body: Center(
        child: Text(
          "Suivi de votre commande en cours...",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}