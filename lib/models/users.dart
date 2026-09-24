import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gpassword/gpassword.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/navigation/curved_navigation_admin.dart';
import '../screens/navigation/curved_navigation_restau.dart';
import '../screens/navigation/curved_navigation_user.dart';
import '../screens/navigation/curved_navigation_livreur.dart';
import '../db/database_helper.dart';
import '../services/session_service.dart';

part 'users.g.dart';

@HiveType(typeId: 0)
class Users extends HiveObject {
  /// Dernière erreur d'authentification serveur, utilisée uniquement pour
  /// afficher un diagnostic utile à l'écran de connexion.
  static String? lastLoginError;

  @HiveField(0)
  final int userID;

  @HiveField(1)
  final String firstname;

  @HiveField(2)
  final String lastname;

  @HiveField(3)
  final String username;

  @HiveField(4)
  int roleID;

  @HiveField(5)
  String password;

  @HiveField(6)
  DateTime? last_login;

  @HiveField(7)
  final String image;

  @HiveField(8)
  final String email;

  @HiveField(9)
  final String telephone;

  @HiveField(10)
  String country;

  bool mustChangePassword;
  String? birthDate;
  bool consentRGPD;
  String? consentDate;

  String? permisType;
  bool permisVerified;
  bool isOnline;
  double? maxDeliveryDistance;

  @HiveField(11)
  String status;

  @HiveField(12)
  String identity;

  String? identityStatus;

  @HiveField(13)
  int addressID;

  @HiveField(14)
  int cityID;

  bool ageConfirmed;

  String? parrain;

