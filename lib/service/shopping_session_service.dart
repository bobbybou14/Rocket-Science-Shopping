import '../models/shopping_session.dart';

class ShoppingSessionService {
  static ShoppingSession? _activeSession;

  static ShoppingSession? get activeSession => _activeSession;

  static bool get hasActiveSession =>
      _activeSession != null && _activeSession!.active;

  static String get currentStoreName {
    return _activeSession?.storeName ?? '';
  }

  static String get currentCurrency {
    return _activeSession?.currency ?? 'CAD';
  }

  static ShoppingSession startSession({required String storeName}) {
    final session = ShoppingSession.newSession(storeName: storeName);

    _activeSession = session;

    return session;
  }

  static ShoppingSession? updateStore(String storeName) {
    final session = _activeSession;

    if (session == null) {
      return startSession(storeName: storeName);
    }

    _activeSession = session.copyWith(storeName: storeName);

    return _activeSession;
  }

  static ShoppingSession? endSession() {
    final session = _activeSession;

    if (session == null) {
      return null;
    }

    final completedSession = session.copyWith(active: false);

    _activeSession = null;

    return completedSession;
  }

  static void clearSession() {
    _activeSession = null;
  }

  static void restoreSession(ShoppingSession session) {
    _activeSession = session;
  }
}
