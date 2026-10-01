import re

path = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\admin\admin_dashboard.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the mess in _loadStats
old_bad = """      final data = await NodeAdminService.getDashboardStats(country: target);
      final response = await fn
          .execute(parameters: {if (target.isNotEmpty) 'country': target});
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {"""

new_good = """      final responseData = await NodeAdminService.getDashboardStats(country: target);
      if (responseData != null) {
        if (responseData['success'] == true && responseData['stats'] != null) {"""
content = content.replace(old_bad, new_good)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done2")