  Users({
    required this.userID,
    required this.roleID,
    required this.email,
    required this.firstname,
    required this.lastname,
    required this.username,
    required this.password,
    this.last_login,
    required this.image,
    required this.telephone,
    required this.country,
    required this.status,
    required this.identity,
    this.identityStatus,
    required this.addressID,
    this.cityID = 1,
    this.mustChangePassword = false,
    this.ageConfirmed = false,
    this.birthDate,
    this.consentRGPD = false,
    this.consentDate,
    this.permisType,
    this.permisVerified = false,
    this.isOnline = false,
    this.maxDeliveryDistance,
    this.parrain,
  });

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'roleID': roleID,
      'email': email,
      'firstname': firstname,
      'lastname': lastname,
      'username': username,
      'password': password,
      'last_login': last_login?.toIso8601String(),
      'image': image,
      'country': country,
      'telephone': telephone,
      'status': status,
      'identity': identity,
      'identityStatus': identityStatus,
      'addressID': addressID,
      'cityID': cityID,
      'ageConfirmed': ageConfirmed,
      'mustChangePassword': mustChangePassword,
      'birthDate': birthDate,
      'consentRGPD': consentRGPD,
      'consentDate': consentDate,
      'permisType': permisType,
      'permisVerified': permisVerified,
      'isOnline': isOnline,
      'maxDeliveryDistance': maxDeliveryDistance ?? 10,
      'parrain': parrain,
    };
  }

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      roleID: int.tryParse(map['roleID']?.toString() ?? '0') ?? 0,
      telephone: map['telephone'].toString().trim(),
      email: map['email']?.toString() ?? '',
      firstname: map['firstname']?.toString() ?? '',
      lastname: map['lastname']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      identity: map['identity']?.toString() ?? '',
      identityStatus: map['identityStatus']?.toString(),
      addressID: int.tryParse(map['addressID']?.toString() ?? '0') ?? 0,
      cityID: int.tryParse(map['cityID']?.toString() ?? '1') ?? 1,
      ageConfirmed: map['ageConfirmed'] == true || map['ageConfirmed']?.toString() == 'true',
      last_login: map['last_login'] != null
          ? (map['last_login'] is String
              ? DateTime.tryParse(map['last_login'])
              : (map['last_login']['iso'] != null
                  ? DateTime.tryParse(map['last_login']['iso'])
                  : null))
          : null,
      image: map['image']?.toString() ?? '',
      mustChangePassword: map['mustChangePassword'] == true ||
          map['mustChangePassword']?.toString() == 'true',
      birthDate: map['birthDate']?.toString(),
      consentRGPD: map['consentRGPD'] == true ||
          map['consentRGPD']?.toString() == 'true',
      consentDate: map['consentDate']?.toString(),
      permisType: map['permisType']?.toString(),
      permisVerified: map['permisVerified'] == true ||
          map['permisVerified']?.toString() == 'true',
      isOnline:
          map['isOnline'] == true || map['isOnline']?.toString() == 'true',
      maxDeliveryDistance: map['maxDeliveryDistance'] != null
          ? (map['maxDeliveryDistance'] as num).toDouble()
          : null,
      parrain: map['parrain']?.toString(),
    );
  }

  Users copy({
    int? userID,
    int? roleID,
    String? telephone,
    String? password,
    String? email,
    String? firstname,
    String? lastname,
    String? username,
    DateTime? last_login,
    String? image,
    String? country,
    String? status,
    String? identity,
    String? identityStatus,
    int? addressID,
    int? cityID,
    bool? ageConfirmed,
    String? birthDate,
    bool? consentRGPD,
    String? consentDate,
    String? permisType,
    bool? permisVerified,
    bool? isOnline,
    double? maxDeliveryDistance,
  }) {
    return Users(
      userID: userID ?? this.userID,
      roleID: roleID ?? this.roleID,
      telephone: telephone ?? this.telephone,
      password: password ?? this.password,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      username: username ?? this.username,
      email: email ?? this.email,
      last_login: last_login ?? this.last_login,
      image: image ?? this.image,
      country: country ?? this.country,
      status: status ?? this.status,
      identity: identity ?? this.identity,
      identityStatus: identityStatus ?? this.identityStatus,
      addressID: addressID ?? this.addressID,
      cityID: cityID ?? this.cityID,
      ageConfirmed: ageConfirmed ?? this.ageConfirmed,
      birthDate: birthDate ?? this.birthDate,
      consentRGPD: consentRGPD ?? this.consentRGPD,
      consentDate: consentDate ?? this.consentDate,
      permisType: permisType ?? this.permisType,
      permisVerified: permisVerified ?? this.permisVerified,
      isOnline: isOnline ?? this.isOnline,
      maxDeliveryDistance: maxDeliveryDistance ?? this.maxDeliveryDistance,
    );
  }

  static Future<dynamic> manageUser({
    int? userID,
    required int roleID,
    required String telephone,
    required String password,
    required String password_crypte,
    required String firstname,
    required String lastname,
    required String email,
    required String username,
    required String status,
    required String identity,
    required int addressID,
    int cityID = 1,
    String country = "",
    DateTime? last_login,
    ParseFileBase? image,
    String? birthDate,
    bool consentRGPD = false,
    String? consentDate,
    String? permisType,
    String? identityStatus,
    bool ageConfirmed = false,
  }) async {
    String functionName = userID == null ? 'add1User' : 'updateUser';
    var cloudFunction = ParseCloudFunction(functionName);

    String imageUrl = "";

    if (image != null) {
      final response = await image.save();
      if (response.success && response.result != null) {
        imageUrl = (response.result as ParseFileBase).url ?? "";
      } else {
        return "Erreur lors de l'upload de l'image: ${response.error?.message}";
      }
    }

    final params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'roleID': roleID,
      'firstname': firstname,
      'lastname': lastname,
      'username': username,
      'email': email,
      'country': country,
      'password': password,
      'telephone': telephone.toString(),
      'password_crypte': password_crypte,
      'image': imageUrl,
      'status': status,
      'identity': identity,
      'addressID': addressID,
      'cityID': cityID,
      'ageConfirmed': ageConfirmed,
      'birthDate': birthDate,
      'consentRGPD': consentRGPD,
      'consentDate': consentDate,
      'permisType': permisType,
      if (identityStatus != null) 'identityStatus': identityStatus,
    };
    if (last_login != null) {
      params['last_login'] = {
        "__type": "Date",
        "iso": last_login.toIso8601String()
      };
    }

    final ParseResponse parseResponse =
        await cloudFunction.execute(parameters: params);

    if (parseResponse.success && parseResponse.result != null) {
      var response = parseResponse.result as Map<String, dynamic>;
      if (response['success'] == false) {
        return "Erreur : ${response['error']}";
      } else {
        notifyDataChanged();
        return response['userID']; // Retourne l'ID de l'utilisateur créé
      }
    } else {
      return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
    }
  }

  static Future<String> updateStatus(int userID, String status) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    // Construire les paramètres, y compris userID pour la mise à jour
    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'status': status
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserStatus(userID, status);

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateIdentity(int userID, String identity) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    // Construire les paramètres, y compris userID pour la mise à jour
    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'identity': identity
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserIdentity(userID, identity);

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateDerniereConnexion(int userID) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    DateTime last_login = DateTime.now();

    // Construire les paramètres, y compris userID pour la mise à jour
    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'last_login': {"__type": "Date", "iso": last_login.toIso8601String()}
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUser(userID, last_login);

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updatePassword(int userID, String newPassword,
      {bool? mustChangePassword, String? plainPassword}) async {
    final hasNativeSession = plainPassword != null &&
        await SessionService.hasParseSession();
    String functionName = hasNativeSession ? 'changePassword' : 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    var params = <String, dynamic>{
      if (!hasNativeSession) 'userID': userID,
      if (hasNativeSession) 'newPassword': plainPassword,
      if (hasNativeSession) 'passwordHash': newPassword,
      if (!hasNativeSession) 'password': newPassword,
      if (mustChangePassword != null && !hasNativeSession)
        'mustChangePassword': mustChangePassword,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserPassword(
            userID,
            newPassword,
            mustChangePassword: mustChangePassword,
          );

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateProfile(
    int userID, {
    required String firstname,
    required String lastname,
    required String email,
    required String telephone,
    String? image,
  }) async {
    var cloudFunction = ParseCloudFunction('update1User');
    var params = <String, dynamic>{
      'userID': userID,
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'telephone': telephone,
      if (image != null) 'image': image,
    };
    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);
      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserProfile(
              userID, firstname, lastname, email, telephone,
              image: image);
          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateCountryAndRole(
      int userID, String country, int roleID) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    // Construire les paramètres, y compris userID pour la mise à jour
    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'country': country,
      'roleID': roleID
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateCountryAndRole(userID, country, roleID);

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> suppr1User(int userID) async {
    var cloudFunction = ParseCloudFunction('softDelete1User');
    var params = <String, dynamic>{
      'userID': userID,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == true) {
          try {
            await DatabaseHelper.updateUserStatus(userID, 'deleted_pending');
          } catch (_) {}
          notifyDataChanged();
          return "success";
        } else {
          return "Erreur : ${response['error']}";
        }
      } else {
        return "Erreur : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<String> permanentlyDeleteUser(int userID) async {
    var cloudFunction = ParseCloudFunction('suppr1User');
    var params = <String, dynamic>{
      'userID': userID,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == true) {
          await DatabaseHelper.deleteUser(userID);
          notifyDataChanged();
          return "success";
        } else {
          return "Erreur : ${response['error']}";
        }
      } else {
        return "Erreur : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> getAllUsersDetails({int? adminUserID}) async {
    final params = adminUserID != null ? {'userID': adminUserID} : null;
    var cloudFunction = ParseCloudFunction('getAllUsers');

    try {
      var response = await cloudFunction.execute(parameters: params);

      if (response.success) {
        List<dynamic> usersDataList = response.result;
        for (var usersData in usersDataList) {
          Users user = Users.fromMap(usersData);
          final cached = await DatabaseHelper.getUser(user.userID);
          if (user.password.isEmpty && cached != null) {
            user.password = cached.password;
          }
          await DatabaseHelper.createUser(user);
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  static Future<Users?> loginUser(String login, String password) async {
    lastLoginError = null;
    try {
      final cloudFunction = ParseCloudFunction('loginUser');
      final passwordHash = await encryptPassword(password);
      final response = await cloudFunction.execute(parameters: {
        'login': login.trim(),
        'password': password,
        'passwordHash': passwordHash,
      });

      if (!response.success) {
        lastLoginError = response.error?.message;
        return null;
      }

      if (response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == true && result['user'] != null) {
          final user = Users.fromMap(result['user']);
          final sessionToken = result['sessionToken']?.toString();
          var sessionReady = false;

          // Nouveau Cloud Code : la session Parse est déjà créée côté serveur.
          if (sessionToken != null && sessionToken.isNotEmpty) {
            sessionReady = await SessionService.adoptParseSession(sessionToken);
          }

          // Ancien Cloud Code / données Parse existantes : le profil métier
          // est validé par `Users`, puis le SDK ouvre la session `_User`.
          if (!sessionReady) {
            sessionReady = await SessionService.loginParseUser(
              user.username,
              password,
            );
          }

          if (!sessionReady) {
            lastLoginError = 'Session Parse impossible à ouvrir.';
            return null;
          }

          // Ne pas remplacer un hash local déjà présent par une réponse
          // serveur qui, volontairement, ne contient plus de mot de passe.
          final cached = await DatabaseHelper.getUser(user.userID);
          if (user.password.isEmpty && cached != null) {
            user.password = cached.password;
          }
          return user;
        }
        lastLoginError = result['error']?.toString() ??
            'Identifiant ou mot de passe incorrect.';
      } else {
        lastLoginError = 'Réponse vide du serveur.';
      }
      return null;
    } catch (e) {
      lastLoginError = e.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  static Future<List<Users>> fetchUsersFromDB() async {
    List<Users> usersList = await DatabaseHelper.readAllUserss();
    return usersList;
  }

  static Future<String> generatePassword() async {
    GPassword gPassword = GPassword();
    return gPassword.generate(passwordLength: 8);
  }

  static Future<String> encryptPassword(String password) async {
    GPassword gPassword = GPassword();
    return gPassword.encryptPassword(password: password);
  }

  static Future<Users?> verifUser(
      List<Users> listUsers, String usernameOrEmail, String password) async {
    String passwordCrypte = await encryptPassword(password);
    final normalizedLogin = usernameOrEmail.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final normalizedPasswordCrypte = passwordCrypte.trim();

    for (final user in listUsers) {
      final storedPassword = user.password.trim();
      final loginMatches =
          user.username.trim().toLowerCase() == normalizedLogin ||
              user.email.trim().toLowerCase() == normalizedLogin;
      final passwordMatches = storedPassword == normalizedPasswordCrypte ||
          storedPassword == normalizedPassword;

      if (loginMatches && passwordMatches) {
        return user;
      }
    }

    return null;
  }

  static Users? getUsersByUserId(List<Users> users, int id) {
    try {
      return users.firstWhere((user) => user.userID == id);
    } catch (e) {
      return null;
    }
  }

  static Users? getUsersByUsername(List<Users> listUsers, String username) {
    try {
      return listUsers.firstWhere((users) => users.username == username);
    } catch (e) {
      return null;
    }
  }

  static Users? getUsersByEmail(List<Users> listUsers, String email) {
    try {
      return listUsers.firstWhere((users) => users.email == email);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkEmailExists(
      List<Users> listUsers, String email) async {
    try {
      listUsers.firstWhere((users) => users.email == email);
      return true;
    } catch (e) {
      return false;
    }
  }

  static void chooseCurvedNavigation(
      int userRole, String country, BuildContext context) {
    final Widget destination;
    if (userRole == 1 || userRole == 4) {
      destination = CurvedNavigationAdmin(specified_index: 0);
    } else if (userRole == 3) {
      destination = CurvedNavigationRestau(specified_index: 0);
    } else if (userRole == 2) {
      destination = CurvedNavigationUser(specified_index: 0, country: country);
    } else if (userRole == 5) {
      destination = const CurvedNavigationLivreur();
    } else {
      destination = CurvedNavigationUser(specified_index: 0, country: country);
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }
}
