import 'package:avatar_glow/avatar_glow.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../Constant/Constant.dart';
import '../../modeles/users.dart';
import 'PasswordResetScreen.dart';

class EmailInputScreen extends StatefulWidget {
  final List<Users> listusers;

  EmailInputScreen({required this.listusers});

  @override
  _EmailInputScreenState createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  Future<void> checkEmail() async {
    setState(() {
      isLoading = true;
    });

    // Simuler la vérification de l'email
    bool emailExists =
        await Users.checkEmailExists(widget.listusers, emailController.text);

    setState(() {
      isLoading = false;
    });

    if (emailExists) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PasswordResetScreen(
                email: emailController.text, listusers: widget.listusers)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucun compte trouvé avec cet email.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
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
                'Forgotten password',
                style: kLoginTitleStyle(size),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Please enter your email adress :",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    style: kTextFormFieldStyle(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_rounded),
                      hintText: 'Email address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                    ),
                    controller: emailController,
                    validator: (value) {
                      if (!EmailValidator.validate(value!)) {
                        return 'Please enter a valid email address';
                      }
                    },
                  ),
                  SizedBox(height: 20),
                  isLoading
                      ? CircularProgressIndicator()
                      : Center(
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
                                borderRadius: BorderRadius.circular(
                                    15), // Bordure du bouton
                              ),
                            ),
                            onPressed: checkEmail,
                            child: Text("Verify the email"),
                          ),
                        )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
