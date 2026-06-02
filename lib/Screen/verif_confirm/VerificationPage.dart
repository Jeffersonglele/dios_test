import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../core/app_role.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../services/session_service.dart';
import '../../components/showConfetti.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final int roleID; //c'est la création de compte pour un utilisateur lambda
  final String telephone;
  final int userID;
  final String password;
  final String firstname;
  final String lastname;
  final String username;
  final String password_crypte;
  final String indicatif;
  final String country;

  VerificationPage(
      {required this.email,
      required this.username,
      required this.userID,
      required this.roleID,
      required this.telephone,
      required this.password_crypte,
      required this.password,
      required this.firstname,
      required this.country,
      required this.indicatif,
      required this.lastname});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _codeController = TextEditingController();

  bool _isSendingCodes = true;
  String? _sendErrorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  Future<void> _initializeVerification() async {
    final emailSent = await _sendEmailCode();

    if (!mounted) return;

    setState(() {
      _isSendingCodes = false;
      _sendErrorMessage = emailSent ? null : _buildSendErrorMessage();
    });

    if (emailSent) {
      Toast(
        context,
        "Code de vérification envoyé par email.",
        true,
      );
    } else {
      Toast(context, _sendErrorMessage!, false);
    }
  }

  Future<bool> _sendEmailCode() async {
    try {
      return await sendVerificationEmail(context, widget.email);
    } catch (e) {
      print("Erreur lors de l'envoi du mail : $e");
      return false;
    }
  }

  String _buildSendErrorMessage() {
    return "Impossible d'envoyer le code email.";
  }

  String _countryOrDefault(String country) {
    final cleanCountry = country.trim();
    return cleanCountry.isEmpty ? "Bénin" : cleanCountry;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: size.width > 600
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          SizedBox(height: 5),
          size.width > 600
              ? Container() // N'affiche pas l'avatar sur les grands écrans
              : const Center(child: BrandAvatarLogo()),
          SizedBox(height: size.height * 0.03),
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Text(
              'Verification Code',
              style: kLoginTitleStyle(
                  size), // Assurez-vous que cette fonction est bien appelée ici
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSendingCodes) ...[
                  Center(
                    child: Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Envoi du code de vérification..."),
                      ],
                    ),
                  ),
                ] else if (_sendErrorMessage != null) ...[
                  Text(
                    _sendErrorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isSendingCodes = true;
                          _sendErrorMessage = null;
                        });
                        _initializeVerification();
                      },
                      child: const Text("Renvoyer le code"),
                    ),
                  ),
                ] else ...[
                  Text(
                    "Entrez le code envoyé par email à ${widget.email}",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  PinCodeTextField(
                    appContext: context,
                    length: 6,
                    autoDisposeControllers: false,
                    // Le code a 6 chiffres
                    obscureText: false,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(5),
                      fieldHeight: 50,
                      fieldWidth: 40,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.grey[200],
                      selectedFillColor: Colors.white,
                    ),
                    animationDuration: Duration(milliseconds: 300),
                    backgroundColor: Colors.transparent,
                    enableActiveFill: true,
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onCompleted: (v) {
                      print(
                          "Code entered: $v"); // Action après avoir entré les 6 chiffres
                    },
                    onChanged: (value) {
                      print(
                          value); // Mettre à jour l'état à chaque chiffre entré
                    },
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        // Couleur de fond du bouton
                        foregroundColor: Colors.white,
                        //Couleur du texte
                        textStyle: TextStyle(
                          fontSize: 18, // Taille du texte
                          fontWeight: FontWeight
                              .bold, // (Optionnel) Style de texte en gras
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(15), // Bordure du bouton
                        ),
                      ),
                      onPressed: () async {
                        final code = _codeController.text.trim();
                        if (code.isEmpty) {
                          Toast(context, 'Veuillez entrer le code.', false);
                          return;
                        }
                        final valid = await verifyEmailCode(email: widget.email, code: code);
                        if (valid) {
                          try {
                            await Users.updateStatus(widget.userID, "Verified");
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('userVerified', true);
                            final country = _countryOrDefault(widget.country);

                            await SessionService.saveUserSession(
                              userId: widget.userID,
                              role: AppRole.fromId(widget.roleID),
                              country: country,
                            );
                            await Users.updateDerniereConnexion(widget.userID);

                            if (!mounted) return;

                            Toast(context, "Vérification réussie", true);

                            final welcomeKey = 'has_seen_welcome_${widget.userID}';
                            final hasSeenWelcome = prefs.getBool(welcomeKey) ?? false;

                            if (!hasSeenWelcome) {
                              await prefs.setBool(welcomeKey, true);
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WelcomeScreen(),
                                ),
                              );
                            } else {
                              if (!mounted) return;
                              Users.chooseCurvedNavigation(
                                widget.roleID,
                                country,
                                context,
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            Toast(
                              context,
                              "Erreur lors de la validation du compte.",
                              false,
                            );
                          }
                        } else {
                          Toast(context, "Erreur : code email non valide.",
                              false);
                        }
                      },
                      child: Text("Vérifier"),
                    ),
                  )
                ],
              ],
            ),
          ),
        ],
      )),
    );
  }
}
