import 'package:get/get.dart';

class MyTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'signup': 'Sign up',
      'firstname': 'First Name',
      'lastname': 'Last Name',
      'username': 'Username',
      'email': 'Email address',
      'password': 'Password',
      'confirm_password': 'Confirm password',
      'already_have_account': 'Already have an account?',
      'login': 'Login',
    },
    'fr_FR': {
      'signup': 'Inscription',
      'firstname': 'Prénom',
      'lastname': 'Nom',
      'username': "Nom d'utilisateur",
      'email': 'Adresse mail',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'already_have_account': 'Vous avez déjà un compte ?',
      'login': 'Connexion',
    }
  };
}
