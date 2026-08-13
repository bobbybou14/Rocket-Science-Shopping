import '../models/shopping_session.dart';

class ShoppingSessionService {
  static ShoppingSession? _activeSession;

  static ShoppingSession? get activeSession => _activeSession;

  static bool get hasActiveSession =>
      _activeSession != null && _activeSession!.active;

  static String get currentStoreId {
    return _activeSession?.storeId ?? '';
  }

  static String get currentStoreName {
    return _activeSession?.storeName ?? '';
  }

  static String get currentCurrency {
    return _activeSession?.currency ?? 'CAD';
  }

  static ShoppingSession startSession({
    required String storeId,
    required String storeName,
  }) {
    final session = ShoppingSession.newSession(
      storeId: storeId,
      storeName: storeName,
    );

    _activeSession = session;

    return session;
  }

  static ShoppingSession? updateStore({
    required String storeId,
    required String storeName,
  }) {
    final session = _activeSession;

    if (session == null) {
      return startSession(storeId: storeId, storeName: storeName);
    }

    _activeSession = session.copyWith(storeId: storeId, storeName: storeName);

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
