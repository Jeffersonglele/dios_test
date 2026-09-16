
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/onboarding/identity_created.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:dios_delices/widgets/dios_image.dart';
import 'package:dios_delices/utils/image_picker_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../constants/constant.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../models/identity.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../restaurants/restaurant_form_page.dart';

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

  XFile? _userPhoto;
  XFile? _identityFile;

  bool isLoading = true;

  Future<void> _showPhotoSourcePicker() async {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(l10n.take_a_photo),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.choose_from_gallery),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhotoFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(l10n.choose_image_file),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhotoFromFiles();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final cameraSupported =
          await picker.supportsImageSource(ImageSource.camera);

      if (!cameraSupported) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        Toast(context, l10n.identity_camera_unavailable, false);
        return;
      }

      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        final confirmed =
            await showImageConfirmDialog(context, image);
        if (confirmed != null && mounted) {
          setState(() => _userPhoto = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      Toast(context, l10n.identity_camera_error, false);
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final confirmed =
            await showImageConfirmDialog(context, image);
        if (confirmed != null && mounted) {
          setState(() => _userPhoto = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      Toast(context, l10n.identity_gallery_error, false);
    }
  }

  Future<void> _pickPhotoFromFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    final file = result?.files.single;
    if (file?.bytes != null) {
      setState(() {
        _userPhoto = XFile.fromData(file!.bytes!, name: file.name);
      });
    }
  }

  Future<void> _showIdentitySourcePicker() async {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.choose_image_from_gallery),
                  onTap: () {
                    Navigator.pop(context);
                    _pickIdentityFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(l10n.choose_from_files),
                  subtitle: Text(l10n.image_or_pdf),
                  onTap: () {
                    Navigator.pop(context);
                    _pickIdentityFromFiles();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickIdentityFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final confirmed =
            await showImageConfirmDialog(context, image);
        if (confirmed != null && mounted) {
          setState(() => _identityFile = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      Toast(context, l10n.identity_gallery_error, false);
    }
  }

  Future<void> _pickIdentityFromFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes != null) {
      setState(() {
        _identityFile = XFile.fromData(file!.bytes!, name: file.name);
      });
    }
  }

  bool _isPdf(XFile file) {
    return p.extension(file.name).toLowerCase() == '.pdf';
  }

  Widget _buildImagePreview(XFile file, {double size = 120}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: pickedImagePreview(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildIdentityPreview(XFile file) {
    final fileName = file.name;

    if (_isPdf(file)) {
      return Column(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder(
              future: file.readAsBytes(),
              builder: (context, snapshot) => snapshot.hasData
                  ? SfPdfViewer.memory(snapshot.data!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildImagePreview(file, size: 180),
        const SizedBox(height: 8),
        Text(
          fileName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // Fonction pour envoyer un email à l'admin avec les infos du restaurant
  Future<void> _sendEmailToAdmin() async {
    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': 'blandinedupont087@gmail.com',
        'subject': 'Nouvelle identité en attente de vérification',
        'text': "Connectez-vous pour valider ou non l'utilisateur.",
      });
    } catch (e) {}
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
    Identity? identity =
        await Identity.getIdentityByUserId(identitiesList, widget.objectID);

    setState(() {
      users = usersList;
      identities = identitiesList;
      current_user = user!;
      current_identity = identity!;
    });
  }

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
                    l10n.identity_title,
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
                        l10n.identity_your_photo,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      _userPhoto != null
                          ? _buildImagePreview(_userPhoto!)
                          : current_identity.photo != null
                              ? SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: DiosImage(
                                    url: current_identity.photo,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(l10n.no_photo_available),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _showPhotoSourcePicker,
                        icon: Icon(Icons.add_a_photo),
                        label: Text(l10n.add_a_photo),
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
                        l10n.identity_id_document,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      _identityFile != null
                          ? _buildIdentityPreview(_identityFile!)
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
                                              url: current_identity
                                                      .piece_identite ??
                                                  "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(l10n.view_existing_file),
                                    ),
                                  ],
                                )
                              : Text(l10n.no_file_selected),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _showIdentitySourcePicker,
                        icon: Icon(Icons.file_present),
                        label: Text(l10n.add_identity_document),
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
                            textStyle: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () async {
                            if (_userPhoto == null && _identityFile == null) {
                              final l10n = AppLocalizations.of(context)!;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(l10n.please_modify_a_file)),
                              );
                              return;
                            } else {
                              ParseFileBase? parseFile_userPhoto;
                              ParseFileBase? parseFile_identityFile;

                              String userPhoto_newFileName =
                                  current_identity.photo ?? "";
                              String piece_newFileName =
                                  current_identity.piece_identite ?? "";

                              if (_userPhoto != null) {
                                String _userPhoto_fileName =
                                    p.basename(_userPhoto!.path);
                                String extension_userPhoto =
                                    p.extension(_userPhoto_fileName);
                                String nom_userPhoto =
                                    "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_photo";
                                userPhoto_newFileName =
                                    "$nom_userPhoto$extension_userPhoto";

                                parseFile_userPhoto = ParseXFile(
                                    _userPhoto!,
                                    name: userPhoto_newFileName);
                              }

                              if (_identityFile != null) {
                                String identityFileName =
                                    p.basename(_identityFile!.path);
                                String extension_identityFile =
                                    p.extension(identityFileName);
                                String nomPiece =
                                    "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_pieceIdentite";
                                piece_newFileName =
                                    "$nomPiece$extension_identityFile";

                                parseFile_identityFile = ParseXFile(
                                    _identityFile,
                                    name: piece_newFileName);
                              }

                              String createResult =
                                  await Identity.manageIdentity(
                                identityID: current_identity.identityID,
                                userID: current_user.userID,
                                photo: parseFile_userPhoto, // nullable
                                piece_identite:
                                    parseFile_identityFile, // nullable
                                photo_name: userPhoto_newFileName,
                                piece_name: piece_newFileName,
                              );

                              if (createResult == "success") {
                                await _sendEmailToAdmin();
                                String updateIdentity =
                                    await Users.updateIdentity(
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
                                    context, l10n.identity_naming_error, false);
                              }
                            }
                          },
                          child: Text(l10n.validate_caps),
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
          child: DiosImage(url: url, fit: BoxFit.contain),
        ),
      );
    }
  }
}
