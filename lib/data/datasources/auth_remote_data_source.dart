import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<void> adminLogin(String email, String password);
  Future<void> adminRegister(String email, String password);
  Future<UserModel?> login(String username, String password);
  Future<UserModel?> loginWithGoogle();
  Future<String> sendPhoneVerificationCode(String phoneNumber);
  Future<UserModel?> verifyPhoneCode(String verificationId, String smsCode);
  Future<void> logout();
  Future<void> syncUsers(List<UserModel> localUsers);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  // GoogleSignIn cannot be initialized on web without a configured OAuth clientId
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  AuthRemoteDataSourceImpl(this._firestore, this._auth);

  @override
  Future<void> adminLogin(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> adminRegister(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      
      final query = await _firestore
          .collection('stores')
          .doc(currentUser.uid)
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first.data();
      final userModel = UserModel()
        ..userId = doc['userId']
        ..username = doc['username']
        ..fullName = doc['fullName']
        ..passwordHash = doc['passwordHash'] ?? ''
        ..salt = doc['salt'] ?? ''
        ..role = doc['role'] ?? 'Cashier'
        ..isActive = doc['isActive'] ?? true
        ..isDirty = false
        ..lastUpdated = DateTime.parse(doc['lastUpdated']);

      return userModel;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel?> loginWithGoogle() async {
    if (_googleSignIn == null) return null;
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return _buildFirebaseUser(userCredential.user);
  }

  @override
  Future<String> sendPhoneVerificationCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (!completer.isCompleted) {
          completer.complete('');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future;
  }

  @override
  Future<UserModel?> verifyPhoneCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return _buildFirebaseUser(userCredential.user);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn?.signOut();
  }

  @override
  Future<void> syncUsers(List<UserModel> localUsers) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    final batch = _firestore.batch();
    for (final user in localUsers) {
      final docRef = _firestore.collection('stores').doc(currentUser.uid).collection('users').doc(user.userId);
      batch.set(docRef, {
        'userId': user.userId,
        'username': user.username,
        'fullName': user.fullName,
        'role': user.role,
        'isActive': user.isActive,
        'passwordHash': user.passwordHash,
        'salt': user.salt,
        'lastUpdated': user.lastUpdated.toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  UserModel? _buildFirebaseUser(User? firebaseUser) {
    if (firebaseUser == null) return null;

    final username = firebaseUser.email ?? firebaseUser.phoneNumber ?? firebaseUser.uid;
    final fullName = firebaseUser.displayName ?? username;

    return UserModel()
      ..userId = firebaseUser.uid
      ..username = username
      ..fullName = fullName
      ..passwordHash = ''
      ..salt = ''
      ..role = 'Cashier'
      ..isActive = true
      ..isDirty = false
      ..lastUpdated = DateTime.now();
  }
}
