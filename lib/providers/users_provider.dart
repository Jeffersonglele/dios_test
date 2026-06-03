import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../modeles/users.dart';
import '../services/session_service.dart';

// StateProvider pour l'utilisateur
final usersProvider = StateProvider<Users?>((ref) => null);

// Provider pour récupérer l'utilisateur depuis la session
final currentUserProvider = FutureProvider<Users?>((ref) async {
  final session = await SessionService.readSession();
  if (session.userId == null) return null;

  // Récupération directe depuis la base de données
  final users = await Users.fetchUsersFromDB();
  return users.cast<Users?>().firstWhere(
        (user) => user?.userID == session.userId,
        orElse: () => null,
      );
});

// Méthode utilitaire pour mettre à jour l'utilisateur
Future<void> updateCurrentUser(WidgetRef ref) async {
  final session = await SessionService.readSession();
  if (session.userId == null) {
    ref.read(usersProvider.notifier).state = null;
    return;
  }

  final users = await Users.fetchUsersFromDB();
  final user = users.cast<Users?>().firstWhere(
        (user) => user?.userID == session.userId,
        orElse: () => null,
      );

  ref.read(usersProvider.notifier).state = user;
}
