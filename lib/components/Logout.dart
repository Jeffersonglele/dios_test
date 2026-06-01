import 'package:dios_delices/Screen/AnimatedSplashScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/session_service.dart';

class LogoutFormDialog extends StatefulWidget {

  const LogoutFormDialog({Key? key}) : super(key: key);

  @override
  _LogoutFormDialogState createState() => _LogoutFormDialogState();
}

class _LogoutFormDialogState extends State<LogoutFormDialog> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              right: -40,
              top: -40,
              child: InkResponse(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, color: Colors.white),
                  radius: 15,
                ),
              ),
            ),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        "Vous allez être déconnecté(e) et l'application sera fermée",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text("Poursuivre ?",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.red,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          onPressed: () async {
                            await SessionService.clearAll();
                            await DatabaseHelper.cleanUpDatabase(true); // Nettoie la base de données

                            // Retour à l'écran de démarrage
                            Navigator.pushAndRemoveUntil(
                              context,
                              CupertinoPageRoute(
                                  builder: (ctx) =>
                                  const AnimatedSplashScreen()),
                                  (Route<dynamic> route) => false, // Supprime toutes les routes
                            );
                          },
                          child: const Text('Oui',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.green,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Non',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
