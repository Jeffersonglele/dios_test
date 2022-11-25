class ScreenArguments {
  final int id;
  final int fromPage;
  final String category;

  ScreenArguments(this.id, this.fromPage, this.category);

  getId() {
    return this.id;
  }

  getFromPage() {
    return this.fromPage;
  }

  getFoodCategory() {
    return this.category;
  }
}
