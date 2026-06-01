import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../Constant/Constant.dart';
import '../../modeles/identity.dart';
import '../../modeles/users.dart';
import '../../utils/toast.dart';
import '../../widgets/dios_image.dart';

class UserDetails extends ConsumerStatefulWidget {
  static const routeName = '/UserDetailsUser';

  final int user_id;

  UserDetails({required this.user_id});

  @override
  _UserDetailsState createState() => _UserDetailsState();
}

class _UserDetailsState extends ConsumerState<UserDetails> {
  final _formKey = GlobalKey<FormState>();
  String? country = "";
  int currentUser_user = 0;
  int currentUser_role = 0;
  int currentUser_id = 0;
  String currentUser_country = "";

  //bool isEditMode = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  TextEditingController nameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController lastnameController = TextEditingController();
  TextEditingController nbOrdersController = TextEditingController();
  TextEditingController nbServingsController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  TextEditingController categoriesController = TextEditingController();
  bool isAvailable = true;
  bool select_image = false;

  List<Identity> identities = [];
  List<Identity> filteredIdentities = [];

  Users? current_user;
  Identity? current_identity;
  Restaurant? current_user_restaurant;

  List<Restaurant> restaurants = [];

  String type_profil = "...";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {

      // Chargement des users et des plats depuis la base de données
      List<Users> usersList = await Users.fetchUsersFromDB();
      Users? user = await Users.getUsersByUserId(usersList, widget.user_id);

      List<Identity> allIdentities = await Identity.fetchIdentitiesFromDB();

      List<Restaurant> restaurantsList = await Restaurant.fetchRestaurantsFromDB();

      // Filtrage des plats associés au user actuel
      // On cherche une identité dont l'userID correspond à celui du widget
      Identity? identity = allIdentities.firstWhere((identity) => identity.userID == widget.user_id);

      Restaurant? restaurant = Restaurant.getRestaurantByUser(restaurantsList, widget.user_id);

      // Mise à jour de l'état
      setState(() {
        current_user = user;
        current_identity = identity;
        current_user_restaurant = restaurant;

        restaurants = restaurantsList;

        if (current_user != null) {
          nameController.text = current_user!.firstname!;
        }

        if (current_user?.roleID == 1) {
          type_profil = "Administrateur";
        } else if (current_user?.roleID == 2) {
          type_profil = "Particulier";
          print("Particulier");
        } else if (current_user?.roleID == 3) {
          type_profil = "Restaurateur";
        } else if (current_user?.roleID == 4) {
          type_profil = "Super-Administrateur";
        }

      });
    } catch (e) {
      print("Erreur lors du chargement des données : $e");
    }
  }

  bool hasChanges() {
    return selectedImage != null ||
        nameController.text != current_user!.firstname ||
        lastnameController.text != current_user!.lastname ||
        isAvailable != (current_user!.identity == "Verified");
  }

  bool hasNewImage() {
    return selectedImage != null;
  }

  void _handleFilePreview(BuildContext context, String fileUrl) async {
    if (fileUrl.toLowerCase().endsWith(".pdf")) {
      // Télécharger et ouvrir le PDF
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(fileUrl: fileUrl),
        ),
      );
    } else {
      // Ouvrir image plein écran
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(imageUrl: fileUrl),
        ),
      );
    }
  }

  Future<bool> _sendEmailToUser(Users user, bool valid, [String? remark]) async {
    final recipientEmail = user?.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre profil est validé !'
        : '❌ Mise à jour : Validation de votre profil sur Dios Délices';

    final messageText = valid
        ? 'Bonjour ${user?.firstname},\n\n'
        'Nous sommes ravis de vous informer que votre profil a été validé. '
        'Vous pouvez maintenant accéder à votre compte pour gérer votre profil et recevoir des commandes.\n\n'
        'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user?.firstname},\n\n'
        'Nous regrettons de vous informer que votre profil n’a pas été validé suite à notre processus de vérification.\n\n'
        'Raison du rejet : ${remark ?? "Non spécifiée"}\n\n'
        'Pour plus d’informations, n’hésitez pas à nous contacter.\n\n'
        'Cordialement,\nL’équipe Dios Délices';

    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText,
      });
      print('Email envoyé avec succès');
      return true;
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    if (current_user == null) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.03),
                  Stack(
                    children: [
                      Container(
                        constraints:
                            BoxConstraints.expand(height: 300.0, width: 400),
                        padding: EdgeInsets.only(
                            left: 16.0, bottom: 8.0, right: 16.0),
                        margin: EdgeInsets.only(
                            left: 16.0, bottom: 8.0, right: 16.0),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(current_identity?.photo ??
                                "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png"),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Positioned(
                              right: 0.0,
                              top: 5,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  // Coins arrondis
                                  color: Colors.white,
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: CircleAvatar(
                                    radius: 6, // Taille du cercle
                                    backgroundColor:
                                        isAvailable ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(height: size.height * 0.02),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      Text(
                          current_user!.firstname +
                              " " +
                              current_user!.lastname,
                          style: kLoginSubtitleStyle(size)),
                      Spacer(),
                      Text(
                        "..",
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      Text("Type de profil : ", style: TextStyle(fontSize: 16)),
                      Text(type_profil, style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      Text("Pièce d'identité :",
                          style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: Icon(Icons.camera_alt),
                        onPressed: () => _handleFilePreview(
                            context, current_identity?.piece_identite ?? ""),
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  current_user?.identity != "Verified" ? Row(
                    children: [
                      SizedBox(width: 25),
                      Text(
                        "Valider le profil : ",
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _validateUsers(current_user!),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _showRejectDialog(current_user!),
                      ),
                    ],
                  ) : SizedBox(),
                  SizedBox(height: 8),
                  current_user_restaurant == null ? SizedBox() :Row(
                    children: [
                      SizedBox(width: 25),
                      Text(
                        "Restaurant ",
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  current_user_restaurant == null ? SizedBox() : Card(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: DiosImage(
                                  url: current_user_restaurant?.image,
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),
                            title: Text(
                              current_user_restaurant?.name ?? "Nom non défini",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              current_user_restaurant?.categories ?? "",
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RestaurantDetails(
                                    restaurant_id: current_user_restaurant!.restaurantID,
                                  ),
                                ),
                              );
                            },
                          ),

                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                nameController.text =
                                    current_user?.firstname ?? "";
                                lastnameController.text =
                                    current_user?.lastname ?? "";
                              });
                            },
                            child: Text('Modifier',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              textStyle: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(Users users) {
    final TextEditingController remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Rejeter le profil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Ajouter une remarque pour l'utilisateur :"),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Saisissez votre remarque ici...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler', style: TextStyle(color: Colors.green),),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectUsers(users, remarkController.text);
              },
              child: Text('Envoyer', style: TextStyle(color: Colors.red),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateUsers(Users users) async {
    String updateResult = await Users.updateIdentity(users.userID, "Verified"); // Correction du nom de la méthode
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, true);
      if (emailSent) {
        setState(() {
          users.identity = "Verified";
        });
        Toast(context, "Le profil de l'utilisateur ${users.firstname} ${users.lastname} a été validé et un mail a été envoyé à l'utilisateur.", true);
      } else {
        Toast(context, "Le profil de l'utilisateur ${users.firstname} ${users.lastname} a été validé, mais une erreur est survenue lors de l'envoi de l'email.", false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }

  Future<void> _rejectUsers(Users users, String remark) async {
    String updateResult = await Users.updateIdentity(users.userID, "Rejected"); // profil rejeté
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, false, remark); // Passer la remarque ici
      if (emailSent) {
        setState(() {
          users.identity = "Rejected";
        });
        Toast(context, "Le profil de l'utilisateur ${users.firstname} ${users.lastname} a été rejeté et un mail a été envoyé à l'utilisateur.", false);
      } else {
        Toast(context, "Le profil de l'utilisateur ${users.firstname} ${users.lastname} a été rejeté, mais une erreur est survenue lors de l'envoi de l'email.", false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }
}

Widget buildImage(String? imageUrl) {
  if (imageUrl != null && imageUrl.trim().isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
    return Image.network(
      imageUrl,
      height: 200,
      width: 200,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/no_image.png',
          // Image par défaut si le chargement échoue
          height: 200,
          width: 200,
          fit: BoxFit.fitWidth,
        );
      },
    );
  } else {
    // Si ce n'est pas une URL valide, utilisez une image locale
    return Image.asset(
      'assets/images/no_image.png',
      height: 200,
      width: 200,
      fit: BoxFit.fitWidth,
    );
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String fileUrl;

  PDFViewerScreen({required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Aperçu du PDF')),
      body: SfPdfViewer.network(fileUrl),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Piièce d'identité")),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (_, __) => CircularProgressIndicator(),
          errorWidget: (_, __, ___) => Icon(Icons.error),
        ),
      ),
    );
  }
}
