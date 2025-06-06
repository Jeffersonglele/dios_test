import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_flutter/twilio_flutter.dart';

import '../../Constant/Constant.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../utils/toast.dart';
import '../authentification/Login.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final int roleID; //c'est la création de compte pour un utilisateur lambda
  final int telephone;
  final int userID;
  final String password;
  final String firstname;
  final String lastname;
  final String username;
  final String password_crypte;
  final String indicatif;

  VerificationPage(
      {required this.email,
      required this.username,
      required this.userID,
      required this.roleID,
      required this.telephone,
      required this.password_crypte,
      required this.password,
      required this.firstname,
      required this.indicatif,
      required this.lastname});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  late TwilioFlutter twilioFlutter;
  String generatedSmsCode = "";

  String? mail_verificationCode = "";
  String sms_verificationCode = "";

  DateTime mail_codeGenerationTime = DateTime.now();
  DateTime sms_codeGenerationTime = DateTime.now();

  String? verificationCode;

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  Future<void> _initializeVerification() async {
    twilioFlutter = TwilioFlutter(
      accountSid: 'AC58d8e7c62d49c0c3084ea2a074c56023',
      authToken: '3ad23444b373e36f2d67b85601686276',
      twilioNumber: '+16193658244',
    );

    try {
      await _sendSmsCode();
      await _sendEmailCode();

      Toast(context, "Code de vérification envoyé par SMS et email.", true);
    } catch (e) {
      print("Erreur globale dans _initializeVerification : $e");
      Toast(context, "Erreur lors de l'envoi des codes.", false);
    }
  }

  Future<void> _sendEmailCode() async {
    try {
      print("widget.email: ${widget.email}");
      mail_verificationCode =
          await sendVerificationEmail(context, widget.email);
      mail_codeGenerationTime = DateTime.now();

      print("Email envoyé, code : $mail_verificationCode");
    } catch (e) {
      print("Erreur lors de l'envoi du mail : $e");
      Toast(context, "Erreur lors de l'envoi de l'e-mail.", false);
    }
  }

  Future<void> _sendSmsCode() async {
    generatedSmsCode =
        (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
            .toString(); // Code à 6 chiffres

    try {
      final response = await twilioFlutter.sendSMS(
        toNumber: formatPhoneNumber(widget.telephone),
        messageBody: 'Votre code de vérification est : $generatedSmsCode',
      );

      print("SMS envoyé avec succès : $response");
    } catch (e) {
      print("Erreur lors de l'envoi du SMS : $e");
      Toast(context, "Erreur lors de l'envoi du SMS.", false);
    }
  }

  Future<bool> verifySmsCode(String enteredCode) async {
    return enteredCode == generatedSmsCode;
  }

  String formatPhoneNumber(int phone) {
    String phoneStr = phone.toString();
    if (!phoneStr.startsWith("+")) {
      phoneStr = "${widget.indicatif}$phoneStr"; // Ajoute l'indicatif
    }
    return phoneStr.replaceAll(RegExp(r'\s+'), ""); // Supprime les espaces
  }

  @override
  void dispose() {
    _codeController.dispose();
    _smsCodeController.dispose();
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
                    Text(
                      "Please enter the verification code sent to ${widget.email}",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 20),
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
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
                    SizedBox(height: 10),
                    //Text("Please enter the SMS code sent to ${widget.telephone}"),
                    Text(
                      "Please enter the SMS code sent to ${widget.telephone}",
                      style: TextStyle(fontSize: 16),
                    ),
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      obscureText: false,
                      animationType: AnimationType.fade,
                      controller: _smsCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        /*onPressed: () async {
                        bool valid = isCodeValid(widget.verificationCode ?? "aaa",
                            _codeController.text, widget.codeGenerationTime);
                        if (valid) {
                          print("valid");
                          ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                              content: new Text("Code valide", style: TextStyle(
                                fontSize: 18, // Taille du texte
                                fontWeight: FontWeight
                                    .bold, // (Optionnel) Style de texte en gras
                              ),)));

                          List<Users> listUsers = await Users.fetchUsersFromDB();
                          print("listUsers " + listUsers.toString());

                          String validationResult = await Users.manageUser(
                              roleID: 2, //c'est la création de compte pour un utilisateur lambda
                              password: widget.password,
                              password_crypte:  widget.password_crypte,
                              firstname:  widget.firstname,
                              lastname:  widget.lastname,
                              username:  widget.username,
                              email:  widget.email,
                              telephone: widget.telephone
                          );


                          Toast(
                              context,
                              validationResult == "success"
                                  ? "Utilisateur ajouté avec succès. Vous pouvez maintenant vous connecter."
                                  : "Erreur : $validationResult",
                              validationResult == "success"
                                  ? true
                                  : false);

                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          bool? userCreated = prefs.getBool('userCreated');

                          if(userCreated == true){
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => Login()),  // Remplace Login() par la page de connexion
                            );
                          } else {
                            Navigator.pop(context);
                          }

                        } else {
                          print("not valid");
                          ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                              content: new Text("Code non valide", style: TextStyle(
                                fontSize: 18, // Taille du texte,
                                color: Colors.red,
                                fontWeight: FontWeight
                                    .bold, // (Optionnel) Style de texte en gras
                              ),)));
                        }
                      },*/
                        onPressed: () async {
                          bool emailValid = isCodeValid(
                              mail_verificationCode ?? "aaa",
                              _codeController.text,
                              mail_codeGenerationTime);
                          bool smsValid =
                          await verifySmsCode(_smsCodeController.text);

                          if (emailValid && smsValid) {
                            Toast(context, "Vérification réussie", true);


                            try {
                              await Users.updateStatus(widget.userID, "Verified");
                              SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                              await prefs.setBool('userVerified', true);

                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Login()));
                            } catch (e) {}

                            /*String validationResult = await Users.manageUser(
                              roleID: 2,
                              password: widget.password,
                              password_crypte: widget.password_crypte,
                              firstname: widget.firstname,
                              lastname: widget.lastname,
                              username: widget.username,
                              email: widget.email,
                              telephone: widget.telephone, status: '', identity: '', addressID: 0,
                            );

                            if (validationResult == "success") {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('userVerified', true);

                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Login()));
                            } else {
                              Toast(context, "Erreur : $validationResult", false);
                            }*/
                          } else {
                            /*ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("1 ou  2 code(s) non valide(s)",
                                style: TextStyle(color: Colors.white)),
                          ));*/
                            Toast(context, "Erreur : 1 ou  2 code(s) non valide(s)", false);
                          }
                        },
                        child: Text("Verify"),
                      ),
                    )
                  ],
                ),
              ),
            ],
          )
        ),
    );
  }
}
