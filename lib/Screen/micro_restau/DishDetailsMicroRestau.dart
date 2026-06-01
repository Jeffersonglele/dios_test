import 'dart:io';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constant/Constant.dart';
import '../../modeles/dish.dart';
import '../../providers/cart_provider.dart' as cartProvider;
import '../../providers/users_provider.dart';
import '../../utils/DeviseFormat.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import 'package:path/path.dart' as p;

import '../Cart.dart' as screenCart;
import '../../widgets/comment_section.dart';

class DishDetailsMicroRestau extends ConsumerStatefulWidget {
  static const routeName = '/DishDetailsMicroRestau';

  final int dish_id;
  final int from_page;
  final int dish_restau;

  DishDetailsMicroRestau({required this.dish_id, required this.from_page, required this.dish_restau});

  @override
  _DishDetailsMicroRestauState createState() => _DishDetailsMicroRestauState();
}

class _DishDetailsMicroRestauState extends ConsumerState<DishDetailsMicroRestau> {
  final _formKey = GlobalKey<FormState>();
  String? country = "";
  int currentUser_id = 0;
  int currentUser_restau = 0;
  int currentUser_role = 0;
  String currentUser_country = "";
  bool restau_de_luser_connecte = false;

  bool isEditMode = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  TextEditingController nameController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  TextEditingController nbOrdersController = TextEditingController();
  TextEditingController nbServingsController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  TextEditingController categoriesController = TextEditingController();
  bool isAvailable = true;
  bool select_image = false;
  List<String> _selectedHashtags = [];
  List<String> _selectedHashtagsFromDatabase = [];

  Dish? current_dish;
  Restaurant? current_dish_restau;

  int selectedQuantity = 1; // Default value

  List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    country = prefs.getString('currentUser_country');
    currentUser_restau = prefs.getInt('currentUser_restau') ?? 0;
    currentUser_role = prefs.getInt('currentUser_role') ?? 0;
    currentUser_id = prefs.getInt('loggedUserID') ?? 0;
    currentUser_country = prefs.getString('currentUser_country') ?? "France";

    List<Dish> dishesList = await Dish.fetchDishesFromDB();
    Dish? dish = await Dish.getDishByDishId(dishesList, widget.dish_id);

