import 'package:dios_delices/Constant/Constant.dart';
import 'package:dios_delices/SearchInput.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: Column(
          children: <Widget>[
            new SearchInput(),
            SizedBox(
              height: size.height * 0.02,
            ),
            StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  DateTime now = new DateTime.now();
                  String hour = now.hour.toString() +
                      ":" +
                      now.minute.toString() +
                      ":" +
                      now.second.toString();
                  String parsed_hour = DateFormat.jm()
                      .format(DateFormat("hh:mm:ss").parse(hour));

                  return Row(
                    children: [
                      SizedBox(width: 25),
                      Icon(Icons.today),
                      Text(
                        "  " +
                            now.day.toString() +
                            " " +
                            _getMonthName(now.month) +
                            " " +
                            now.year.toString() +
                            ", " +
                            parsed_hour,
                      ),
                    ],
                  );
                }),
            SizedBox(
              height: size.height * 0.03,
            ),
            Row(
              children: [
                SizedBox(width: 25),
                Text(
                  'Popular meals',
                  style: bigTitleStyle(size),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _getMonthName(currentMonth) {
    List<String> month_names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    return month_names.elementAt(currentMonth - 1);
  }
}
