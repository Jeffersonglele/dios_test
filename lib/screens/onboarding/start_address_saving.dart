import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/constant.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../profile/location_page.dart';

class StartAddressSaving extends ConsumerStatefulWidget {
  final int userID;
  final int roleID;

  StartAddressSaving({required this.userID, required this.roleID});

  @override
  StartAddressSavingState createState() => StartAddressSavingState();
}

class StartAddressSavingState extends ConsumerState<StartAddressSaving> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    : const Center(child: BrandAvatarLogo()),
                SizedBox(height: size.height * 0.03),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    l10n.start_address_instructions,
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
                          child: Text(l10n.start_begin),
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
                          child: Text(l10n.start_cancel_return),
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
