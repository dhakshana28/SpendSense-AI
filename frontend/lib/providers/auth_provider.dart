import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/firebase/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      debugPrint('Auth state changed: ${user != null ? 'Logged in as ${user.uid}' : 'Logged out'}');
      notifyListeners();
    });
  }

  final FirebaseService _firebaseService = FirebaseService();
  late final StreamSubscription<User?> _subscription;
  User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  User? get firebaseUser => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<UserModel?> login(String email, String password) async {
    _setLoading(true);
    try {
      final user = await _firebaseService.signInUser(
        email: email.trim(),
        password: password,
      );
      await _cacheSession();
      debugPrint('AuthProvider.login: success for $email');
      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In AuthProvider.login'),
      ));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel> register(String name, String email, String password) async {
    _setLoading(true);
    try {
      final user = await _firebaseService.registerUser(
        displayName: name.trim(),
        email: email.trim(),
        password: password,
      );
      await _cacheSession();
      debugPrint('AuthProvider.register: success for $email');
      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In AuthProvider.register'),
      ));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseService.sendPasswordReset(email.trim());
      debugPrint('AuthProvider.resetPassword: success for $email');
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In AuthProvider.resetPassword'),
      ));
      rethrow;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _firebaseService.signOut();
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(AppConstants.isLoggedIn);
      await preferences.remove(AppConstants.userId);
      await preferences.remove(AppConstants.userEmail);
      await preferences.remove(AppConstants.userName);
      debugPrint('AuthProvider.logout: success');
    } catch (e, stackTrace) {
      debugPrint('AuthProvider.logout error: $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In AuthProvider.logout'),
      ));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _cacheSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(AppConstants.isLoggedIn, true);
      await preferences.setString(AppConstants.userId, user.uid);
      await preferences.setString(AppConstants.userEmail, user.email ?? '');
      await preferences.setString(AppConstants.userName, user.displayName ?? '');
    } catch (e) {
      debugPrint('AuthProvider._cacheSession error: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
