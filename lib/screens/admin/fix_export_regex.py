import re

path = r'c:\Users\miche\OneDrive\Bureau\dios\dios_delices\lib\screens\admin\admin_dashboard.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure we have the pdf package imports
if "import 'package:pdf/pdf.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:pdf/pdf.dart';\nimport 'package:pdf/widgets.dart' as pw;")

new_export = """  Future<void> _doExport(String type) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Format d\\'export', style: AppTypography.titleMedium()),
        content: Text('Voulez-vous exporter au format CSV ou PDF ?', style: AppTypography.bodyRegular()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'csv'), child: Text('CSV')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'pdf'), child: Text('PDF')),
        ],
      ),
    );
    if (format == null) return;

    try {
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      String filename = '${type}_$ts.$format';
      List<String> headers = [];
      List<List<String>> dataRows = [];

      if (type == 'users') {
        headers = ['ID', 'Nom', 'Prénom', 'Email', 'Rôle', 'Pays', 'Téléphone'];
        dataRows = _allUsers.map((u) => [
          u.userID.toString(), _e(u.lastname), _e(u.firstname), _e(u.email),
          _role(u.roleID), _e(u.country), _e(u.telephone),
        ]).toList();
      } else if (type == 'restaurants') {
        headers = ['ID', 'Nom', 'Propriétaire', 'Catégories', 'Validé'];
        dataRows = _allRestaurants.map((r) {
          final o = Users.getUsersByUserId(_allUsers, r.userID);
          return [
            r.restaurantID.toString(), _e(r.name),
            _e(o != null ? '${o.firstname} ${o.lastname}' : '#${r.userID}'),
            _e(r.categories),
            r.valid == 1 ? 'Oui' : r.valid == 2 ? 'Rejeté' : 'Attente',
          ];
        }).toList();
      } else if (type == 'orders') {
        final cmds = await Commande.fetchCommandesFromDB();
        headers = ['ID', 'Client', 'Status', 'Livraison', 'Réduction', 'Date'];
        dataRows = cmds.map((c) {
          final u = Users.getUsersByUserId(_allUsers, c.userID);
          return [
            c.commandeID.toString(),
            _e(u != null ? '${u.firstname} ${u.lastname}' : '#${c.userID}'),
            _e(c.status), c.fraisLivraison.toStringAsFixed(2),
            c.reduction.toStringAsFixed(2), c.dateCommande.toIso8601String().split('T')[0],
          ];
        }).toList();
      } else {
        headers = ['Métrique', 'Valeur'];
        dataRows = [
          ['Utilisateurs totaux', _allUsers.length.toString()],
          ['Restaurants totaux', _allRestaurants.length.toString()],
          ['Commandes totales', _statsData?['totalOrders']?.toString() ?? '0'],
          ['Revenu estimé', '${_statsData?['totalRevenue']?.toString() ?? '0'} ${_userCountry == 'Bénin' ? 'FCFA' : 'CDF'}'],
          ['Nouveaux utilisateurs (mois)', _statsData?['newUsersThisMonth']?.toString() ?? '0'],
        ];
      }

      List<int> fileBytes;
      if (format == 'pdf') {
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              pw.Header(level: 0, child: pw.Text('Export $type - $_userCountry')),
              pw.Paragraph(text: 'Généré le: ${DateTime.now()}'),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: dataRows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
            ],
          ),
        );
        fileBytes = await pdf.save();
      } else {
        String csv = _csv(headers, dataRows);
        fileBytes = const Utf8Codec().encode(csv);
      }

      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le fichier $format',
          fileName: filename,
          bytes: fileBytes,
          type: FileType.custom,
          allowedExtensions: [format],
        );
      } catch (_) {
        savedPath = null;
      }

      if (savedPath != null && savedPath.isNotEmpty) {
        if (!mounted) return;
        Toast(context, 'Fichier $format enregistré avec succès !', true);
      }
    } catch (e) {
      if (!mounted) return;
      Toast(context, 'Erreur lors de l\\'export : $e', false);
    }
  }"""

pattern = re.compile(r'  Future<void> _doExport\(String type\) async \{.*?\n  \}', re.DOTALL)
if pattern.search(content):
    content = pattern.sub(new_export, content)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Export replaced using regex")
else:
    print("Could not match regex")