    setState(() {
      current_dish = dish;

      if(currentUser_restau == dish?.restauID){
        restau_de_luser_connecte =  true;
        print("restau_de_luser_connecte " + restau_de_luser_connecte.toString());
      }

      if (current_dish != null) {
        nameController.text = current_dish!.name!;
        priceController.text = current_dish!.price.toString();
        descriptionController.text = current_dish!.description!;
        nbOrdersController.text = current_dish!.nb_orders.toString();
        nbServingsController.text = current_dish!.nb_servings.toString();
        noteController.text = current_dish!.note.toString();
        categoriesController.text = current_dish!.categories!;
        isAvailable = current_dish!.status == 1;

        _selectedHashtags = current_dish!.categories!.split(', ');
        _selectedHashtagsFromDatabase = _selectedHashtags;

        List<String?> options = [
          current_dish!.option1,
          current_dish!.option2,
          current_dish!.option3,
        ];

        for (int i = 0; i < options.length; i++) {
          _optionControllers[i].text = options[i] ?? "";
        }
      }
    });
  }

  void _removeOption(int index) {
    setState(() {
      // Supprime le contenu à l'index donné
      _optionControllers[index].clear();

      // Décale les options suivantes
      for (int i = index; i < 2; i++) {
        _optionControllers[i].text = _optionControllers[i + 1].text;
      }

      // Vide la dernière option
      _optionControllers[2].clear();
    });
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
        nameController.text != current_dish!.name ||
        descriptionController.text != current_dish!.description ||
        _optionControllers[0].text != (current_dish!.option1 ?? "") ||
        _optionControllers[1].text != (current_dish!.option2 ?? "") ||
        _optionControllers[2].text != (current_dish!.option3 ?? "") ||
        priceController.text != current_dish!.price.toString() ||
        nbServingsController.text != current_dish!.nb_servings.toString() ||
        _selectedHashtags.join(', ') != current_dish!.categories ||
        select_image == true ||
        isAvailable != (current_dish!.status == 1);
  }

  bool hasNewImage() {
    return selectedImage != null;
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final cartNotifier = ref.read(cartProvider.cartStateProvider.notifier);

    if (current_dish == null) {
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
                        padding:
                        EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
                        margin:
                        EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: current_dish?.image != null && current_dish!.image!.trim().isNotEmpty
                                ? NetworkImage(current_dish!.image!)
                                : AssetImage('assets/images/no_image.png')
                            as ImageProvider,
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
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      if (isEditMode)
                        Flexible(
                          flex: 3,
                          child: _buildTextField(
                            controller: nameController,
                            hintText: "Nom du plat",
                            maxLines: 2,
                            icon: Icons.restaurant,
                          ),
                        ),
                      if (!isEditMode)
                        Text(current_dish?.name ?? "", style: kLoginSubtitleStyle3(size)),
                      Spacer(),
                      if (isEditMode)
                        Flexible(
                          flex: 2,
                          child: country == "France"
                              ? _buildTextField(
                            controller: priceController,
                            hintText: "Prix du plat (en euro €)",
                            icon: Icons.money,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(,\d{0,2})?')),
                              LengthLimitingTextInputFormatter(5),
                              FrenchFormat(decimalRange: 2),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Entrez un prix';
                              }
                              return null;
                            },
                          )
                              : _buildTextField(
                            controller: priceController,
                            hintText: "Prix du plat (en FCFA)",
                            icon: Icons.money,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                              CFAFormat(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Entrez un prix';
                              }
                              return null;
                            },
                          ),
                        ),
                      if (!isEditMode)
                        Text(
                          "${current_dish!.price} ${country == "France" ? "€" : 'FCFA'}",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      SizedBox(width: 20),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: 25),
                      if (isEditMode)
                        Expanded(
                          child: _buildTextField(
                            controller: descriptionController,
                            hintText: "Description",
                            icon: Icons.description,
                            maxLines: 3,
                          ),
                        ),
                      if (!isEditMode)
                        Expanded(
                          child: Text(
                            current_dish?.description ?? "",
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
                            categoriesController.text = _selectedHashtags.join(', ');
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
                  currentUser_role == 4 || restau_de_luser_connecte ?
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Options :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ..._buildEditableOptions()
                      ],
                    ),
                  ) :
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sélectionnez vos options :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ..._buildSelectableOptions(current_dish!)
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  if(currentUser_role == 2 && !restau_de_luser_connecte)
                   Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        children: [
                          StarRating(rating: double.parse(noteController.text)),
                          Spacer(),
                          DropdownButton<int>(
                            value: selectedQuantity, // The currently selected value
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedQuantity = newValue; // Update the selected value
                                });
                              }
                            },
                            items: List.generate(
                              current_dish!.nb_servings ?? 5,
                                  (index) => DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            dropdownColor: Colors.white, // Optional: Set the dropdown background color
                            style: TextStyle(
                              color: Colors.black, // Text color
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )

                   ),


                  if(currentUser_role != 2 || restau_de_luser_connecte)
                  Row(
                    children: [
                      SizedBox(width: 25),
                      Expanded(
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: Text(
                                'Informations',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Valeur',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: [
                            DataRow(cells: [
                              DataCell(
                                Text(
                                  'Nombre de commandes',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
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
                                  'Portions disponibles',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                isEditMode
                                    ? _buildTextField(
                                  controller: nbServingsController,
                                  hintText: "Portions disponibles",
                                  icon: Icons.fastfood,
                                  keyboardType: TextInputType.number,
                                )
                                    : Text(
                                  nbServingsController.text,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ]),
                            DataRow(cells: [
                              DataCell(
                                Text(
                                  'Note',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    StarRating(
                                        rating:
                                        double.parse(noteController.text)),
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
                                      fontSize: 16, fontWeight: FontWeight.bold),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.05),
                  if(currentUser_role != 2 || restau_de_luser_connecte)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isEditMode) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  nameController.text = current_dish?.name ?? "";
                                  priceController.text = current_dish!.price.toString();
                                  descriptionController.text = current_dish?.description ?? "";
                                  nbServingsController.text = current_dish!.nb_servings.toString();
                                  isAvailable = current_dish!.status == 1;
                                  isEditMode = false;
                                });
                              },
                              child: Text('Annuler', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: ElevatedButton(
                              onPressed: () async {
                              if (isEditMode && hasChanges()) {
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

                                    String createResult = await Dish.manageDish(
                                      dishID: current_dish!.dishID,
                                      userID: user.userID,
                                      nb_orders: current_dish!.nb_orders,
                                      note: current_dish!.note,
                                      categories: _selectedHashtags.join(', '),
                                      description: descriptionController.text,
                                      option1: _optionControllers[0].text,
                                      option2: _optionControllers[1].text,
                                      option3: _optionControllers[2].text,
                                      name: nameController.text,
                                      price: double.tryParse(priceController.text) ?? 0.0,
                                      nb_servings: int.tryParse(nbServingsController.text) ?? 0,
                                      restauID: currentUser_restau,
                                      status: isAvailable ? 1 : 0,
                                      image: parseFile,
                                      img_url: current_dish?.image,
                                    );

                                    Toast(
                                      context,
                                      createResult == "success" ? "Plat modifié avec succès" : "Erreur : $createResult",
                                      createResult == "success",
                                    );

                                    if (createResult == "success") {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                }
                              }
                              setState(() {
                                isEditMode = !isEditMode;
                                nameController.text = current_dish?.name ?? "";
                                priceController.text = current_dish!.price.toString();
                                descriptionController.text = current_dish?.description ?? "";
                                nbServingsController.text = current_dish!.nb_servings.toString();
                                isAvailable = current_dish!.status == 1;
                              });
                            },
                            child: Text(isEditMode ? 'Valider' : 'Modifier', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if(currentUser_role == 2 && !restau_de_luser_connecte)
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                List<String?> options = [current_dish!.option1, current_dish!.option2, current_dish!.option3];
                                for (int i = 0; i < options.length; i++) {
                                  String? opt = options[i];
                                  if (opt != null && opt.trim().isNotEmpty) {
                                    if (!selectedChoices.containsKey(i)) {
                                      Toast(context, "Veuillez sélectionner un choix pour l'option ${i + 1}", false);
                                      return;
                                    }
                                  }
                                }

                                // Calcul du prix final
                                double prixPlat = current_dish?.price ?? 0.0;
                                double prixTotalOptions = 0.0;

                                for (int i = 0; i < options.length; i++) {
                                  String? opt = options[i];
                                  String? selectedChoice = selectedChoices[i];

                                  if (opt == null || opt.trim().isEmpty || selectedChoice == null || selectedChoice == "Aucun choix") {
                                    continue;
                                  }

                                  List<String> parts = opt.split(':');
                                  if (parts.length <= 1) continue;

                                  List<String> choixList = parts[1].split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                  String prixStr = choixList.isNotEmpty ? choixList.last : '';
                                  prixStr = prixStr.replaceAll(',', '.');

                                  double? prix = double.tryParse(prixStr);

                                  if (prix != null) {
                                    prixTotalOptions += prix;
                                    selectedChoices[i] = selectedChoice; // juste le nom, sans prix
                                  }
                                }

                                print("current_dish!.dishID " + current_dish!.dishID.toString());
                                final addResult = await cartNotifier.addToCart(
                                  current_dish!.dishID,
                                  current_dish?.name ?? "Plat",
                                  prixPlat,
                                  current_dish?.image ?? '',
                                  selectedQuantity,
                                  current_dish?.nb_servings ?? 0,
                                  currentUser_country,
                                  currentUser_id,
                                  widget.dish_restau,
                                  selectedChoices: selectedChoices,
                                  optionPrice: prixTotalOptions,
                                  rawOptions: options,
                                );

                                if (addResult == 'different_restaurant') {
                                  Toast(
                                    context,
                                    "Le panier ne peut contenir que des plats d'un seul restaurant.",
                                    false,
                                  );
                                  return;
                                }

                                if (addResult != 'success') {
                                  Toast(
                                    context,
                                    "Impossible d'ajouter ce plat au panier.",
                                    false,
                                  );
                                  return;
                                }

                                Toast(context, "Le plat ${current_dish?.name} a été ajouté au panier !", true);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => screenCart.Cart(),
                                  ),
                                );
                              },
                              child: Text('Ajouter au panier', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (currentUser_role == 2) ...[
                    SizedBox(height: size.height * 0.03),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: CommentSection(
                        targetType: 2,
                        targetID: widget.dish_id,
                      ),
                    ),
                  ],
                  SizedBox(height: size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptionsDisplay(Dish dish) {
    List<String?> options = [dish.option1, dish.option2, dish.option3];
    List<Widget> widgets = [];

    for (var opt in options) {
      if (opt != null && opt.trim().isNotEmpty) {
        var parts = opt.split(':');
        String nomOption = parts.first.trim();
        String choixStr = parts.length > 1 ? parts[1].trim() : "";
        List<String> choixList = choixStr.split('/').map((e) => e.trim()).toList();
        String? prix = choixList.length > 3 ? choixList[3] : null;
        List<String> choix = choixList.take(3).toList(); // max 3 choix


        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nomOption,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  children: choix
                      .where((c) => c.isNotEmpty)
                      .map((c) => Chip(label: Text(c)))
                      .toList(),
                ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Prix de l'option : $prix ${country == "France" ? "€" : "FCFA"}",
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ))
              ],
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(Text("Aucune option définie."));
    }

    return widgets;
  }

  List<Widget> _buildEditableOptions() {
    List<Widget> widgets = [];

    for (int i = 0; i < _optionControllers.length; i++) {
      String fullText = _optionControllers[i].text;
      if (fullText.trim().isEmpty) continue;

      String displayText = fullText;

      try {
        List<String> parts = fullText.split(':');
        String nom = parts[0].trim();
        List<String> choixList = parts.length > 1
            ? parts[1].split('/').map((e) => e.trim()).toList()
            : [];

        String? prix = "";
        String choixDisplay = "";

        if (choixList.isNotEmpty) {
          prix = choixList.last; // dernier = prix
          List<String> choix = choixList.sublist(0, choixList.length - 1);
          choixDisplay = choix.join(' / ');
        }

        displayText = "$nom: $choixDisplay";

        if (prix != null && prix.isNotEmpty) {
          displayText += " / $prix ${country == "France" ? "€" : "FCFA"}";
        }
      } catch (_) {
        displayText = fullText;
      }

      widgets.add(
        ListTile(
          title: Text(displayText),
          trailing: isEditMode
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _showOptionDialog(optionIndex: i),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _removeOption(i),
              ),
            ],
          )
              : null,
        ),
      );
    }

    return widgets;
  }

  Map<int, String> selectedChoices = {};

  List<Widget> _buildSelectableOptions(Dish dish) {
    List<String?> options = [dish.option1, dish.option2, dish.option3];
    List<Widget> widgets = [];
    print("options " + options.toString());

    for (int i = 0; i < options.length; i++) {
      String? opt = options[i];
      if (opt == null || opt.trim().isEmpty) continue;

      var parts = opt.split(':');
      String title = parts.first.trim();
      List<String> choixList = parts.length > 1
          ? parts[1].split('/').map((e) => e.trim()).toList()
          : [];

      String? prixOption;
      List<String> vraisChoix = [];

      if (choixList.isNotEmpty) {
        prixOption = choixList.last;
        vraisChoix = choixList.sublist(0, choixList.length - 1);
      }

      vraisChoix = ['Aucun choix', ...vraisChoix.where((c) => c.isNotEmpty)];

      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
          if (prixOption != null && prixOption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "Prix de l'option : $prixOption ${country == "France" ? "€" : "FCFA"}",
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ...vraisChoix.map((c) {
            return RadioListTile<String>(
              title: Text(c),
              value: c,
              groupValue: selectedChoices[i],
              onChanged: (val) {
                setState(() {
                  selectedChoices[i] = val!;
                });
              },
            );
          }).toList(),
          SizedBox(height: 10),
        ],
      ));
    }

    return widgets;
  }

  void _showOptionDialog({required int optionIndex}) {
    final existing = _optionControllers[optionIndex].text;

    List<String> parts = existing.split(": ");
    String nomInitial = parts.length > 1 ? parts[0] : "";
    List<String> sousParts = parts.length > 1 ? parts[1].split("/") : [];

    TextEditingController nomController = TextEditingController(text: nomInitial);
    TextEditingController choix1Controller = TextEditingController(text: sousParts.isNotEmpty ? sousParts[0].trim() : "");
    TextEditingController choix2Controller = TextEditingController(text: sousParts.length > 1 ? sousParts[1].trim() : "");
    TextEditingController choix3Controller = TextEditingController(text: sousParts.length > 2 ? sousParts[2].trim() : "");
    TextEditingController prixController = TextEditingController(
      text: sousParts.length > 3 ? sousParts[3].trim() : "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Option ${optionIndex + 1}"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: "Nom de l'option"),
              ),
              TextField(
                controller: choix1Controller,
                decoration: InputDecoration(labelText: "Choix 1"),
              ),
              TextField(
                controller: choix2Controller,
                decoration: InputDecoration(labelText: "Choix 2"),
              ),
              TextField(
                controller: choix3Controller,
                decoration: InputDecoration(labelText: "Choix 3"),
              ),
              TextField(
                controller: prixController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(,\d{0,2})?$')),
                  LengthLimitingTextInputFormatter(6), // Par exemple : "999,99"
                ],
                decoration: InputDecoration(labelText: "Prix de l'option (format 00,00)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Valider"),
            onPressed: () {
              String nom = nomController.text.trim();
              String c1 = choix1Controller.text.trim();
              String c2 = choix2Controller.text.trim();
              String c3 = choix3Controller.text.trim();
              String prix = prixController.text.trim();

              if (nom.isEmpty || c1.isEmpty || prix.isEmpty) {
                Toast(context, "Nom, choix 1 et prix sont obligatoires", false);
                return;
              }

              String result = "$nom: $c1 / $c2 / $c3 / $prix";

              setState(() {
                _optionControllers[optionIndex].text = result;
              });

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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
}
