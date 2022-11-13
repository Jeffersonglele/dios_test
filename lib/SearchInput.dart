import 'package:flutter/material.dart';

import 'Screen/CustomSearchDelegate.dart';

class SearchInput extends StatefulWidget {
  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 25, left: 25, right: 25),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  margin: EdgeInsets.only(right: 10),
                  padding: EdgeInsets.only(top: 15, right: 25, bottom: 15),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(15)),
                  child: Image.asset('assets/images/paragraph.png'),
                  width: 50),
              Flexible(
                flex: 1,
                child: TextField(
                  readOnly: true,
                  cursorColor: Colors.grey,
                  decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      hintText: 'Search for dishes, stores ...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                      prefixIcon: Container(
                        padding: EdgeInsets.all(15),
                        child: Image.asset('assets/images/search.png'),
                        width: 18,
                      )),
                  onTap: () {
                    //Go to the next screen
                    showSearch(
                        context: context,
                        // delegate to customize the search bar
                        delegate: CustomSearchDelegate());
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
