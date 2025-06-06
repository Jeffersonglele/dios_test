import 'dart:io';

import 'package:avatar_glow/avatar_glow.dart';
import 'package:dios_delices/Screen/verif_confirm/IdentityCreated.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../Constant/Constant.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../modeles/identity.dart';
import '../restaurants/RestaurantFormPage.dart';

class UserIdentityRejected extends ConsumerStatefulWidget {
  final int objectID;
  final int user_roleID;

  UserIdentityRejected({required this.objectID, required this.user_roleID});

  @override
  _UserIdentityRejectedState createState() => _UserIdentityRejectedState();
}

class _UserIdentityRejectedState extends ConsumerState<UserIdentityRejected> {
  final _formKey = GlobalKey<FormState>();

  List<Users> users = [];
  List<Identity> identities = [];
  late Users current_user;
  late Identity current_identity;

  File? _userPhoto;
  File? _identityFile;

  bool isLoading = true;

  // 📸 Prendre une photo de l'utilisateur avec la caméra
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _userPhoto = File(image.path);
      });
    }
  }

  // 📄 Sélectionner une pièce d'identité (image ou PDF)
  Future<void> _pickIdentityFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null) {
      setState(() {
        _identityFile = File(result.files.single.path!);
      });
    }
  }

  // Fonction pour envoyer un email à l'admin avec les infos du restaurant
  Future<void> _sendEmailToAdmin() async {
    String username =
        'blandinedupont087@gmail.com'; // Remplacez par votre adresse Gmail
    String password =
        'dtmd pleh ufau vjqd'; // Remplacez par votre mot de passe sécurisé

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address('blandinedupont087@gmail.com', 'Dios Délices')
      ..recipients.add('blandinedupont087@gmail.com') // Envoyer à l'admin
      ..subject = 'Nouvelle identité en attente de vérification'
      ..text = "Connectez-vous pour valider ou non l'utilisateur.";

    try {
      await send(message, smtpServer);
      print('Email envoyé avec succès');
    } on MailerException catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Chargement des données Users depuis la base de données
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Identity> identitiesList = await Identity.fetchIdentitiesFromDB();
    Users? user = await Users.getUsersByUserId(usersList, widget.objectID);
    Identity? identity = await Identity.getIdentityByUserId(identitiesList, widget.objectID);

    setState(() {
      users = usersList;
      identities = identitiesList;
      current_user = user!;
      current_identity = identity!;
    });
  }

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
                    'Mon identité',
                    style: kLoginTitleStyle(size),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 10),
                  child: Text(
                      "Les documents que vous avez fourni n'ont pas permis à nos équipes de valider votre profil"
                          "(un mail vous a été envoyé avec nos remarques. Veuillez-en prendre compte sur cette page.",
                      style: paragraph(size),
                      textAlign: TextAlign.justify),
                ),
                SizedBox(height: 30),

                Center(
                  child: Column(
                    children: [
                      // 📸 Photo de l'utilisateur
                      Text(
                        'Votre photo',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      _userPhoto != null
                          ? Image.file(_userPhoto!, width: 100, height: 100, fit: BoxFit.cover)
                          : current_identity.photo != null
                          ? Image.network(current_identity.photo ?? "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                          width: 100, height: 100, fit: BoxFit.cover)
                          : Text("Aucune photo disponible"),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: Icon(Icons.camera_alt),
                        label: Text("Prendre une photo"),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 50),

                Center(
                  child: Column(
                    children: [
                      // 🪪 Pièce d'identité
                      Text(
                        'Pièce d\'identité (image ou PDF)',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      _identityFile != null
                          ? Text("Fichier sélectionné : ${_identityFile!.path.split('/').last}")
                          : current_identity.piece_identite != null
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_present),
                          SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              // Affiche le document dans une nouvelle page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PDFOrImageViewer(
                                      url: current_identity.piece_identite ?? "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                                  ),
                                ),
                              );
                            },
                            child: Text("Voir le fichier existant"),
                          ),
                        ],
                      )
                          : Text("Aucun fichier sélectionné"),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _pickIdentityFile,
                        icon: Icon(Icons.file_present),
                        label: Text("Choisir un fichier"),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // 🔘 Valider
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      textStyle:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () async {
                      if (_userPhoto == null && _identityFile == null) {
                        print("_userPhoto " + _userPhoto.toString());
                        print("_identityFile " + _identityFile.toString());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  "Merci de modifier un des fichiers.")),
                        );
                        return;
                      } else {
                        ParseFile? parseFile_userPhoto;
                        ParseFile? parseFile_identityFile;

                        String userPhoto_newFileName = current_identity.photo ?? "";
                        String piece_newFileName = current_identity.piece_identite ?? "";

                        if (_userPhoto != null) {
                          String _userPhoto_fileName = p.basename(_userPhoto!.path);
                          String extension_userPhoto = p.extension(_userPhoto_fileName);
                          String nom_userPhoto = "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_photo";
                          userPhoto_newFileName = "$nom_userPhoto$extension_userPhoto";

                          parseFile_userPhoto = ParseFile(File(_userPhoto!.path), name: userPhoto_newFileName);
                        }

                        if (_identityFile != null) {
                          String identityFileName = p.basename(_identityFile!.path);
                          String extension_identityFile = p.extension(identityFileName);
                          String nomPiece = "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_pieceIdentite";
                          piece_newFileName = "$nomPiece$extension_identityFile";

                          parseFile_identityFile = ParseFile(_identityFile, name: piece_newFileName);
                        }

                        String createResult = await Identity.manageIdentity(
                          identityID: current_identity.identityID,
                          userID: current_user.userID,
                          photo: parseFile_userPhoto, // nullable
                          piece_identite: parseFile_identityFile, // nullable
                          photo_name: userPhoto_newFileName,
                          piece_name: piece_newFileName,
                        );

                        if (createResult == "success") {
                          await _sendEmailToAdmin();
                          String updateIdentity = await Users.updateIdentity(
                              widget.objectID, "En attente");
                          if (updateIdentity == "success") {
                            // si c'est un resto on va l'enregistrer d'abord
                            setState(() {
                              isLoading = false;
                            });
                            /*if (widget.user_roleID == 3) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => RestaurantFormPage()),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => IdentityCreated(),
                                ),
                              );
                            }*/
                          }
                        } else {
                          setState(() {
                            _identityFile = null;
                            _userPhoto = null;
                          });
                          Toast(
                              context,
                              "Erreur : vérifiez que les noms de vos fichiers respectent les conventions de nommage.",
                              false);
                        }
                      }
                    },
                    child: Text("VALIDER"),
                  ),
                ),

                SizedBox(height: size.height * 0.2),
              ],
            ),
          ),
        ));
  }
}

class PDFOrImageViewer extends StatelessWidget {
  final String url;

  const PDFOrImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.toLowerCase().endsWith(".pdf")) {
      return Scaffold(
        appBar: AppBar(title: Text("Aperçu PDF")),
        body: SfPdfViewer.network(url),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: Text("Aperçu Image")),
        body: Center(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      );
    }
  }
}
