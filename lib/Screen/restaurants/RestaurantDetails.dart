import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constant/Constant.dart';
import '../../modeles/dish.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../providers/cart_provider.dart' as cartProvider;
import '../../providers/users_provider.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/stars.dart';
import 'package:path/path.dart' as p;
import '../Cart.dart' as screenCart;
import '../../utils/toast.dart';
import '../micro_restau/DishDetailsMicroRestau.dart';

class RestaurantDetails extends ConsumerStatefulWidget {
  static const routeName = '/RestaurantDetailsMicroRestau';

  final int restaurant_id;

  RestaurantDetails({required this.restaurant_id});

  @override
  _RestaurantDetailsState createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends ConsumerState<RestaurantDetails> {
  final _formKey = GlobalKey<FormState>();
  String? country = "";
  int currentUser_restau = 0;
  int currentUser_role = 0;
  int currentUser_id = 0;
  String currentUser_country = "";
  bool restau_de_luser_connecte = false;

  bool isEditMode = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  TextEditingController nameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController nbOrdersController = TextEditingController();
  TextEditingController nbServingsController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  TextEditingController categoriesController = TextEditingController();
  bool isAvailable = true;
  bool select_image = false;
  List<String> _selectedHashtags = [];
  List<String> _selectedHashtagsFromDatabase = [];
  List<Dish> dishes = [];
  List<Dish> filteredDishes = [];

  Restaurant? current_restaurant;

  // Ajoutez ces deux variables
  List<Map<String, dynamic>> _current_meals =
      []; // Liste des plats dans le panier
  double total = 0.0; // Total du panier

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      currentUser_role = prefs.getInt('currentUser_role') ?? 0;
      currentUser_country = prefs.getString('currentUser_country') ?? "France";
      currentUser_id = prefs.getInt('loggedUserID') ?? 0;

      // Chargement des restaurants et des plats depuis la base de données
      List<Restaurant> restaurantsList =
          await Restaurant.fetchRestaurantsFromDB();
      Restaurant? restaurant = await Restaurant.getRestaurantByRestaurantId(
          restaurantsList, widget.restaurant_id);

      List<Dish> allDishes = await Dish.fetchDishesFromDB();

      // Filtrage des plats associés au restaurant actuel
      List<Dish> filteredDishes = allDishes
          .where((dish) => dish.restauID == widget.restaurant_id)
          .toList();

      // Mise à jour de l'état
      setState(() {
        currentUser_restau = prefs.getInt('currentUser_restau') ?? 0;

        current_restaurant = restaurant;
        dishes = filteredDishes;

        if (currentUser_restau == current_restaurant?.restaurantID) {
          restau_de_luser_connecte = true;
        }

        if (current_restaurant != null) {
          nameController.text = current_restaurant!.name!;
          addressController.text = current_restaurant!.adress!;
          descriptionController.text = current_restaurant!.description!;
          nbOrdersController.text = current_restaurant!.nb_orders.toString();
          nbServingsController.text = current_restaurant!.nb_orders.toString();
          noteController.text = current_restaurant!.note.toString();
          categoriesController.text = current_restaurant!.categories!;
          isAvailable = current_restaurant!.valid == 1;

          _selectedHashtags = current_restaurant!.categories!.split(', ');
          _selectedHashtagsFromDatabase = _selectedHashtags;
        }
      });
    } catch (e) {
      print("Erreur lors du chargement des données : $e");
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        select_image == true;
        selectedImage = File(image.path);
      });
    }
  }

  bool hasChanges() {
    return selectedImage != null ||
        nameController.text != current_restaurant!.name ||
        descriptionController.text != current_restaurant!.description ||
        nbServingsController.text != current_restaurant!.nb_orders.toString() ||
        _selectedHashtags.join(', ') != current_restaurant!.categories ||
        select_image == true ||
        isAvailable != (current_restaurant!.valid == 1);
  }

  bool hasNewImage() {
    return selectedImage != null;
  }

  void _showRestaurantInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(current_restaurant?.name ?? "Informations"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current_restaurant?.adress != null)
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current_restaurant!.adress!,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Ouvert jusqu'à 20h ",
                    //todo decommenter "Ouvert jusqu'à ${current_restaurant?.closingTime ?? ''}",
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  StarRating(rating: double.parse(noteController.text)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final cartNotifier = ref.read(cartProvider.cartStateProvider.notifier);
    final cartItems = ref.watch(cartProvider.cartStateProvider);

    if (current_restaurant == null) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.03),
                  Stack(
                    children: [
                      Container(
                        constraints:
                            BoxConstraints.expand(height: 300.0, width: 400),
                        padding: EdgeInsets.only(
                            left: 16.0, bottom: 8.0, right: 16.0),
                        margin: EdgeInsets.only(
                            left: 16.0, bottom: 8.0, right: 16.0),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: (current_restaurant?.image != null &&
                                current_restaurant!.image!.trim().isNotEmpty)
                                ? NetworkImage(current_restaurant!.image!)
                                : AssetImage('assets/images/no_image.png') as ImageProvider,
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
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  // Coins arrondis
                                  color: Colors.white,
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: CircleAvatar(
                                    radius: 6, // Taille du cercle
                                    backgroundColor:
                                        isAvailable ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEditMode)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      SizedBox(height: 8),
                      SizedBox(height: size.height * 0.02),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      isEditMode
                          ? Flexible(
                              flex: 3,
                              child: _buildTextField(
                                controller: nameController,
                                hintText: "Nom du plat",
                                maxLines: 2,
                                icon: Icons.restaurant,
                              ),
                            )
                          : Text(current_restaurant?.name ?? "",
                              style: kLoginSubtitleStyle3(size)),
                      Spacer(),
                      Text(
                        "${country == "France" ? "€" : 'FCFA'}",
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      isEditMode
                          ? Flexible(
                              child: _buildTextField(
                                controller: descriptionController,
                                hintText: "Description du restaurant",
                                maxLines: 3,
                                icon: Icons.description,
                              ),
                            )
                          : Expanded(
                              child: Text(
                                current_restaurant?.description ?? "",
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      SizedBox(width: 20),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  if (isEditMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: HashtagTextInputFormatter(
                        initialHashtags: _selectedHashtagsFromDatabase,
                        onHashtagsChanged: (hashtags) {
                          setState(() {
                            _selectedHashtags = hashtags;
                            categoriesController.text =
                                _selectedHashtags.join(', ');
                          });
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Text(
                      "Catégories : ${categoriesController.text}",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  currentUser_role == 1 ||
                          currentUser_role == 4 ||
                          restau_de_luser_connecte
                      ? Row(
                          children: [
                            SizedBox(width: 25),
                            Expanded(
                              child: DataTable(
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Informations',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Valeur',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                rows: [
                                  DataRow(cells: [
                                    DataCell(
                                      Text(
                                        'Nombre de commandes',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        nbOrdersController.text,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(
                                      Text(
                                        'Note',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          StarRating(
                                              rating: double.parse(
                                                  noteController.text)),
                                          SizedBox(width: 8),
                                          Text(
                                            "${noteController.text}/5",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(
                                      Text(
                                        'Statut',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? Switch(
                                              value: isAvailable,
                                              onChanged: (value) {
                                                setState(() {
                                                  isAvailable = value;
                                                });
                                              },
                                            )
                                          : Text(
                                              isAvailable
                                                  ? "Disponible"
                                                  : "Indisponible",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                    ),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(
                                      Text(
                                        'Adresse',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        addressController.text,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25.0),
                          child: Row(
                            children: [
                              StarRating(
                                  rating: double.parse(noteController.text)),
                              SizedBox(width: 8),
                              Text(
                                "${noteController.text}/5",
                                style: TextStyle(fontSize: 16),
                              ),
                              Spacer(),
                              TextButton(
                                onPressed: () {
                                  _showRestaurantInfoDialog(context);
                                },
                                child: Text(
                                  "Informations",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration
                                        .underline, // Ajoute le soulignement
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  SizedBox(height: size.height * 0.05),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Text(
                      "Menu",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: dishes.length,
                      itemBuilder: (context, index) {
                        final dish = dishes[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DishDetailsMicroRestau(
                                      dish_id: dish.dishID,
                                      from_page: 1,
                                      dish_restau: widget.restaurant_id),
                                ),
                              );
                            },
                            child: buildImage(dish.image),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DishDetailsMicroRestau(
                                      dish_id: dish.dishID,
                                      from_page: 1,
                                      dish_restau: widget.restaurant_id),
                                ),
                              );
                            },
                            child: Text(
                              dish.name ?? "",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          subtitle: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DishDetailsMicroRestau(
                                      dish_id: dish.dishID,
                                      from_page: 1,
                                      dish_restau: widget.restaurant_id),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish.description ?? "",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      "${dish.price?.toStringAsFixed(2)} ${currentUser_country == 'France' ? '€' : 'FCFA'}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    if (currentUser_role == 2) Spacer(),
                                    /*if (currentUser_role == 2 &&
                                        current_restaurant?.restaurantID !=
                                            currentUser_restau)
                                      Tooltip(
                                        message: "Ajouter au panier",
                                        child: GestureDetector(
                                          onTap: () {
                                            cartNotifier.addToCart(
                                                dish.name ?? "Plat",
                                                dish.price ?? 0.0,
                                                dish.image ?? '',
                                                1,
                                                // Quantité par défaut
                                                dish.nb_servings ?? 0,
                                                // Nombre de portions max
                                                currentUser_country ?? "France",
                                                currentUser_id,
                                                widget.restaurant_id);
                                            Toast(
                                                context,
                                                "Le plat ${dish?.name} a été ajouté au panier !",
                                                true);

                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    screenCart.Cart(),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),*/
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8),
                  if (currentUser_role == 3 || restau_de_luser_connecte)
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isEditMode) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    nameController.text =
                                        current_restaurant?.name ?? "";
                                    descriptionController.text =
                                        current_restaurant?.description ?? "";
                                    nbServingsController.text =
                                        current_restaurant!.nb_orders
                                            .toString();
                                    isAvailable =
                                        current_restaurant!.valid == 1;
                                    isEditMode = false;
                                  });
                                },
                                child: Text('Annuler',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isEditMode) {
                                  // Tu es en mode édition, donc tu valides
                                  if (_formKey.currentState?.validate() ?? false) {
                                    final user = ref.read(usersProvider);
                                    if (user != null) {
                                      ParseFile? parseFile;
                                      if (hasNewImage()) {
                                        String fileName = p.basename(selectedImage!.path);
                                        String extension = p.extension(fileName);
                                        String newFileName = "${nameController.text}_${user.userID}$extension";
                                        parseFile = ParseFile(File(selectedImage!.path), name: newFileName);
                                      }

                                      String result = await Restaurant.manageRestaurant(
                                        restaurantID: current_restaurant!.restaurantID,
                                        userID: user.userID,
                                        categories: _selectedHashtags.join(', '),
                                        description: descriptionController.text,
                                        adress: addressController.text,
                                        name: nameController.text,
                                        note: current_restaurant!.note,
                                        nb_orders: current_restaurant!.nb_orders,
                                        valid: isAvailable ? 1 : 0,
                                        date_creation: current_restaurant?.date_creation,
                                        image: parseFile,
                                        img_url: current_restaurant?.image,
                                      );

                                      if (result == "success") {
                                        Toast(context, "Restaurant mis à jour", true);
                                        // recharge les données localement
                                        await loadData();
                                      } else {
                                        Toast(context, "Erreur : $result", false);
                                      }
                                    }
                                  }
                                }

                                // Quoi qu'il arrive, on repasse en mode affichage
                                setState(() {
                                  isEditMode = !isEditMode;
                                });
                              },
                              child: Text(isEditMode ? 'Valider' : 'Modifier',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hintText,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  int? maxLines = 1,
}) {
  return TextFormField(
    controller: controller,
    decoration: InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    ),
    validator: validator,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
  );
}

Widget buildImage(String? imageUrl) {
  // Vérifie si le lien est une URL valide
  if (imageUrl != null && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
    return Image.network(
      imageUrl,
      height: 200,
      width: 200,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/no_image.png',
          // Image par défaut si le chargement échoue
          height: 200,
          width: 200,
          fit: BoxFit.fitWidth,
        );
      },
    );
  } else {
    // Si ce n'est pas une URL valide, utilisez une image locale
    return Image.asset(
      'assets/images/no_image.png',
      height: 200,
      width: 200,
      fit: BoxFit.fitWidth,
    );
  }
}
