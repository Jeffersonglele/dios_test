class ScreenArguments {
  final int id;
  final int fromPage;
  final String category;

  ScreenArguments(this.id, this.fromPage, this.category);

  int getId() {
    return this.id;
  }

  int getFromPage() {
    return this.fromPage;
  }

  String getFoodCategory() {
    return this.category;
  }
}
