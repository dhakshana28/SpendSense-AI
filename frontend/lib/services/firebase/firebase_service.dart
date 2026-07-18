import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../app/constants/app_constants.dart';
import '../../models/budget_model.dart';
import '../../models/expense_model.dart';
import '../../models/goal_model.dart';
import '../../models/income_model.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get incomeRef =>
      _firestore.collection(AppConstants.incomeCollection);

  CollectionReference<Map<String, dynamic>> get expensesRef =>
      _firestore.collection(AppConstants.expenseCollection);

  CollectionReference<Map<String, dynamic>> get budgetsRef =>
      _firestore.collection(AppConstants.budgetCollection);

  CollectionReference<Map<String, dynamic>> get goalsRef =>
      _firestore.collection(AppConstants.goalsCollection);

  CollectionReference<Map<String, dynamic>> get reportsRef =>
      _firestore.collection(AppConstants.reportsCollection);

  static String getFriendlyErrorMessage(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException [${e.code}]: ${e.message}');
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid. Please enter a valid email.';
      case 'user-disabled':
        return 'This account has been disabled by an administrator.';
      case 'user-not-found':
        return 'No account found with this email. Please check or register.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please contact support.';
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login':
        return 'Please log out and log back in before making this change.';
      case 'provider-already-linked':
        return 'This account is already linked to this provider.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      case 'email-not-verified':
        return 'Please verify your email address before logging in.';
      case 'expired-action-code':
        return 'The action code has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'The action code is invalid. Please request a new one.';
      case 'missing-email':
        return 'Please enter an email address.';
      case 'missing-password':
        return 'Please enter a password.';
      case 'session-cookie-expired':
        return 'Your session has expired. Please log in again.';
      case 'internal-error':
        return 'An internal error occurred. Please try again later.';
      case 'invalid-user-token':
        return 'Your session is invalid. Please log in again.';
      case 'user-token-expired':
        return 'Your session has expired. Please log in again.';
      case 'web-context-cancelled':
        return 'Sign in was cancelled.';
      case 'web-internal-error':
        return 'A web sign-in error occurred. Please try again.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not configured. Please ensure Email/Password sign-in is enabled in the Firebase Console.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }

  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create user account. Please try again.');
      }
      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.reload();
      final model = UserModel(
        uid: firebaseUser.uid,
        name: displayName,
        email: email,
        photoUrl: firebaseUser.photoURL,
      );
      await usersRef.doc(model.uid).set(model.toMap());
      debugPrint('User registered successfully: ${model.uid}');
      return model;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In registerUser'),
      ));
      rethrow;
    }
  }

  Future<UserModel?> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      await firebaseUser.reload();

      // Try to fetch the user document from Firestore
      UserModel? userModel;
      try {
        userModel = await fetchUser(firebaseUser.uid);
      } catch (e) {
        debugPrint('signInUser: fetchUser failed (will create default): $e');
      }

      // If document doesn't exist or fetch failed, create a default one
      if (userModel == null) {
        debugPrint('signInUser: Creating default user document for ${firebaseUser.uid}');
        userModel = UserModel.createDefault(firebaseUser);
        try {
          await usersRef.doc(userModel.uid).set(userModel.toMap(), SetOptions(merge: true));
          debugPrint('signInUser: Default user document created');
        } catch (e) {
          debugPrint('signInUser: Failed to create default document (non-fatal): $e');
        }
      }

      debugPrint('User signed in successfully: ${firebaseUser.uid}');
      return userModel;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In signInUser'),
      ));
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In sendPasswordReset'),
      ));
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In signOut'),
      ));
      rethrow;
    }
  }

  Future<UserModel?> fetchUser(String uid) async {
    try {
      final snapshot = await usersRef.doc(uid).get(const GetOptions(source: Source.server));
      if (!snapshot.exists) {
        debugPrint('fetchUser: Document does not exist for uid: $uid');
        return null;
      }
      return UserModel.fromMap(snapshot.data()!);
    } on FirebaseException catch (e) {
      debugPrint('fetchUser: FirebaseException for uid $uid: ${e.code} - ${e.message}');
      // Return null instead of throwing - caller will create default profile
      return null;
    } catch (e, stackTrace) {
      debugPrint('fetchUser: Error for uid $uid: $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In fetchUser for uid: $uid'),
      ));
      // Return null instead of throwing - caller will create default profile
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    try {
      await usersRef.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      debugPrint('User saved: ${user.uid}');
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In saveUser for uid: ${user.uid}'),
      ));
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await usersRef.doc(user.uid).update(user.toMap());
      debugPrint('User updated: ${user.uid}');
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In updateUser for uid: ${user.uid}'),
      ));
      rethrow;
    }
  }

  Future<String> uploadProfileImageBytes(Uint8List bytes, String uid) async {
    try {
      final ref = _storage.ref().child('profile_images/$uid/profile.jpg');
      final snapshot = await ref.putData(bytes);
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('Profile image uploaded for uid: $uid');
      return url;
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In uploadProfileImageBytes for uid: $uid'),
      ));
      rethrow;
    }
  }

  Future<String> uploadReceiptBytes(Uint8List bytes, String fileName) async {
    try {
      final ref = _storage.ref().child('receipts/$fileName');
      final snapshot = await ref.putData(bytes);
      return await snapshot.ref.getDownloadURL();
    } catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        context: ErrorDescription('In uploadReceiptBytes'),
      ));
      rethrow;
    }
  }

  Future<List<IncomeModel>> fetchIncomes(String userId) async {
    try {
      final snapshot = await incomeRef
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchIncomes: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> addIncome(IncomeModel income) async {
    try {
      await incomeRef.doc(income.id).set(income.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in addIncome: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    try {
      await incomeRef.doc(income.id).update(income.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in updateIncome: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    try {
      await incomeRef.doc(id).delete();
    } catch (e, stackTrace) {
      debugPrint('Error in deleteIncome: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<ExpenseModel>> fetchExpenses(String userId) async {
    try {
      final snapshot = await expensesRef
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchExpenses: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await expensesRef.doc(expense.id).set(expense.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in addExpense: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await expensesRef.doc(expense.id).update(expense.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in updateExpense: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await expensesRef.doc(id).delete();
    } catch (e, stackTrace) {
      debugPrint('Error in deleteExpense: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<BudgetModel>> fetchBudgets(String userId) async {
    try {
      final snapshot = await budgetsRef
          .where('userId', isEqualTo: userId)
          .orderBy('startDate', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => BudgetModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchBudgets: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> addBudget(BudgetModel budget) async {
    try {
      await budgetsRef.doc(budget.id).set(budget.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in addBudget: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> updateBudget(BudgetModel budget) async {
    try {
      await budgetsRef.doc(budget.id).update(budget.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in updateBudget: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await budgetsRef.doc(id).delete();
    } catch (e, stackTrace) {
      debugPrint('Error in deleteBudget: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<GoalModel>> fetchGoals(String userId) async {
    try {
      final snapshot = await goalsRef
          .where('userId', isEqualTo: userId)
          .orderBy('deadline', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => GoalModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchGoals: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> addGoal(GoalModel goal) async {
    try {
      await goalsRef.doc(goal.id).set(goal.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in addGoal: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    try {
      await goalsRef.doc(goal.id).update(goal.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in updateGoal: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await goalsRef.doc(id).delete();
    } catch (e, stackTrace) {
      debugPrint('Error in deleteGoal: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> addReport(ReportModel report) async {
    try {
      await reportsRef.doc(report.userId).set(report.toMap());
    } catch (e, stackTrace) {
      debugPrint('Error in addReport: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<ReportModel>> fetchReports(String userId) async {
    try {
      final snapshot = await reportsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ReportModel.fromMap(doc.data())).toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchReports: $e\n$stackTrace');
      rethrow;
    }
  }
}