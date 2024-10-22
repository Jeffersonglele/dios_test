import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'dart:math';
import 'package:intl/intl.dart';

/// Génère un code aléatoire de 6 chiffres
String generateVerificationCode() {
  Random random = Random();
  int code = random.nextInt(900000) + 100000; // Génère un nombre entre 100000 et 999999
  return code.toString();
}

/// Envoie un email avec le code de vérification et retourne le code généré
Future<String?> sendVerificationEmail(BuildContext context, String email) async {
  try {
    String username = 'blandinedupont087@gmail.com'; // Remplacez par votre adresse Gmail
    String password = 'dtmd pleh ufau vjqd'; // Remplacez par votre mot de passe sécurisé

    final smtpServer = gmail(username, password);

    // Génère un code de vérification
    String verificationCode = generateVerificationCode();

    // Ajoute la date d'expiration du code (15 minutes après la génération)
    DateTime expirationTime = DateTime.now().add(Duration(minutes: 15));
    String formattedExpirationTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(expirationTime);

    // Message à envoyer
    String message = "Votre code de vérification est : $verificationCode.\n"
        "Ce code est valable jusqu'à $formattedExpirationTime.";

    // Créez le message à envoyer
    final messageSending = Message()
      ..from = Address(username, 'Dios Délices')
      ..recipients.add(email) // Envoyer à l'utilisateur
      ..subject = 'Votre code de vérification'
      ..text = message
      ..html = "<h1>Code de vérification : $verificationCode</h1>"
          "<p>Ce code est valable jusqu'à $formattedExpirationTime. "
          "Veuillez entrer ce code pour continuer.</p>";

    // Envoie du message
    await send(messageSending, smtpServer);

    // Affiche un message de succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Code de vérification envoyé à $email")),
    );

    // Retourne le code généré pour validation plus tard
    return verificationCode;
  } on MailerException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erreur lors de l'envoi du mail")),
    );
    return null;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erreur inconnue.")),
    );
    return null;
  }
}

/// Vérifie si le code de vérification est toujours valide
bool isCodeValid(String generatedCode, String enteredCode, DateTime generationTime) {
  // Vérifie si le code correspond et s'il est dans les 15 minutes
  if (generatedCode == enteredCode && DateTime.now().difference(generationTime).inMinutes < 15) {
    return true;
  }
  return false;
}
