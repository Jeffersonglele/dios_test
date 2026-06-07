import 'dart:io';

import 'package:dios_delices/Screen/verif_confirm/IdentityCreated.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../Constant/Constant.dart';
import '../../utils/image_picker_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../theme/app_theme.dart';

import '../../modeles/identity.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../restaurants/RestaurantFormPage.dart';

class IdentityVerification extends ConsumerStatefulWidget {
  final int objectID;
  final int user_roleID;

  const IdentityVerification(
      {super.key, required this.objectID, required this.user_roleID});

  @override
  _IdentityVerificationState createState() => _IdentityVerificationState();
}

class _IdentityVerificationState extends ConsumerState<IdentityVerification> {
  final _formKey = GlobalKey<FormState>();

  List<Users> users = [];
  late Users current_user;

  File? _userPhoto;
  File? _identityFile;

  Future<void> _showPhotoSourcePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Prendre une photo"),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choisir depuis la galerie"),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotoFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text("Choisir un fichier image"),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotoFromFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final cameraSupported =
          await picker.supportsImageSource(ImageSource.camera);

      if (!cameraSupported) {
        if (!mounted) return;
        Toast(context,
            "La caméra n'est pas disponible sur ce simulateur. Utilisez un vrai iPhone pour prendre une photo.",
            false);
        return;
      }

      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        final confirmed = await showImageConfirmDialog(context, File(image.path));
        if (confirmed != null && mounted) {
          setState(() => _userPhoto = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Toast(context,
          "Impossible d'ouvrir l'appareil photo. Vérifiez l'autorisation caméra.",
          false);
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final confirmed = await showImageConfirmDialog(context, File(image.path));
        if (confirmed != null && mounted) {
          setState(() => _userPhoto = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Toast(context, "Impossible d'ouvrir la galerie.", false);
    }
  }

  Future<void> _pickPhotoFromFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result?.files.single.path != null) {
      setState(() {
        _userPhoto = File(result!.files.single.path!);
      });
    }
  }

  Future<void> _showIdentitySourcePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choisir une image depuis la galerie"),
                onTap: () {
                  Navigator.pop(context);
                  _pickIdentityFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text("Choisir dans les fichiers"),
                subtitle: const Text("Image ou PDF"),
                onTap: () {
                  Navigator.pop(context);
                  _pickIdentityFromFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickIdentityFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final confirmed = await showImageConfirmDialog(context, File(image.path));
        if (confirmed != null && mounted) {
          setState(() => _identityFile = confirmed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Toast(context, "Impossible d'ouvrir la galerie.", false);
    }
  }

  Future<void> _pickIdentityFromFiles() async {
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

  bool _isPdf(File file) {
    return p.extension(file.path).toLowerCase() == '.pdf';
  }

  Widget _buildImagePreview(File file, {double size = 120}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildIdentityPreview(File file) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(file.path);

    if (_isPdf(file)) {
      return Column(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: SfPdfViewer.file(file),
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: colorScheme.onSurface),
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
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: colorScheme.onSurface),
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
    } catch (e) {
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
    Users? user = await Users.getUsersByUserId(usersList, widget.objectID);

    setState(() {
      users = usersList;
      current_user = user!;
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

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
                    'Mon identité',
                    style: AppTypography.displayMedium(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const SizedBox(height: 30),

                Center(
                  child: Column(
                    children: [
                      // 📸 Photo de l'utilisateur
                      Text(
                        'Votre photo',
                        style: AppTypography.titleMedium(
                                color: colorScheme.onSurface)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _userPhoto != null
                          ? _buildImagePreview(_userPhoto!)
                          : Text("Aucune photo prise",
                              style: AppTypography.bodyMedium(
                                  color: colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                            foregroundColor: Colors.white),
                        onPressed: _showPhotoSourcePicker,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text("Ajouter une photo"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                Center(
                  child: Column(
                    children: [
                      // 🪪 Pièce d'identité
                      Text(
                        'Pièce d\'identité (image ou PDF)',
                        style: AppTypography.titleMedium(
                                color: colorScheme.onSurface)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _identityFile != null
                          ? _buildIdentityPreview(_identityFile!)
                          : Text("Aucun fichier sélectionné",
                              style: AppTypography.bodyMedium(
                                  color: colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                            foregroundColor: Colors.white),
                        onPressed: _showIdentitySourcePicker,
                        icon: const Icon(Icons.file_present),
                        label: const Text("Ajouter une pièce d'identité"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 🔘 Valider
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    onPressed: () async {
                      if (_userPhoto == null || _identityFile == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Merci de fournir une photo et une pièce d'identité")),
                          );
                        }
                        return;
                      } else {
                        ParseFile? parseFile_userPhoto;
                        ParseFile? parseFile_identityFile;

                        String _userPhoto_fileName =
                            p.basename(_userPhoto!.path); // Get the file name
                        String extension_userPhoto = p.extension(
                            _userPhoto_fileName); // Get the file extension (.jpg, .png)
                        String nom_userPhoto =
                            "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_photo"; // New image name
                        String userPhoto_newFileName =
                            "$nom_userPhoto$extension_userPhoto"; // Combine name and extension
                        parseFile_userPhoto = ParseFile(File(_userPhoto!.path),
                            name: userPhoto_newFileName);

                        String identityFileName =
                            p.basename(_identityFile!.path);
                        String extension_identityFile =
                            p.extension(identityFileName); // .jpg, .pdf, etc.
                        String nomPiece =
                            "${current_user.firstname}_${current_user.lastname}_${current_user.userID}_pieceIdentite";
                        String piece_newFileName =
                            "$nomPiece$extension_identityFile";
                        parseFile_identityFile =
                            ParseFile(_identityFile, name: piece_newFileName);

                        String createResult = await Identity.manageIdentity(
                            userID: current_user.userID,
                            photo: parseFile_userPhoto,
                            piece_identite: parseFile_identityFile,
                            photo_name: userPhoto_newFileName,
                            piece_name: piece_newFileName);

                        if (createResult == "success") {
                          await _sendEmailToAdmin();
                          String updateIdentity = await Users.updateIdentity(
                              widget.objectID, "En attente");
                          if (updateIdentity == "success") {
                            // si c'est un resto on va l'enregistrer d'abord
                            if (widget.user_roleID == 3) {
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          RestaurantFormPage()),
                                );
                              }
                            } else {
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IdentityCreated(),
                                  ),
                                );
                              }
                            }
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
                    child: const Text("Valider"),
                  ),
                ),

                SizedBox(height: size.height * 0.2),
              ],
            ),
          ),
        ));
  }
}
