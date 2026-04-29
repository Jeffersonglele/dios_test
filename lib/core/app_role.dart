enum AppRole {
  admin(1),
  individual(2),
  microRestaurant(3),
  superAdmin(4),
  unknown(0);

  const AppRole(this.id);

  final int id;

  static AppRole fromId(int? id) {
    for (final role in AppRole.values) {
      if (role.id == id) {
        return role;
      }
    }
    return AppRole.unknown;
  }

  bool get isAdmin => this == AppRole.admin || this == AppRole.superAdmin;

  bool get isProfessional => this == AppRole.microRestaurant;

  bool get isIndividual => this == AppRole.individual;
}
