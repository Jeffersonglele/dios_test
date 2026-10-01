import re

path1 = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\users\user_identity_rejected.dart'
with open(path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

if "import '../../services/node_admin_service.dart';" not in content1:
    content1 = content1.replace("import '../../services/session_service.dart';", "import '../../services/session_service.dart';\nimport '../../services/node_admin_service.dart';")

old_send1 = """    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': 'blandinedupont087@gmail.com',
        'subject': 'Nouvelle identité en attente de vérification',
        'text': "Connectez-vous pour valider ou non l'utilisateur.",
      });
    } catch (e) {}"""

new_send1 = """    final token = await SessionService.readNodeToken();
    if (token == null) return;
    await NodeAdminService.sendEmail(
      to: 'blandinedupont087@gmail.com',
      subject: 'Nouvelle identité en attente de vérification',
      text: "Connectez-vous pour valider ou non l'utilisateur.",
      token: token,
    );"""

content1 = content1.replace(old_send1, new_send1)
with open(path1, 'w', encoding='utf-8') as f:
    f.write(content1)
print("user_identity_rejected.dart updated")

path2 = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\users\user_details.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

if "import '../../services/node_admin_service.dart';" not in content2:
    content2 = content2.replace("import '../../services/session_service.dart';", "import '../../services/session_service.dart';\nimport '../../services/node_admin_service.dart';")

old_delete = """                          final fn = ParseCloudFunction('forceDeleteUser');
                          final res = await fn
                              .execute(parameters: {'userID': widget.user_id});
                          if (!ctx.mounted) return;
                          if (res.success) {"""

new_delete = """                          final token = await SessionService.readNodeToken();
                          if (token != null) {
                            try {
                              await NodeAdminService.forceDeleteUser(widget.user_id, token);
                              if (!ctx.mounted) return;"""

content2 = content2.replace(old_delete, new_delete)

old_send2 = """    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText,
      });
      return true;
    } catch (e) {
      return false;
    }"""

new_send2 = """    final token = await SessionService.readNodeToken();
    if (token == null) return false;
    return await NodeAdminService.sendEmail(
      to: recipientEmail,
      subject: subject,
      text: messageText,
      token: token,
    );"""

content2 = content2.replace(old_send2, new_send2)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print("user_details.dart updated")
