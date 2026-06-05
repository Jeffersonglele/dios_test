import 'package:shared_preferences/shared_preferences.dart';

class Strings {
  static String _lang = 'fr';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('app_language') ?? 'fr';
  }

  static void setLanguage(String code) {
    _lang = code;
  }

  static String get(String fr, [String? en]) {
    return _lang == 'en' && en != null ? en : fr;
  }

  // ── Général ──
  static String get ok => get('OK', 'OK');
  static String get cancel => get('Annuler', 'Cancel');
  static String get save => get('Enregistrer', 'Save');
  static String get delete => get('Supprimer', 'Delete');
  static String get confirm => get('Confirmer', 'Confirm');
  static String get modify => get('Modifier', 'Edit');
  static String get validate => get('Valider', 'Validate');
  static String get required => get('Requis', 'Required');
  static String get error => get('Erreur', 'Error');
  static String get success => get('Succès', 'Success');
  static String get retry => get('Réessayer', 'Retry');
  static String get search => get('Rechercher', 'Search');
  static String get filter => get('Filtrer', 'Filter');
  static String get remove => get('Retirer', 'Remove');
  static String get allFieldsRequired => get('Tous les champs sont requis', 'All fields are required');
  static String get reject => get('Rejeter', 'Reject');
  static String get close => get('Fermer', 'Close');
  static String get create => get('Créer', 'Create');
  static String get open => get('Ouvert', 'Open');
  static String get closed => get('Fermé', 'Closed');
  static String get refresh => get('Actualiser', 'Refresh');
  static String get add => get('Ajouter', 'Add');
  static String get all => get('Tous', 'All');
  static String get hello => get('Bonjour', 'Hello');
  static String get thisMonth => get('ce mois', 'this month');
  static String get confirmedPlural => get('confirmées', 'confirmed');
  static String get cancelledPlural => get('annulées', 'cancelled');

  // ── Navigation ──
  static String get home => get('Accueil', 'Home');
  static String get menu => get('Menu', 'Menu');
  static String get cart => get('Panier', 'Cart');
  static String get favorites => get('Favoris', 'Favorites');
  static String get noFavorites => get('Aucun favori', 'No favorites');
  static String get boutique => get('Boutique', 'Store');
  static String get settings => get('Paramètres', 'Settings');
  static String get mySpace => get('Mon espace', 'My Space');
  static String get logout => get('Déconnexion', 'Logout');
  static String get dashboard => get('Dashboard', 'Dashboard');

  // ── Authentification ──
  static String get login => get('Connexion', 'Login');
  static String get signup => get('Inscription', 'Sign Up');
  static String get email => get('Email', 'Email');
  static String get password => get('Mot de passe', 'Password');
  static String get username => get("Nom d'utilisateur", 'Username');
  static String get firstName => get('Prénom', 'First Name');
  static String get lastName => get('Nom', 'Last Name');
  static String get phone => get('Téléphone', 'Phone');
  static String get forgotPassword => get('Mot de passe oublié ?', 'Forgot password?');
  static String get loginFailed => get('Échec de connexion', 'Login failed');
  static String get connectError => get('Erreur de connexion. Vérifiez votre réseau.', 'Connection error. Check your network.');
  static String get loginSuccess => get('Connecté avec succès', 'Logged in successfully');
  static String get verificationCode => get('Code de vérification', 'Verification code');
  static String get resendCode => get('Renvoyer le code', 'Resend code');
  static String get logoutConfirm => get('Voulez-vous vraiment vous déconnecter ?', 'Are you sure you want to logout?');

  // ── Restaurants ──
  static String get myRestaurant => get('Mon restaurant', 'My restaurant');
  static String get createRestaurant => get('Créer un restaurant', 'Create restaurant');
  static String get restaurantName => get('Nom du restaurant', 'Restaurant name');
  static String get restaurantDescription => get('Description', 'Description');
  static String get restaurantAddress => get('Adresse', 'Address');
  static String get openingHours => get("Horaires d'ouverture", 'Opening hours');
  static String get openingDays => get("Jours d'ouverture", 'Opening days');
  static String get deliveryFee => get('Frais de livraison', 'Delivery fee');
  static String get addPhoto => get('Ajouter une photo', 'Add photo');
  static String get pendingValidation => get('En attente de validation', 'Pending validation');
  static String get validated => get('Validé', 'Validated');
  static String get rejected => get('Rejeté', 'Rejected');
  static String get validatedWithSuccess => get('validé avec succès', 'validated successfully');
  static String get rejectedStatus => get('rejeté', 'rejected');
  static String get becomeRestaurateur => get('Devenir micro-restaurateur', 'Become a home chef');
  static String get recoveryModes => get('Modes de récupération', 'Recovery modes');
  static String get delivery => get('Livraison', 'Delivery');
  static String get pickup => get('Ramassage', 'Pickup');
  static String get comeBackHome => get("Retourner à l'accueil", 'Go back to home');
  static String get refreshStatus => get('Rafraîchir le statut', 'Refresh status');
  static String get restaurantUpdated => get('Restaurant mis à jour', 'Restaurant updated');
  static String get restaurantNotValidated => get("Votre restaurant n'a pas encore été validé.", 'Your restaurant has not been validated yet.');
  static String get willReceiveMail => get('Vous recevrez un mail si votre idée de restaurant est acceptée.', 'You will receive an email if your restaurant idea is accepted.');

  // ── Plats ──
  static String get addDish => get('Ajouter un plat', 'Add dish');
  static String get dishName => get('Nom du plat', 'Dish name');
  static String get dishDescription => get('Description du plat', 'Dish description');
  static String get dishPrice => get('Prix', 'Price');
  static String get servings => get('Portions', 'Servings');
  static String get available => get('Disponible', 'Available');
  static String get unavailable => get('Indisponible', 'Unavailable');
  static String get addOption => get('Ajouter une option', 'Add option');
  static String get options => get('Options', 'Options');
  static String get categories => get('Catégories', 'Categories');
  static String get mainPhoto => get('Photo principale', 'Main photo');
  static String get secondaryPhoto => get('Photo secondaire', 'Secondary photo');

  // ── Commandes ──
  static String get orders => get('Commandes', 'Orders');
  static String get myOrders => get('Mes commandes', 'My orders');
  static String get pending => get('En attente', 'Pending');
  static String get confirmed => get('Confirmée', 'Confirmed');
  static String get delivered => get('Livrée', 'Delivered');
  static String get cancelled => get('Annulée', 'Cancelled');
  static String get total => get('Total', 'Total');
  static String get subtotal => get('Sous-total', 'Subtotal');
  static String get clearCart => get('Vider le panier', 'Clear cart');
  static String get order => get('Commander', 'Order');
  static String get orderConfirmed => get('Commande confirmée', 'Order confirmed');

  // ── Admin ──
  static String get users => get('Utilisateurs', 'Users');
  static String get restaurants => get('Restaurants', 'Restaurants');
  static String get livreurs => get('Livreurs', 'Drivers');
  static String get administrators => get('Administrateurs', 'Administrators');
  static String get auditLog => get('Audit Log', 'Audit Log');
  static String get supportChat => get('Support Messagerie', 'Support Chat');
  static String get export => get('Exporter', 'Export');
  static String get stats => get('Statistiques', 'Statistics');
  static String get revenue => get('Revenus', 'Revenue');
  static String get overview => get("Vue d'ensemble", 'Overview');
  static String get quickActions => get('Actions rapides', 'Quick actions');
  static String get management => get('Gestion', 'Management');
  static String get completeList => get('Liste complète', 'Complete list');
  static String get noOrder => get('Aucune commande', 'No order');
  static String get noUser => get('Aucun utilisateur', 'No user');
  static String get csv => get('CSV', 'CSV');
  static String get addAdmin => get('Ajouter un admin', 'Add admin');
  static String get addUserLabel => get('Ajouter un utilisateur', 'Add user');
  static String get userCreatedSuccess => get('Utilisateur créé avec succès', 'User created successfully');
  static String get exportData => get('Exporter les données', 'Export data');
  static String get exportSuccess => get('Export réussi', 'Export successful');
  static String get exportErrorLabel => get('Erreur export', 'Export error');
  static String get noResults => get('Aucun résultat', 'No results');
  static String get rejectReason => get('Motif de rejet', 'Rejection reason');
  static String get rejectReasonHint => get('Raison du rejet…', 'Reason for rejection…');
  static String get pendingRestaurantsValidation => get('Restaurants en attente de validation', 'Restaurants pending validation');
  static String get searchHint => get('Rechercher un utilisateur ou un restaurant…', 'Search a user or restaurant…');
  static String get chatWithUsers => get('Discuter avec les utilisateurs', 'Chat with users');
  static String get auditTrail => get('Traçabilité des actions', 'Audit trail');
  static String get completeUserList => get('Liste complète des utilisateurs', 'Complete user list');
  static String get completeRestaurantList => get('Liste complète des restaurants', 'Complete restaurant list');
  static String get ordersHistory => get('Historique des commandes', 'Orders history');
  static String get completeReport => get('Rapport complet', 'Complete report');
  static String get usersRestaurantsOrders => get('Utilisateurs + restaurants + commandes', 'Users + restaurants + orders');

  // ── Profil ──
  static String get profile => get('Profil', 'Profile');
  static String get editProfile => get('Modifier le profil', 'Edit profile');
  static String get editProfileTitle => get('Modifier mon profil', 'Edit my profile');
  static String get profileUpdated => get('Profil mis à jour', 'Profile updated');
  static String get changePhoto => get('Changer la photo', 'Change photo');
  static String get gallery => get('Galerie', 'Gallery');
  static String get camera => get('Caméra', 'Camera');
  static String get changePassword => get('Changer le mot de passe', 'Change password');
  static String get currentPassword => get('Mot de passe actuel', 'Current password');
  static String get newPassword => get('Nouveau mot de passe', 'New password');
  static String get deleteAccount => get('Supprimer mon compte', 'Delete my account');
  static String get deleteAccountWarning => get(
      'Cette action est irréversible. Toutes vos données seront perdues.',
      'This action is irreversible. All your data will be lost.');
  static String get country => get('Pays', 'Country');
  static String get role => get('Rôle', 'Role');
  static String get darkMode => get('Mode sombre', 'Dark mode');
  static String get language => get('Langue', 'Language');
  static String get notifications => get('Notifications', 'Notifications');
  static String get security => get('Sécurité', 'Security');
  static String get appearance => get('Apparence', 'Appearance');

  // ── Messages ──
  static String get noInternet => get('Pas de connexion Internet', 'No internet connection');
  static String get loading => get('Chargement...', 'Loading...');
  static String get noData => get('Aucune donnée', 'No data');
  static String get emptyList => get('Liste vide', 'Empty list');
  static String get comingSoon => get('Bientôt disponible', 'Coming soon');
  static String get contactUs => get('Nous contacter', 'Contact us');
  static String get noRestaurantData => get('Aucune donnée de restaurant.', 'No restaurant data.');
  static String get chat => get('Chat', 'Chat');
  static String get messages => get('Messages', 'Messages');
  static String get noConversation => get('Aucune conversation', 'No conversation');
  static String get online => get('En ligne', 'Online');
  static String get yourMessage => get('Votre message...', 'Your message...');
  static String get demandReceived => get('Votre demande a bien été prise en compte.', 'Your request has been received.');
  static String get willBeContacted => get('Vous serez contacté si votre idée de restaurant est acceptée.', 'You will be contacted if your restaurant idea is accepted.');

  // ── Welcome ──
  static String get welcome => get('Bienvenue !', 'Welcome!');
  static String get welcomeSubtitle => get(
      'Votre compte a été créé avec succès.\nDécouvrez les meilleurs plats faits maison près de chez vous.',
      'Your account has been created.\nDiscover the best homemade dishes near you.');
  static String get discover => get('Découvrir', 'Discover');

  static String of(String key, [String? fallback]) {
    // Legacy support for AppLocalizations keys
    switch (key) {
      case 'settings': return settings;
      case 'editProfile': return editProfile;
      case 'save': return save;
      case 'cancel': return cancel;
      case 'delete': return delete;
      case 'validate': return validate;
      case 'firstName': return firstName;
      case 'lastName': return lastName;
      case 'email': return email;
      case 'phone': return phone;
      case 'logout': return logout;
      case 'changePassword': return changePassword;
      case 'darkMode': return darkMode;
      case 'language': return language;
      case 'deleteAccount': return deleteAccount;
      // Signup keys
      case 'signup_title': return get('Inscription', 'Sign Up');
      case 'signup_subtitle': return get('Créez votre compte', 'Create your account');
      case 'already_have_account': return get('Déjà un compte ?', 'Already have an account?');
      case 'login': return get('Connectez-vous', 'Log in');
      case 'firstname': return get('Prénom', 'First name');
      case 'enter_firstname': return get('Entrez votre prénom', 'Enter your first name');
      case 'min_4_chars': return get('Minimum 4 caractères', 'Min 4 characters');
      case 'lastname': return get('Nom', 'Last name');
      case 'enter_lastname': return get('Entrez votre nom', 'Enter your last name');
      case 'username': return get("Nom d'utilisateur", 'Username');
      case 'enter_username': return get("Entrez votre nom d'utilisateur", 'Enter your username');
      case 'enter_valid_email': return get('Entrez un email valide', 'Enter a valid email');
      case 'phone_number': return get('Numéro de téléphone', 'Phone number');
      case 'enter_phone': return get('Entrez votre numéro', 'Enter your phone number');
      case 'benin_phone_format': return get('Format : 8 chiffres', 'Format: 8 digits');
      case 'phone_length': return fallback ?? get('Numéro invalide', 'Invalid number');
      case 'password': return get('Mot de passe', 'Password');
      case 'new_password': return get('Nouveau mot de passe', 'New password');
      case 'confirm_password': return get('Confirmer le mot de passe', 'Confirm password');
      case 'confirm_password_required': return get('Confirmation requise', 'Confirmation required');
      case 'passwords_do_not_match': return get('Les mots de passe ne correspondent pas', 'Passwords do not match');
      case 'terms_acceptance': return get('J\'accepte les conditions d\'utilisation', 'I accept the terms of use');
      case 'signup': return get('S\'inscrire', 'Sign Up');
      case 'login_title': return get('Connexion', 'Login');
      case 'login_subtitle': return get('Connectez-vous à votre compte', 'Log in to your account');
      case 'login_failed': return get('Identifiants incorrects', 'Invalid credentials');
      case 'connect_error': return connectError;
      // Additional keys from features branch
      case 'dont_have_account': return get("Pas de compte ? S'inscrire", "Don't have an account? Sign up");
      case 'splash_subtitle': return get('Des plats faits maison, livrés chez vous', 'Homemade dishes, delivered to you');
      case 'splash_loading': return get('Chargement...', 'Loading...');
      case 'skip': return get('Passer', 'Skip');
      case 'next': return get('Suivant', 'Next');
      case 'reset_password': return get('Réinitialiser le mot de passe', 'Reset password');
      case 'reset_password_title': return get('Mot de passe oublié', 'Forgot password');
      case 'reset_password_subtitle': return get('Entrez votre email pour réinitialiser', 'Enter your email to reset');
      case 'forgotten_password': return get('Mot de passe oublié', 'Forgot password');
      case 'forgotten_password_title': return get('Mot de passe oublié', 'Forgot password');
      case 'forgotten_password_subtitle': return get('Entrez votre email pour recevoir un code', 'Enter your email to receive a code');
      case 'enter_password': return get('Entrez votre mot de passe', 'Enter your password');
      case 'max_13_chars': return get('Maximum 13 caractères', 'Max 13 characters');
      case 'min_6_chars': return get('Minimum 6 caractères', 'Min 6 characters');
      case 'form_invalid': return get('Formulaire invalide', 'Invalid form');
      case 'internet_required': return get('Connexion Internet requise', 'Internet connection required');
      case 'invalid_or_expired_code': return get('Code invalide ou expiré', 'Invalid or expired code');
      case 'no_account_for_email': return get('Aucun compte pour cet email', 'No account for this email');
      case 'reset_code_send_failed': return get('Échec envoi du code', 'Failed to send code');
      case 'reset_code_sent': return get('Code envoyé !', 'Code sent!');
      case 'username_or_email': return get("Nom d'utilisateur ou email", 'Username or email');
      case 'user_not_found': return get('Utilisateur non trouvé', 'User not found');
      case 'verification_code_hint': return get('Entrez le code à 6 chiffres', 'Enter the 6-digit code');
      case 'verify_code': return get('Vérifier le code', 'Verify code');
      case 'verify_email': return get('Envoyer le code', 'Send code');
      case 'verification_code': return get('Code de vérification', 'Verification code');
      case 'same_password_error': return get('Le nouveau mot de passe est identique à l\'actuel', 'New password is same as current');
      // Onboarding steps
      case 'onboarding_step_1_title': return get('Découvrez les saveurs maison près de vous', 'Homemade dishes');
      case 'onboarding_step_1_body': return get('Découvrez les meilleurs plats faits maison près de chez vous, préparés avec passion.', 'Discover the best homemade dishes near you, made with passion.');
      case 'onboarding_step_2_title': return get('Commandez simplement, où que vous soyez', 'Fast delivery');
      case 'onboarding_step_2_body': return get('Parcourez les menus, suivez votre panier et retrouvez rapidement vos plats favoris.', 'Order in a few clicks and get fast delivery wherever you are.');
      case 'onboarding_step_3_title': return get('Vendez vos plats en toute confiance', 'Become a home chef');
      case 'onboarding_step_3_body': return get('Créez votre espace restaurant, publiez vos plats et gérez les commandes depuis l\'app.', 'Share your culinary talents and sell your homemade dishes on Dios Délices.');
      default: return fallback ?? key;
    }
  }
}
