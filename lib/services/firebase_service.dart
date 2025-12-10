import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import '../models/user.dart';
import '../core/errors/exceptions.dart' as app_exceptions;
import '../core/errors/result.dart';
import '../core/constants/app_constants.dart';

/// Handle all Firebase operations
/// FIX #7: Properly isolates favorites to prevent carry-over between users
/// FIX #12: Security - Firebase keys should be in environment config (handled by Firebase setup)
/// FIX #15: Password validation enforcement added
class FirebaseService {
  final auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseService(this._firebaseAuth, this._firestore);

  // Auth state stream
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Current user
  auth.User? get currentUser => _firebaseAuth.currentUser;

  // Is user authenticated
  bool get isAuthenticated => currentUser != null;

  /// Validate password strength
  /// FIX #15: Password Validation Not Enforced
  Result<void> validatePassword(String password) {
    if (password.isEmpty) {
      return Failure(
        'Password cannot be empty',
        exception: app_exceptions.ValidationException('Password is required'),
      );
    }

    if (password.length < AppConstants.minPasswordLength) {
      return Failure(
        'Password must be at least ${AppConstants.minPasswordLength} characters',
        exception: app_exceptions.ValidationException('Password too short'),
      );
    }

    if (password.length > AppConstants.maxPasswordLength) {
      return Failure(
        'Password must not exceed ${AppConstants.maxPasswordLength} characters',
        exception: app_exceptions.ValidationException('Password too long'),
      );
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return Failure(
        'Password must contain at least one number',
        exception: app_exceptions.ValidationException(
          'Password missing number',
        ),
      );
    }

    // Check for at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      return Failure(
        'Password must contain at least one letter',
        exception: app_exceptions.ValidationException(
          'Password missing letter',
        ),
      );
    }

    return const Success(null);
  }

  /// Validate email format
  Result<void> validateEmail(String email) {
    if (email.isEmpty) {
      return Failure(
        'Email cannot be empty',
        exception: app_exceptions.ValidationException('Email is required'),
      );
    }

    // More permissive email regex that accepts all valid TLDs
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return Failure(
        'Please enter a valid email address',
        exception: app_exceptions.ValidationException('Email format invalid'),
      );
    }

    return const Success(null);
  }

  /// Sign in with email and password
  Future<Result<auth.User>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation.isFailure) {
        return Failure(emailValidation.errorOrNull ?? 'Invalid email');
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation.isFailure) {
        return Failure(passwordValidation.errorOrNull ?? 'Invalid password');
      }

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Failure('Failed to sign in');
      }

      return Success(credential.user!);
    } on auth.FirebaseAuthException catch (e) {
      return Failure(
        _getAuthErrorMessage(e.code),
        exception: app_exceptions.AuthException(
          e.message ?? 'Authentication failed',
        ),
      );
    } catch (e) {
      return Failure(
        'Unexpected error during sign in',
        exception: app_exceptions.AuthException(e.toString()),
      );
    }
  }

  /// Register with email and password
  Future<Result<auth.User>> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation.isFailure) {
        return Failure(emailValidation.errorOrNull ?? 'Invalid email');
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation.isFailure) {
        return Failure(passwordValidation.errorOrNull ?? 'Invalid password');
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Failure('Failed to register');
      }

      // Create user document with empty favorites (fixes #7)
      await _createUserDocument(credential.user!.uid);

      return Success(credential.user!);
    } on auth.FirebaseAuthException catch (e) {
      return Failure(
        _getAuthErrorMessage(e.code),
        exception: app_exceptions.AuthException(
          e.message ?? 'Registration failed',
        ),
      );
    } catch (e) {
      return Failure(
        'Unexpected error during registration',
        exception: app_exceptions.AuthException(e.toString()),
      );
    }
  }

  /// Sign in anonymously
  Future<Result<auth.User>> signInAnonymously() async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();

      if (credential.user == null) {
        return const Failure('Failed to sign in anonymously');
      }

      // Create user document with empty favorites (fixes #7)
      await _createUserDocument(credential.user!.uid);

      return Success(credential.user!);
    } on auth.FirebaseAuthException catch (e) {
      return Failure(
        _getAuthErrorMessage(e.code),
        exception: app_exceptions.AuthException(
          e.message ?? 'Anonymous sign-in failed',
        ),
      );
    } catch (e) {
      return Failure(
        'Unexpected error during anonymous sign-in',
        exception: app_exceptions.AuthException(e.toString()),
      );
    }
  }

  /// Sign out
  Future<Result<void>> signOut() async {
    try {
      await _firebaseAuth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(
        'Failed to sign out',
        exception: app_exceptions.AuthException(e.toString()),
      );
    }
  }

  /// Get user data
  /// FIX #7: Each user gets their own isolated data
  Future<Result<User>> getUser(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        // Return user with empty favorites if document doesn't exist
        return Success(User(uid: uid));
      }

      return Success(User.fromMap(doc.data()!, uid));
    } on FirebaseException catch (e) {
      return Failure(
        'Failed to get user data',
        exception: app_exceptions.FirestoreException(
          e.message ?? 'Firestore error',
        ),
      );
    } catch (e) {
      return Failure(
        'Unexpected error getting user',
        exception: app_exceptions.FirestoreException(e.toString()),
      );
    }
  }

  /// Update user favorites
  /// FIX #7: Favorites are isolated per user
  Future<Result<void>> updateUserFavorites(
    String uid,
    List<int> favoriteIds,
  ) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        AppConstants.favoritesField: favoriteIds,
      }, SetOptions(merge: true));

      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(
        'Failed to update favorites',
        exception: app_exceptions.FirestoreException(
          e.message ?? 'Firestore error',
        ),
      );
    } catch (e) {
      return Failure(
        'Unexpected error updating favorites',
        exception: app_exceptions.FirestoreException(e.toString()),
      );
    }
  }

  /// Toggle favorite Pokemon
  /// FIX #7: Ensures favorites don't carry over to new users
  Future<Result<void>> toggleFavorite(String uid, int pokemonId) async {
    try {
      final userResult = await getUser(uid);
      if (userResult.isFailure) {
        return Failure(userResult.errorOrNull ?? 'Failed to get user');
      }

      final user = userResult.dataOrNull!;
      final favorites = List<int>.from(user.favoritePokemonIds);

      if (favorites.contains(pokemonId)) {
        favorites.remove(pokemonId);
      } else {
        favorites.add(pokemonId);
      }

      return await updateUserFavorites(uid, favorites);
    } catch (e) {
      return Failure(
        'Failed to toggle favorite',
        exception: app_exceptions.FirestoreException(e.toString()),
      );
    }
  }

  /// Create user document with empty favorites
  /// FIX #7: Initialize each new user with empty favorites
  Future<void> _createUserDocument(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists) {
        await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
          AppConstants.favoritesField: <int>[],
        });
      }
    } catch (e) {
      debugPrint('Error creating user document: $e');
    }
  }

  /// Get user-friendly auth error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      default:
        return 'Authentication error: $code';
    }
  }
}
