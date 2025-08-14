import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.initialize();
      _isAuthenticated = _apiService.isAuthenticated;
      // In a real app we'd fetch the user profile here when authenticated
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.login(email, password);
      _user = result.user;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ApiService.register signature is (email, password, name)
      final result = await _apiService.register(email, password, name);
      _user = result.user;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Registration error: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void skipLogin() {
    _user = User(
      id: 'demo-user',
      name: 'Demo User',
      email: 'demo@example.com',
      createdAt: DateTime.now(),
    );
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  String? validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? validateName(String name) {
    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }
}