import re

path = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\admin\admin_dashboard.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _loadStats
old_load = """      final fn = ParseCloudFunction('getDashboardStats');
      final response = await fn
          .execute(parameters: {if (target.isNotEmpty) 'country': target});
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {"""
new_load = """      final data = await NodeAdminService.getDashboardStats(country: target);
      if (data != null) {
        if (data['success'] == true && data['stats'] != null) {"""
content = content.replace(old_load, new_load)

# Add NodeAdminService import
if "import '../../services/node_admin_service.dart';" not in content:
    content = content.replace("import '../../services/session_service.dart';", "import '../../services/session_service.dart';\nimport '../../services/node_admin_service.dart';")

# Fix _validateRestaurant
old_val = """    final result = await Restaurant.updateRestaurantStatus(r.restaurantID, 1);"""
new_val = """    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken == null) {
      Toast(context, 'Erreur : Non connecté', false);
      return;
    }
    String result = 'success';
    try {
      await NodeAdminService.validateRestaurant(r.restaurantID, nodeToken);
    } catch (e) {
      result = e.toString();
    }"""
content = content.replace(old_val, new_val)

# Fix _rejectRestaurant
old_rej = """    final result = await Restaurant.updateRestaurantStatus(r.restaurantID, 2,
        remark: remark.trim());"""
new_rej = """    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken == null) {
      Toast(context, 'Erreur : Non connecté', false);
      return;
    }
    String result = 'success';
    try {
      await NodeAdminService.rejectRestaurant(r.restaurantID, remark.trim(), nodeToken);
    } catch (e) {
      result = e.toString();
    }"""
content = content.replace(old_rej, new_rej)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
