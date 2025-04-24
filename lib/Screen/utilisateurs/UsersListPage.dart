import 'package:dios_delices/Screen/utilisateurs/UserDetails.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../../modeles/users.dart';
import '../../modeles/identity.dart';

class UsersListPage extends StatefulWidget {
  final String country;

  UsersListPage({required this.country});

  @override
  _UsersListPageState createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  List<Map<String, dynamic>> filteredUsers = [];
  List<Identity> identities = [];
  List<Users> users = [];
  bool isLoading = true;
  bool showOnlyWaitingForValidation = false;
  String sortBy = 'Nom';

  Future<bool> _sendEmailToUser(Users user, bool valid, [String? remark]) async {
    String username = 'blandinedupont087@gmail.com';
    String password = 'dtmd pleh ufau vjqd';

    final smtpServer = gmail(username, password);

    String subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre profil est validé !'
        : '❌ Mise à jour : Validation de votre profil sur Dios Délices';

    String messageText = valid
        ? 'Bonjour ${user?.firstname},\n\n'
        'Nous sommes ravis de vous informer que votre profil a été validé. '
        'Vous pouvez maintenant accéder à votre compte pour gérer votre profil et recevoir des commandes.\n\n'
        'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user?.firstname},\n\n'
        'Nous regrettons de vous informer que votre profil n’a pas été validé suite à notre processus de vérification.\n\n'
        'Raison du rejet : ${remark ?? "Non spécifiée"}\n\n' // Ajouter la remarque ici
        'Pour plus d’informations, n’hésitez pas à nous contacter.\n\n'
        'Cordialement,\nL’équipe Dios Délices';

    final message = Message()
      ..from = Address(username, 'Dios Délices')
      ..recipients.add(user?.email ?? 'adigbononrodicaa@gmail.com') // Ajouter l'email du propriétaire
      ..subject = subject
      ..text = messageText;

    try {
      await send(message, smtpServer);
      print('Email envoyé avec succès');
      return true;
    } on MailerException catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
      return false;
    }
  }


  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    List<Identity> identityList = await Identity.fetchIdentitiesFromDB();
    print("identityList " + identityList.toString());
    List<Users> usersList = await Users.fetchUsersFromDB();
    print("usersList " + usersList.toString());

    setState(() {
      identities = identityList;
      users = usersList;
      _fetchUsersByCountry();
    });
  }

  Future<void> _fetchUsersByCountry() async {
    for (var user in users) {
      Identity? identity = await Identity.getIdentityByUserId(identities, user.userID);
      if (identity != null && user.country == widget.country) {
        setState(() {
          filteredUsers.add({"user": user, "identity": identity});
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void _sortUsers(String criterion) {
    setState(() {
      sortBy = criterion;
      if (criterion == 'Nom') {
        filteredUsers.sort(
                (a, b) => b["users"].name.compareTo(a["users"].name));
      } else if (criterion == 'Username') {
        filteredUsers.sort(
                (a, b) => b["users"].username.compareTo(a["users"].username));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String appBar = widget.country == "Bénin" ? " Users au " : "Users en ";

    return Scaffold(
      appBar: AppBar(
        title: Text(appBar + widget.country),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('En attente de validation'),
                    Switch(
                      value: showOnlyWaitingForValidation,
                      onChanged: (value) {
                        setState(() {
                          showOnlyWaitingForValidation = value;
                        });
                      },
                    ),
                  ],
                ),
                Flexible( // Utiliser Flexible pour s'adapter à la largeur de l'écran
                  child: PopupMenuButton<String>(
                    onSelected: _sortUsers,
                    itemBuilder: (BuildContext context) {
                      return {'Nom', 'Username'}
                          .map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, color: Colors.black),
                          SizedBox(width: 5),
                          Flexible( // Flexible ici pour le texte qui pourrait déborder
                            child: Text(
                              "Trier par ",
                              style: TextStyle(color: Colors.black),
                              overflow: TextOverflow.ellipsis, // Tronque le texte si nécessaire
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredUsers.isEmpty
              ? Center(
              child: Text(
                  'Aucun utilisateur trouvé pour ${widget.country}'))
              : Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                Users user = filteredUsers[index]["user"];
                Identity identity = filteredUsers[index]["identity"];

                if (showOnlyWaitingForValidation && user.identity == "Verified") {
                  return SizedBox();
                }

                return _buildUserCard(user, identity);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Users user, Identity identity) {
    return Card(
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
                child: Image.network(
                  identity.photo ?? "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
              title: Text(
                user.firstname + " " + user.lastname,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis, // Empêche le débordement du nom
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                ],
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () => {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => UserDetails(user_id: user.userID)
                    )
                )
              },
            ),

            if (user.identity != "Verified")
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Email: ${user.email}"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.punch_clock, color: Colors.red), onPressed: () {  },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

}
