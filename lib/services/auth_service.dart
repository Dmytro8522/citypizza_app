import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  /// Регистрация по e-mail и паролю с передачей пользовательских метаданных
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String city,
    required String street,
    required String houseNumber,
    required String postalCode,
  }) {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      // сюда передаём любые дополнительные поля
      data: {
        'name': name,
        'phone': phone,
        'address': {
          'city': city,
          'street': street,
          'house_number': houseNumber,
          'postal_code': postalCode,
        },
      },
      // должен совпадать с Redirect URL в вашем Dashboard Supabase
      emailRedirectTo: 'com.citypizza.app://login-callback',
    );
  }

  /// Вход по e-mail и паролю
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Выход
  static Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  /// Текущий пользователь
  static User? get currentUser => _supabase.auth.currentUser;

  /// Текущая сессия
  static Session? get currentSession => _supabase.auth.currentSession;

  /// Слушатель изменений статуса аутентификации
  static Stream<AuthChangeEvent> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange.map((e) => e.event);
}
