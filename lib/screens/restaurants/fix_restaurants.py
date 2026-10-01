path1 = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\restaurants\restaurant_list_page.dart'
with open(path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# Add imports
if "import '../../services/node_admin_service.dart';" not in content1:
    content1 = content1.replace(
        "import '../../utils/toast.dart';",
        "import '../../services/node_admin_service.dart';\nimport '../../services/session_service.dart';\nimport '../../utils/toast.dart';"
    )

old1 = """    final cloudFunction = ParseCloudFunction('sendEmail');
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

new1 = """    final token = await SessionService.readNodeToken();
    if (token == null) return false;
    return await NodeAdminService.sendEmail(
      to: recipientEmail,
      subject: subject,
      text: messageText,
      token: token,
    );"""

content1 = content1.replace(old1, new1)
with open(path1, 'w', encoding='utf-8') as f:
    f.write(content1)
print("restaurant_list_page.dart updated")

# ---

path2 = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\restaurants\restaurant_update_form_page.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

if "import '../../services/node_admin_service.dart';" not in content2:
    content2 = content2.replace(
        "import '../../utils/toast.dart';",
        "import '../../services/node_admin_service.dart';\nimport '../../services/session_service.dart';\nimport '../../utils/toast.dart';"
    )

old2 = """    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': 'blandinedupont087@gmail.com',
        'subject': 'Nouvelle demande de Restaurant',
        'text': 'Nom du restaurant: $name\\nAdresse: $address\\nTéléphone: $phone',
      });
    } catch (e) {
    }"""

new2 = """    final token = await SessionService.readNodeToken();
    if (token == null) return;
    await NodeAdminService.sendEmail(
      to: 'blandinedupont087@gmail.com',
      subject: 'Nouvelle demande de Restaurant',
      text: 'Nom du restaurant: $name\\nAdresse: $address\\nTéléphone: $phone',
      token: token,
    );"""

content2 = content2.replace(old2, new2)
with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print("restaurant_update_form_page.dart updated")
