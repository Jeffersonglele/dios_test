import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../modeles/dish.dart';
import '../services/favorites_service.dart';
import '../services/session_service.dart';

class DishDetails extends StatefulWidget {
  static const routeName = '/DishDetails';

  final int dish_id;
  final int from_page;

  DishDetails({required this.dish_id, required this.from_page});

  @override
  State<DishDetails> createState() => _DishDetailsState();
}

class _DishDetailsState extends State<DishDetails> {
  String? country = "";
  int currentUser_restau = 0;
  int currentUser_role = 0;
  bool isLoading = true;
  bool isFavorite = false;

  TextEditingController totalController = TextEditingController();

  List<Dish> dishes = [];
  Dish? current_dish;

  @override
  void dispose() {
    totalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    //readJson();
    //getCategories();
    loadData();
  }

  void loadData() async {
    final session = await SessionService.readSession();
    country = session.country;
    currentUser_restau = session.restaurantId ?? 0;
    currentUser_role = session.role.id;

    // Chargement des données Dish depuis la base de données
    List<Dish> dishesList = await Dish.fetchDishesFromDB();
    Dish? dish = Dish.getDishByDishId(dishesList, widget.dish_id);

    if (!mounted || dish == null) return;
    setState(() {
      dishes = dishesList;
      current_dish = dish;
      isLoading = false;
    });
    isFavorite = await FavoritesService.isDishFavorite(widget.dish_id);
    if (!mounted) return;
    setState(() {});
  }

  List _items_categories = [];
  List _items = [];
  var number_of_parts = 1;


  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    if (isLoading || current_dish == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(),
        body: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return _buildLargeScreen(size, theme);
              } else {
                return _buildSmallScreen(size, theme);
              }
            },
          ),
        ),
      ),
    );
  }

  // For large screens
  Widget _buildLargeScreen(
      Size size, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(size, theme),
        ),
      ],
    );
  }

  // For Small screens
  Widget _buildSmallScreen(
      Size size, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, theme),
    );
  }

  // Main Body
  Widget _buildMainBody(
      Size size, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        SizedBox(
          height: size.height * 0.06,
        ),
        Container(
          constraints: BoxConstraints.expand(height: 300.0, width: 400),
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
          margin: EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: (current_dish!.image != null && current_dish!.image!.isNotEmpty)
                  ? NetworkImage(current_dish!.image!)
                  : AssetImage('assets/images/no_image.png') as ImageProvider,
              // Cast explicite en ImageProvider
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: 0.0,
                top: 5,
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border_outlined,
                    ),
                    iconSize: 30,
                    color: isFavorite ? Colors.pink : Colors.black,
                    onPressed: _toggleFavorite,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(width: 25),
            Text(
              current_dish!.name ?? "",
              style: kLoginSubtitleStyle3(size),
            ),
            Spacer(),
            Text(
              current_dish!.price.toString() +
                  " " +
                  (country == "France" ? "€" : 'FCFA'),
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(width: 20),
          ],
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(
              width: 25,
            ),
            Expanded(
              child: Text(
                current_dish!.description ?? "",
                maxLines: 3,
                overflow: TextOverflow.ellipsis, // and this
              ),
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(
              width: 20,
            ),
            ElevatedButton(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See options',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 24.0,
                    color: Colors.grey,
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(
              width: 20,
            ),
            Text(
              "Quantity",
              style: kLoginSubtitleStyle4(size),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Color.fromARGB(255, 225, 221, 221)),
              child: Row(
                children: [
                  InkWell(
                      onTap: () {
                        if (number_of_parts != 0) {
                          setState(() {
                            number_of_parts = number_of_parts - 1;
                          });
                        }
                      },
                      child: Icon(
                        Icons.remove,
                        color: Colors.black,
                        size: 16,
                      )),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Color.fromARGB(255, 225, 221, 221)),
                    child: Text(
                      number_of_parts.toString(),
                      style: TextStyle(color: Colors.black, fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                      onTap: () {
                        if (number_of_parts < (current_dish!.nb_servings ?? 0)) {
                          setState(() {
                            number_of_parts = number_of_parts + 1;
                          });
                        }
                      },
                      child: Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 16,
                      )),
                ],
              ),
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        SizedBox(
          height: size.height * 0.08,
        ),
        Center(
          child: ElevatedButton(
            onPressed: () {},
            child: Text(
              'Add to cart',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 5,
              fixedSize: const Size(200, 40),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite() async {
    final nextValue = await FavoritesService.toggleDishFavorite(widget.dish_id);
    if (!mounted) return;
    setState(() {
      isFavorite = nextValue;
    });
  }

  Future<void> readJson() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Dishes.json');
    final data = await json.decode(response);

    setState(() {
      _items = data["items"];
    });
  }

  Future<void> getCategories() async {
    final String response =
        await rootBundle.loadString('assets/static_data/DishCategories.json');
    final data = await json.decode(response);
    setState(() {
      _items_categories = data["items"];
    });
  }

/*_getCategoryDetails() async {
    var id = widget.dish_id;
    for (var i = 0, j = _items_categories.length; i < j; i++) {
      if (_items_categories[i]["id"] == current_dish["category_id"]) {
        setState(() {
          _category_details = _items_categories[i];
        });
      }
    }
  }*/
}
