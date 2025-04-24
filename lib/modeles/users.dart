import 'package:dios_delices/Screen/curved_navigation/CurvedNavigationUserAfr.dart';
import 'package:flutter/cupertino.dart';
import 'package:gpassword/gpassword.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screen/curved_navigation/CurvedNavigationAdmin.dart';
import '../Screen/curved_navigation/CurvedNavigationRestau.dart';
import '../Screen/curved_navigation/CurvedNavigationUserFrance.dart';
import '../db/database_helper.dart';

part 'users.g.dart';

@HiveType(typeId: 0)
class Users extends HiveObject {
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
  final int telephone;

  @HiveField(10)
  String country;

  @HiveField(11)
  String status;

  @HiveField(12)
  String identity;

  @HiveField(13)
  int addressID;

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
    required this.addressID,
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
      'addressID': addressID,
    };
  }

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      roleID: int.tryParse(map['roleID']?.toString() ?? '0') ?? 0,
      telephone: int.tryParse(map['telephone']?.toString() ?? '0') ?? 0,
      email: map['email']?.toString() ?? '',
      firstname: map['firstname']?.toString() ?? '',
      lastname: map['lastname']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      identity: map['identity']?.toString() ?? '',
      addressID: int.tryParse(map['addressID']?.toString() ?? '0') ?? 0,
      last_login: map['last_login'] != null && map['last_login']['iso'] != null
          ? DateTime.tryParse(map['last_login']['iso'])
          : null,
      image: map['image']?.toString() ?? '',
    );
  }

  Users copy({
    int? userID,
    int? roleID,
    int? telephone,
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
    int? addressID,
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
      addressID: addressID ?? this.addressID,
    );
  }

  static Future<dynamic> manageUser({
    int? userID,
    required int roleID,
    required int telephone,
    required String password,
    required String password_crypte,
    required String firstname,
    required String lastname,
    required String email,
    required String username,
    required String status,
    required String identity,
    required int addressID,
    DateTime? last_login,
    ParseFile? image,
  }) async {
    String functionName = userID == null ? 'add1User' : 'updateUser';
    var cloudFunction = ParseCloudFunction(functionName);

    String imageUrl = "";

    if (image != null) {
      final response = await image.save();
      if (response.success && response.result != null) {
        imageUrl = (response.result as ParseFile).url ?? "";
      } else {
        return "Erreur lors de l'upload de l'image: ${response.error?.message}";
      }
    }

    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'roleID': roleID,
      'firstname': firstname,
      'lastname': lastname,
      'username': username,
      'email': email,
      'country': "",
      'password': password,
      'telephone': telephone,
      'password_crypte': password_crypte,
      'last_login': {"__type": "Date", "iso": last_login?.toIso8601String()},
      'image': imageUrl,
      'status': status,
      'identity': identity,
      'addressID': addressID,
    };

    final ParseResponse parseResponse =
    await cloudFunction.execute(parameters: params);

    if (parseResponse.success && parseResponse.result != null) {
      var response = parseResponse.result as Map<String, dynamic>;
      if (response['success'] == false) {
        return "Erreur : ${response['error']}";
      } else {
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
      final ParseResponse parseResponse = await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserIdentity(userID, identity);

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
      'last_login': {"__type": "Date", "iso": last_login?.toIso8601String()}
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

          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updatePassword(int userID, String newPassword) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1User';
    var cloudFunction = ParseCloudFunction(functionName);

    // Construire les paramètres, y compris userID pour la mise à jour
    var params = <String, dynamic>{
      if (userID != null) 'userID': userID,
      'password': newPassword
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateUserPassword(userID, newPassword);

          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      print("Exception lors de l'appel de la fonction cloud : $e");
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

          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      print("Exception lors de l'appel de la fonction cloud : $e");
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> suppr1User(int userID) async {
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
          // User supprimé avec succès
          await DatabaseHelper.deleteUser(userID);

          return "success";
        } else {
          // Gestion de l'erreur si l'accès n'a pas pu être supprimé
          return "Erreur : ${response['error']}";
        }
      } else {
        // Gestion des erreurs de la réponse
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      // Gestion des exceptions
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<bool> getAllUsersDetails() async {
    // Créer une instance de ParseCloudFunction
    var cloudFunction = ParseCloudFunction('getAllUsers');

    // Appeler la fonction cloud et attendre la réponse
    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> usersDataList = response.result;
        for (var usersData in usersDataList) {
          Users user = Users.fromMap(usersData);
          await DatabaseHelper.createUser(user);
        }
      } else {
        print('Failed to retrieve users details: ${response.error?.message}');
        return false;
      }
    } catch (e) {
      print('Error calling cloud function: $e');
      return false;
    }
    return true;
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
    // Crypter le mot de passe avant de le comparer
    String passwordCrypte = await encryptPassword(password);

    print("passwordCrypte " + passwordCrypte);

    // Chercher l'accès correspondant au username ou email
    for (final user in listUsers) {
      if ((user.username.trim().toLowerCase() == usernameOrEmail.trim().toLowerCase() ||
          user.email.trim().toLowerCase() == usernameOrEmail.trim().toLowerCase()) &&
          user.password.trim() == passwordCrypte.trim()) {

        if (user != null) {
          return user; // Retourner l'utilisateur si trouvé
        }
      }
    }

    // Aucun utilisateur correspondant trouvé
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
      Users user = await listUsers.firstWhere((users) => users.email == email);
      if (user != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static void chooseCurvedNavigation(
      int userRole, String country, BuildContext context) {
    // TODO : revoir la page pour un super admin
    if (userRole == 1 || userRole == 4) {
      // Si l'utilisateur est un administrateur
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => CurvedNavigationAdmin(specified_index: 0),
        ),
      );
    } else if (userRole == 3) {
      // Si l'utilisateur est un restau
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => CurvedNavigationRestau(specified_index: 0),
        ),
      );
    } else if (userRole == 2) {
      // Si l'utilisateur est un utilisateur normal
      if (country == "France") {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) =>
                CurvedNavigationUserFrance(specified_index: 0),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => CurvedNavigationUserAfr(specified_index: 0),
          ),
        );
      }
    }
  }
}
