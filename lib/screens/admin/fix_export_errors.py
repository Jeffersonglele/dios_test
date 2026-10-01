import re

path = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\admin\admin_dashboard.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix bodyRegular
content = content.replace("AppTypography.bodyRegular()", "AppTypography.bodyMedium()")

# Fix stats variables
content = content.replace("_statsData?['totalOrders']?.toString() ?? '0'", "_totalOrders.toString()")
content = content.replace("_${_statsData?['totalRevenue']?.toString() ?? '0'}", "$_totalRevenue")
content = content.replace("(_statsData?['totalRevenue']?.toString() ?? '0')", "_totalRevenue.toStringAsFixed(2)")
content = content.replace("${_statsData?['totalRevenue']?.toString() ?? '0'}", "${_totalRevenue.toStringAsFixed(2)}")
content = content.replace("_statsData?['newUsersThisMonth']?.toString() ?? '0'", "_newUsersMonth.toString()")

# Fix Uint8List
content = content.replace("bytes: fileBytes,", "bytes: Uint8List.fromList(fileBytes),")

# Add typed_data import
if "import 'dart:typed_data';" not in content:
    content = content.replace("import 'dart:convert';", "import 'dart:convert';\nimport 'dart:typed_data';")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("fixes applied")
