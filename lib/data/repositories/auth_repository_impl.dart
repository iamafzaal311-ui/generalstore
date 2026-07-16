import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/sync_service.dart';
import '../../core/utils/hash_helper.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/local_db_service.dart';
import '../models/user_model.dart';
import '../../core/utils/default_data_helper.dart';

class AuthRepositoryImpl implements AuthRepository {
  final LocalDbService _db;
  final AuthRemoteDataSource _remote;
  final SyncService _sync;
  UserModel? _currentUser;
  bool _initialized = false;

  AuthRepositoryImpl(this._db, this._remote, this._sync) {
    unawaited(initialize());
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Add default products if DB is empty
    if (_db.productsBox.isEmpty) {
      final defaultProducts = DefaultDataHelper.getDefaultPakistaniProducts();
      for (var p in defaultProducts) {
        await _db.productsBox.put(p.productId, p);
      }
    }

    _initialized = true;

    // Restore last logged in session
    final lastUserId = _db.settingsBox.get('last_logged_in_user_id');
    if (lastUserId != null) {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && lastUserId == fbUser.uid) {
        _currentUser = UserModel()
          ..userId = fbUser.uid
          ..username = fbUser.email ?? 'Admin'
          ..fullName = 'Store Admin'
          ..role = 'Admin'
          ..isActive = true
          ..isDirty = false
          ..lastUpdated = DateTime.now();
      } else {
        final localUser = _db.usersBox.get(lastUserId);
        if (localUser != null && localUser.isActive) {
          _currentUser = localUser;
        }
      }
    }
  }

  @override
  Future<UserModel?> adminLogin(String email, String password) async {
    await initialize();

    final oldUser = FirebaseAuth.instance.currentUser;
    final oldUid = oldUser?.uid;

    await _remote.adminLogin(email, password);

    final newUser = FirebaseAuth.instance.currentUser;
    final newUid = newUser?.uid;

    if (oldUid != null && newUid != null && oldUid != newUid) {
      await _db.cleanDb(); // Wipe local DB if a DIFFERENT store admin logs in
    }

    await _sync.restoreAllFromCloud();

    final adminUser = UserModel()
      ..userId = newUid ?? 'admin_firebase_id'
      ..username = email
      ..fullName = 'Store Admin'
      ..role = 'Admin'
      ..isActive = true
      ..isDirty = false
      ..lastUpdated = DateTime.now();

    _currentUser = adminUser;
    await _db.settingsBox.put('last_logged_in_user_id', adminUser.userId);
    return adminUser;
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    await initialize();

    var user = _db.usersBox.values
        .where(
          (u) =>
              u.username.trim().toLowerCase() == username.trim().toLowerCase(),
        )
        .firstOrNull;

    if (user != null && user.isActive) {
      final hashed = HashHelper.hashPassword(password.trim(), user.salt);
      if (hashed == user.passwordHash) {
        _currentUser = user;
        await _db.settingsBox.put('last_logged_in_user_id', user.userId);
        return user;
      }
    }

    return null;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    await initialize();
    final user = await _remote.loginWithGoogle();
    if (user == null) return null;
    await _saveRemoteUser(user);
    return user;
  }

  @override
  Future<String> sendPhoneVerificationCode(String phoneNumber) async {
    await initialize();
    return await _remote.sendPhoneVerificationCode(phoneNumber);
  }

  @override
  Future<UserModel?> verifyPhoneCode(
    String verificationId,
    String smsCode,
  ) async {
    await initialize();
    final user = await _remote.verifyPhoneCode(verificationId, smsCode);
    if (user == null) return null;
    await _saveRemoteUser(user);
    return user;
  }

  Future<void> _saveRemoteUser(UserModel user) async {
    await initialize();

    final existing = _db.usersBox.get(user.userId);

    if (existing != null) {
      existing.username = user.username;
      existing.fullName = user.fullName;
      existing.role = user.role;
      existing.isActive = user.isActive;
      existing.isDirty = user.isDirty;
      existing.lastUpdated = user.lastUpdated;

      await existing.save(); // HiveObject save
      _currentUser = existing;
      return;
    }

    await _db.usersBox.put(user.userId, user);
    _currentUser = user;
  }

  @override
  Future<void> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
  }) async {
    await initialize();

    final trimmedUsername = username.trim();
    final existing = _db.usersBox.values
        .where(
          (u) =>
              u.username.trim().toLowerCase() == trimmedUsername.toLowerCase(),
        )
        .firstOrNull;

    if (existing != null) {
      throw Exception('Username already exists');
    }

    final salt = HashHelper.generateSalt();
    final hashedPassword = HashHelper.hashPassword(password.trim(), salt);
    final user = UserModel()
      ..userId = const Uuid().v4()
      ..username = trimmedUsername
      ..fullName = fullName.trim()
      ..passwordHash = hashedPassword
      ..salt = salt
      ..role = role
      ..isActive = true
      ..isDirty = true
      ..lastUpdated = DateTime.now();

    await _db.usersBox.put(user.userId, user);
    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> resetPassword(String userId, String newPassword) async {
    await initialize();

    final user = _db.usersBox.values
        .where((u) => u.userId == userId)
        .firstOrNull;

    if (user == null) throw Exception('User not found');

    final salt = HashHelper.generateSalt();
    final hashedPassword = HashHelper.hashPassword(newPassword, salt);

    user.salt = salt;
    user.passwordHash = hashedPassword;
    user.isDirty = true;
    user.lastUpdated = DateTime.now();

    await user.save();
    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await initialize();

    final user = _db.usersBox.values
        .where((u) => u.userId == userId)
        .firstOrNull;

    if (user == null) throw Exception('User not found');

    user.isActive = isActive;
    user.isDirty = true;
    user.lastUpdated = DateTime.now();

    await user.save();
    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> deleteUser(String userId) async {
    await initialize();

    await _db.usersBox.delete(userId);
    try {
      final oldUser = FirebaseAuth.instance.currentUser;
      if (oldUser != null) {
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(oldUser.uid)
            .collection('users')
            .doc(userId)
            .delete();
      }
    } catch (_) {}
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    await initialize();
    return _db.usersBox.values.toList();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    await initialize();
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    if (_currentUser?.role == 'Admin') {
      try {
        unawaited(_sync.syncDirtyRecords());
      } catch (_) {}
      // We DO NOT call _remote.logout() and _db.cleanDb() here because we want
      // the local session (for Staff) to keep working and syncing with Firebase!
    }
    _currentUser = null;
    await _db.settingsBox.delete('last_logged_in_user_id');
  }
}
