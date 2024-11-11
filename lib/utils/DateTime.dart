import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Récupère l'heure actuelle en UTC
        DateTime nowUtc = DateTime.now().toUtc();

        // Ajuste l'heure en fonction du fuseau horaire (exemple France UTC+1 en hiver)
        DateTime now;
        String? locale = Localizations.localeOf(context).countryCode;

        // France (UTC+1 ou UTC+2 en été)
        if (locale == "FR") {
          now = nowUtc.add(Duration(hours: 1)); // UTC+1
        }
        // Bénin et Côte d'Ivoire (UTC tout au long de l'année)
        else if (locale == "BJ" || locale == "CI") {
          now = nowUtc;
        }
        // Autres pays par défaut (heure locale de l'appareil)
        else {
          now = DateTime.now().toLocal();
        }

        // Format de l'heure et de la date en français
        String parsedHour = DateFormat('HH:mm', 'fr').format(now);
        String formattedDate = DateFormat('d MMMM y', 'fr').format(now);

        return Row(
          children: [
            SizedBox(width: 25),
            Icon(Icons.today),
            Text(
              "  $formattedDate, $parsedHour",
              style: TextStyle(fontSize: 16),
            ),
          ],
        );
      },
    );
  }
}
