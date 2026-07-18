import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/firebase/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _notificationsEnabled = true;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> loadCurrentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      clear();
      return;
    }
    _setLoading(true);
    try {
      _user = await _firebaseService.fetchUser(firebaseUser.uid) ??
          UserModel.createDefault(firebaseUser);
      // Only try to save if we have permission (silently ignore permission errors)
      if (_user!.createdAt == null) {
        try {
          await _firebaseService.saveUser(_user!);
        } catch (saveError) {
          debugPrint('UserProvider.loadCurrentUser: saveUser skipped (non-fatal): $saveError');
        }
      }
      final preferences = await SharedPreferences.getInstance();
      _notificationsEnabled = preferences.getBool('notificationsEnabled') ?? true;
      _error = null;
      debugPrint('UserProvider.loadCurrentUser: loaded user ${firebaseUser.uid}');
    } catch (error, stackTrace) {
      debugPrint('UserProvider.loadCurrentUser error: $error');
      _error = error.toString();
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In UserProvider.loadCurrentUser'),
      ));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String name,
    required String currency,
    required double monthlyIncome,
    required double monthlyBudget,
  }) async {
    final current = _user;
    if (current == null) return;
    _setLoading(true);
    try {
      _user = current.copyWith(
        name: name.trim(),
        currency: currency,
        monthlyIncome: monthlyIncome,
        monthlyBudget: monthlyBudget,
      );
      await _firebaseService.saveUser(_user!);
      _error = null;
      debugPrint('UserProvider.updateProfile: updated user ${current.uid}');
    } catch (error, stackTrace) {
      _user = current;
      _error = error.toString();
      debugPrint('UserProvider.updateProfile error: $error');
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In UserProvider.updateProfile'),
      ));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> pickAndUploadProfileImage() async {
    final current = _user;
    if (current == null) return;
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    _setLoading(true);
    try {
      final bytes = await image.readAsBytes();
      final photoUrl = await _firebaseService.uploadProfileImageBytes(bytes, current.uid);
      _user = current.copyWith(photoUrl: photoUrl);
      await _firebaseService.saveUser(_user!);
      _error = null;
      debugPrint('UserProvider.pickAndUploadProfileImage: uploaded for ${current.uid}');
    } catch (error, stackTrace) {
      _user = current;
      _error = error.toString();
      debugPrint('UserProvider.pickAndUploadProfileImage error: $error');
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('In UserProvider.pickAndUploadProfileImage'),
      ));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('notificationsEnabled', enabled);
  }

  void clear() {
    _user = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
