import re

path = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\users\user_identity_rejected.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add NodeAdminService import
if "import '../../services/node_admin_service.dart';" not in content:
    content = content.replace("import '../../services/session_service.dart';", "import '../../services/session_service.dart';\nimport '../../services/node_admin_service.dart';")

old_send = """    final cloudFunction = ParseCloudFunction('sendEmail');
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

new_send = """    final token = await SessionService.readNodeToken();
    if (token == null) return false;
    return await NodeAdminService.sendEmail(
      to: recipientEmail,
      subject: subject,
      text: messageText,
      token: token,
    );"""

if old_send in content:
    content = content.replace(old_send, new_send)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("user_identity_rejected.dart updated")
else:
    print("Could not find old_send in user_identity_rejected.dart")
