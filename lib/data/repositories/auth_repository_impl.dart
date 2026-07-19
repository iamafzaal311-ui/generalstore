import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/sync_service.dart';
import '../../core/utils/hash_helper.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/local_db_service.dart';
import '../models/user_model.dart';

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

    // Default products seeding removed as requested by user.

    _initialized = true;

    // Restore last logged in session
    final lastUserId = _db.settingsBox.get('last_logged_in_user_id');
    if (lastUserId != null) {
      if (Firebase.apps.isNotEmpty) {
        try {
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser != null && lastUserId == fbUser.uid) {
            _currentUser = UserModel()
              ..userId = fbUser.uid
              ..username = fbUser.email ?? 'Admin'
              ..fullName = 'Ali Abbas'
              ..role = 'Admin'
              ..isActive = true
              ..isDirty = false
              ..lastUpdated = DateTime.now();
            return;
          }
        } catch (_) {}
      }

      final localUser = _db.usersBox.get(lastUserId);
      if (localUser != null && localUser.isActive) {
        _currentUser = localUser;
      }
    }
  }

  @override
  Future<UserModel?> adminLogin(String email, String password) async {
    await initialize();

    String? oldUid;
    if (Firebase.apps.isNotEmpty) {
      try {
        oldUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    await _remote.adminLogin(email, password);

    String? newUid;
    if (Firebase.apps.isNotEmpty) {
      try {
        newUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (oldUid != null && newUid != null && oldUid != newUid) {
      await _db.cleanDb(); // Wipe local DB if a DIFFERENT store admin logs in
    }

    await _sync.restoreAllFromCloud();

    String storeName = 'Store Owner';
    if (newUid != null && Firebase.apps.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(newUid)
            .collection('profile')
            .doc('info')
            .get()
            .timeout(const Duration(seconds: 5));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['storeName'] != null && data['storeName'].toString().isNotEmpty) {
            storeName = data['storeName'];
          }
        }
      } catch (_) {}
    }

    final adminUser = UserModel()
      ..userId = newUid ?? 'admin_firebase_id'
      ..username = email
      ..fullName = storeName
      ..passwordHash = ''
      ..salt = ''
      ..role = 'Admin'
      ..isActive = true
      ..isDirty = false
      ..lastUpdated = DateTime.now();

    _currentUser = adminUser;
    await _db.usersBox.put(adminUser.userId, adminUser); // Cache locally for dev dashboard
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
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await initialize();
    final user = _db.usersBox.get(uid);
    if (user != null) {
      if (data.containsKey('fullName')) user.fullName = data['fullName'];
      if (data.containsKey('username')) user.username = data['username'];
      if (data.containsKey('role')) user.role = data['role'];
      if (data.containsKey('isActive')) user.isActive = data['isActive'];
      user.isDirty = true;
      user.lastUpdated = DateTime.now();
      await user.save();
    }
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
      if (Firebase.apps.isNotEmpty) {
        final oldUser = FirebaseAuth.instance.currentUser;
        if (oldUser != null) {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(oldUser.uid)
              .collection('users')
              .doc(userId)
              .delete();
        }
      }
    } catch (_) {}
  }

  Future<void> adminLogout() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final oldUser = FirebaseAuth.instance.currentUser;
        if (oldUser != null) {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(oldUser.uid)
              .update({'lastActive': FieldValue.serverTimestamp()});
        }
      } catch (_) {}
    }
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
