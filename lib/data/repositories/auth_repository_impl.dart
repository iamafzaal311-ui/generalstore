import 'dart:async';
import 'package:uuid/uuid.dart';

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

    final adminExists = _db.usersBox.values.any((u) => u.username == 'ALI ABBAS');
    if (!adminExists) {
      final salt = HashHelper.generateSalt();
      final hashedPassword = HashHelper.hashPassword('ali123', salt);
      
      final admin = UserModel()
        ..userId = const Uuid().v4()
        ..username = 'ALI ABBAS'
        ..fullName = 'ALI ABBAS'
        ..passwordHash = hashedPassword
        ..salt = salt
        ..role = 'Admin'
        ..isActive = true
        ..isDirty = true
        ..lastUpdated = DateTime.now();
      await _db.usersBox.put(admin.userId, admin);
    }

    _initialized = true;
  }

  @override
  Future<UserModel?> adminLogin(String email, String password) async {
    await initialize();
    await _remote.adminLogin(email, password);
    await _sync.restoreAllFromCloud();

    final adminUser = UserModel()
      ..userId = 'admin_firebase_id'
      ..username = email
      ..fullName = 'Store Admin'
      ..role = 'Admin'
      ..isActive = true
      ..isDirty = false
      ..lastUpdated = DateTime.now();

    _currentUser = adminUser;
    return adminUser;
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    await initialize();

    var user = _db.usersBox.values.where((u) => u.username.toLowerCase() == username.toLowerCase()).firstOrNull;

    if (user != null && user.isActive) {
      final hashed = HashHelper.hashPassword(password, user.salt);
      if (hashed == user.passwordHash) {
        _currentUser = user;
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
  Future<UserModel?> verifyPhoneCode(String verificationId, String smsCode) async {
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

    final existing = _db.usersBox.values.where((u) => u.username == username).firstOrNull;

    if (existing != null) {
      throw Exception('Username already exists');
    }

    final salt = HashHelper.generateSalt();
    final hashedPassword = HashHelper.hashPassword(password, salt);
    final user = UserModel()
      ..userId = const Uuid().v4()
      ..username = username
      ..fullName = fullName
      ..passwordHash = hashedPassword
      ..salt = salt
      ..role = role
      ..isActive = true
      ..isDirty = true
      ..lastUpdated = DateTime.now();

    await _db.usersBox.put(user.userId, user);
    await _sync.syncDirtyRecords();
  }

  @override
  Future<void> resetPassword(String userId, String newPassword) async {
    await initialize();

    final user = _db.usersBox.values.where((u) => u.userId == userId).firstOrNull;

    if (user == null) throw Exception('User not found');

    final salt = HashHelper.generateSalt();
    final hashedPassword = HashHelper.hashPassword(newPassword, salt);

    user.salt = salt;
    user.passwordHash = hashedPassword;
    user.isDirty = true;
    user.lastUpdated = DateTime.now();

    await user.save();
    await _sync.syncDirtyRecords();
  }

  @override
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await initialize();

    final user = _db.usersBox.values.where((u) => u.userId == userId).firstOrNull;

    if (user == null) throw Exception('User not found');

    user.isActive = isActive;
    user.isDirty = true;
    user.lastUpdated = DateTime.now();

    await user.save();
    await _sync.syncDirtyRecords();
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    await initialize();
    return _db.usersBox.values.toList();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
    _currentUser = null;
  }
}
