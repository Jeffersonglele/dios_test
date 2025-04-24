import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../Constant/Constant.dart';
import '../LocationPage.dart';

class StartAddressSaving extends ConsumerStatefulWidget {
  final int userID;
  final int roleID;

  StartAddressSaving({required this.userID, required this.roleID});

  @override
  StartAddressSavingState createState() =>
      StartAddressSavingState();
}

class StartAddressSavingState
    extends ConsumerState<StartAddressSaving> {
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: size.width > 600
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.1),
                size.width > 600
                    ? Container()
                    : Center(
                        child: AvatarGlow(
                          duration: Duration(seconds: 2),
                          glowColor: Colors.white24,
                          repeat: true,
                          startDelay: Duration(seconds: 1),
                          child: Material(
                            elevation: 8.0,
                            shape: CircleBorder(),
                            child: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  AssetImage('assets/images/logo_sm01.jpg'),
                              radius: 50.0,
                            ),
                          ),
                        ),
                      ),
                SizedBox(height: size.height * 0.03),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    "Nous allons enregistrer votre adresse : suivez les instructions jusqu'à la fin",
                    style: kLoginSubtitleStyle(size),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(height: size.height * 0.05),
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: size.width * 0.8, // 80% de la largeur de l'écran
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pushReplacement(
                                context,
                                CupertinoPageRoute(
                                    builder: (ctx) => LocationPage(
                                          objectID: widget.userID,
                                          user_roleID: widget.roleID,
                                        )));
                          },
                          child: const Text('Commencer >'),
                        ),
                      ),
                      const SizedBox(height: 16), // Espace entre les boutons
                      SizedBox(
                        width: size.width * 0.8,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Annuler (retour à la connexion)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
