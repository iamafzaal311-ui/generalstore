import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../../data/models/store_profile_model.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────
// AuthState
// ─────────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> users;
  final bool isDeactivated;
  final String? deactivationReason;
  final String deactivationTarget; // 'store' or 'user'

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.users = const [],
    this.isDeactivated = false,
    this.deactivationReason,
    this.deactivationTarget = 'store',
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? users,
    bool? isDeactivated,
    String? deactivationReason,
    String? deactivationTarget,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      users: users ?? this.users,
      isDeactivated: isDeactivated ?? this.isDeactivated,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      deactivationTarget: deactivationTarget ?? this.deactivationTarget,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// AuthController
// ─────────────────────────────────────────────────────────────────
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  StreamSubscription<DocumentSnapshot>? _storeSubscription;
  StreamSubscription<BoxEvent>? _userSubscription;

  AuthController(this._repository, this._ref) : super(AuthState()) {
    _init();
  }

  String _getFriendlyErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid-credential') || msg.contains('wrong-password') || msg.contains('user-not-found')) {
      return 'Invalid email or password.';
    } else if (msg.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    } else if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    } else if (msg.contains('invalid-email') || msg.contains('badly formatted')) {
      return 'The email address is badly formatted.';
    } else if (msg.contains('user-disabled')) {
      return 'This account has been disabled.';
    } else if (msg.contains('email-already-in-use')) {
      return 'An account already exists for that email.';
    } else if (msg.contains('weak-password')) {
      return 'The password provided is too weak (min 6 chars).';
    }
    return 'Error details: $e';
  }

  Future<void> _init() async {
    final user = await _repository.getCurrentUser();
    if (user != null) {
      _ref.read(currentUserProvider.notifier).state = user;
      _startRealtimeDeactivationListeners(user);
      if (Firebase.apps.isNotEmpty) {
        try {
          final adminUid = FirebaseAuth.instance.currentUser?.uid;
          if (adminUid != null) {
            final doc = await FirebaseFirestore.instance
                .collection('stores')
                .doc(adminUid)
                .collection('profile')
                .doc('info')
                .get()
                .timeout(const Duration(seconds: 8));
            _ref.read(storeProfileProvider.notifier).state =
                StoreProfileModel.fromFirestore(doc);
          }
        } catch (_) {}
      }
    }
    await loadUsers();
  }

  void _startRealtimeDeactivationListeners(UserModel currentUser) {
    _storeSubscription?.cancel();
    _userSubscription?.cancel();

    // 1. Listen to Store deactivation (in Firestore)
    if (Firebase.apps.isNotEmpty) {
      try {
        final adminUid = FirebaseAuth.instance.currentUser?.uid;
        if (adminUid != null) {
          _storeSubscription = FirebaseFirestore.instance
              .collection('stores')
              .doc(adminUid)
              .snapshots()
              .listen((snapshot) async {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;
              final isActive = data['isActive'] as bool? ?? true;
              if (!isActive) {
                final reason = data['deactivationReason'] as String? ??
                    'This store has been deactivated by the developer.';
                state = state.copyWith(
                  isDeactivated: true,
                  deactivationTarget: 'store',
                  deactivationReason: reason,
                );
                await logout();
              }
            }
          });
        }
      } catch (_) {}
    }

    // 2. Listen to local User deactivation (Hive)
    final db = _ref.read(localDbServiceProvider);
    _userSubscription = db.usersBox.watch(key: currentUser.userId).listen((event) async {
      final user = db.usersBox.get(currentUser.userId);
      if (user != null && !user.isActive) {
        state = state.copyWith(
          isDeactivated: true,
          deactivationTarget: 'user',
          deactivationReason: user.deactivationReason.isNotEmpty
              ? user.deactivationReason
              : 'Your account has been deactivated.',
        );
        await logout();
      }
    });
  }

  /// Admin (store owner) login via Firebase email/password.
  Future<bool> adminLogin(String email, String password) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isDeactivated: false,
      deactivationReason: null,
    );
    try {
      final user = await _repository.adminLogin(email, password);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;

        // Check if this store is active in Firestore
        StoreProfileModel? profile;
        try {
          final adminUid = FirebaseAuth.instance.currentUser!.uid;
          final doc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(adminUid)
              .collection('profile')
              .doc('info')
              .get()
              .timeout(const Duration(seconds: 8));

          profile = StoreProfileModel.fromFirestore(doc);

          if (!profile.isActive) {
            // Do NOT sign out of Firebase Auth so Developer Dashboard can still fetch data
            _ref.read(currentUserProvider.notifier).state = null;
            state = state.copyWith(
              isLoading: false,
              isDeactivated: true,
              deactivationTarget: 'store',
              deactivationReason: (profile.deactivationReason?.isNotEmpty == true)
                  ? profile.deactivationReason
                  : 'This store has been deactivated by the developer.',
              errorMessage: null,
            );
            return false;
          }
          _ref.read(storeProfileProvider.notifier).state = profile;
        } catch (_) {
          // Network error — allow login if credentials already cached locally
        }
        _startRealtimeDeactivationListeners(user);
      }
      await loadUsers();
      state = state.copyWith(isLoading: false);
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      return false;
    }
  }

  /// Register a new store account in Firebase.
  Future<bool> registerStore(
    String email,
    String password,
    StoreProfileModel profile,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (Firebase.apps.isNotEmpty) {
        try {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          if (cred.user != null) {
            final uid = cred.user!.uid;
            await FirebaseFirestore.instance
                .collection('stores')
                .doc(uid)
                .collection('profile')
                .doc('info')
                .set(profile.toMap());
            await FirebaseFirestore.instance.collection('stores').doc(uid).set({
              ...profile.toMap(),
              'uid': uid,
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
            });
            // Log out so developer can hand over credentials
            await FirebaseAuth.instance.signOut();
          }
        } catch (e) {
          state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
          return false;
        }
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      return false;
    }
  }

  /// Fetch all stores for the developer dashboard.
  Future<List<Map<String, dynamic>>> fetchAllStores() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .get()
          .timeout(const Duration(seconds: 12));

      final List<Map<String, dynamic>> results = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;
        data['uid'] = uid;

        // Fallback or override from profile/info
        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(uid)
              .collection('profile')
              .doc('info')
              .get()
              .timeout(const Duration(seconds: 5));
          if (profileDoc.exists && profileDoc.data() != null) {
            data.addAll(profileDoc.data()!);
          }
        } catch (_) {}

        results.add(data);
      }
      // Synthesize local stores from local Admins
      try {
        final localUsers = await _repository.getAllUsers();
        for (final lu in localUsers) {
          if (lu.role == 'Admin' && !results.any((r) => r['uid'] == lu.userId)) {
            results.add({
              'uid': lu.userId,
              'storeName': lu.fullName.isNotEmpty ? lu.fullName : 'Local Store',
              'email': lu.username,
              'isActive': lu.isActive,
              'deactivationReason': lu.deactivationReason,
            });
          }
        }
      } catch (_) {}

      return results;
    } catch (e) {
      print('DEBUG fetchAllStores Error: $e');
      
      final List<Map<String, dynamic>> localResults = [];
      try {
        final localUsers = await _repository.getAllUsers();
        for (final lu in localUsers) {
          if (lu.role == 'Admin') {
            localResults.add({
              'uid': lu.userId,
              'storeName': lu.fullName.isNotEmpty ? lu.fullName : 'Local Store',
              'email': lu.username,
              'isActive': lu.isActive,
              'deactivationReason': lu.deactivationReason,
            });
          }
        }
      } catch (_) {}
      
      return localResults;
    }
  }

  /// Fetch ALL users across ALL stores for developer panel.
  /// This includes:
  ///   1. The store admin/owner (from the root `stores` document itself)
  ///   2. All staff users (from `stores/{uid}/users` sub-collection)
  Future<List<Map<String, dynamic>>> fetchAllStoreUsers() async {
    final List<Map<String, dynamic>> allUsers = [];
    try {
      final storesSnap = await FirebaseFirestore.instance
          .collection('stores')
          .get()
          .timeout(const Duration(seconds: 12));

      for (final storeDoc in storesSnap.docs) {
        final storeData = storeDoc.data();
        final storeUid = storeDoc.id;

        // Fetch details from profile/info to get accurate storeName
        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeUid)
              .collection('profile')
              .doc('info')
              .get()
              .timeout(const Duration(seconds: 5));
          if (profileDoc.exists && profileDoc.data() != null) {
            storeData.addAll(profileDoc.data()!);
          }
        } catch (_) {}

        final storeName = (storeData['storeName'] as String?) ?? 'Unknown Store';
        final storeEmail = (storeData['email'] as String?) ?? '';
        final isActive = (storeData['isActive'] as bool?) ?? true;
        final deactivationReason = (storeData['deactivationReason'] as String?) ?? '';

        // 1. Add the admin/owner as a user row
        allUsers.add({
          'fullName': storeName.isNotEmpty ? storeName : storeEmail,
          'username': storeEmail.isNotEmpty ? storeEmail : 'admin@$storeUid',
          'role': 'Admin (Owner)',
          'isActive': isActive,
          'deactivationReason': deactivationReason,
          'storeName': storeName,
          'storeUid': storeUid,
          'uid': storeUid,
          'isAdmin': true,
        });

        // 2. Add all staff users from sub-collection
        try {
          final usersSnap = await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeUid)
              .collection('users')
              .get()
              .timeout(const Duration(seconds: 8));
          for (final userDoc in usersSnap.docs) {
            final userData = Map<String, dynamic>.from(userDoc.data());
            userData['storeName'] = storeName;
            userData['storeUid'] = storeUid;
            userData['uid'] = userDoc.id;
            userData['isAdmin'] = false;
            allUsers.add(userData);
          }
        } catch (_) {}
      }
    } catch (e) {
      print('DEBUG fetchAllStoreUsers Error: $e');
    }

    // Always fetch local users as fallback/addition
    try {
      final localUsers = await _repository.getAllUsers();
      for (final lu in localUsers) {
        // Only add if not already added from Firebase (by uid)
        if (!allUsers.any((u) => u['uid'] == lu.userId)) {
          allUsers.add({
            'fullName': lu.fullName,
            'username': lu.username,
            'role': lu.role,
            'isActive': lu.isActive,
            'deactivationReason': lu.deactivationReason,
            'storeName': 'Local Store',
            'storeUid': 'local',
            'uid': lu.userId,
            'isAdmin': lu.role == 'Admin',
          });
        }
      }
    } catch (_) {}

    return allUsers;
  }

  /// Toggle a store's active/inactive status. Saves reason when deactivating.
  Future<bool> toggleStoreStatus(
    String uid,
    bool currentStatus, {
    String reason = '',
  }) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      final newStatus = !currentStatus;
      final Map<String, dynamic> updateData = {'isActive': newStatus};

      if (!newStatus) {
        updateData['deactivationReason'] = reason;
        updateData['deactivatedAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['deactivationReason'] = '';
        updateData['deactivatedAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(uid)
          .collection('profile')
          .doc('info')
          .set(updateData, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }
  /// Delete an entire store (including all users and subcollections)
  Future<bool> deleteStore(String uid) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      // Note: In a real production app, deleting subcollections from the client is usually not recommended
      // or requires recursive delete cloud functions. For this, we'll delete known documents.
      
      // Delete all users in this store
      final usersSnap = await FirebaseFirestore.instance.collection('stores').doc(uid).collection('users').get();
      for (var doc in usersSnap.docs) {
        await doc.reference.delete();
      }
      
      // Delete profile info
      await FirebaseFirestore.instance.collection('stores').doc(uid).collection('profile').doc('info').delete();
      
      // Delete the main store doc
      await FirebaseFirestore.instance.collection('stores').doc(uid).delete();
      
      return true;
    } catch (e) {
      print('DEBUG deleteStore Error: $e');
      return false;
    }
  }

  /// Update store info
  Future<bool> updateStore(String uid, Map<String, dynamic> data) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      await FirebaseFirestore.instance.collection('stores').doc(uid).set(data, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('stores').doc(uid).collection('profile').doc('info').set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('DEBUG updateStore Error: $e');
      return false;
    }
  }

  /// Delete a specific user within a store
  Future<bool> deleteStoreUser(String storeUid, String userUid) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      if (storeUid == 'local') {
        await _repository.deleteUser(userUid);
      } else {
        await FirebaseFirestore.instance.collection('stores').doc(storeUid).collection('users').doc(userUid).delete();
      }
      return true;
    } catch (e) {
      print('DEBUG deleteStoreUser Error: $e');
      return false;
    }
  }

  /// Update a specific user within a store
  Future<bool> updateStoreUser(String storeUid, String userUid, Map<String, dynamic> data) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      if (storeUid == 'local') {
        await _repository.updateUser(userUid, data);
      } else {
        await FirebaseFirestore.instance.collection('stores').doc(storeUid).collection('users').doc(userUid).update(data);
      }
      return true;
    } catch (e) {
      print('DEBUG updateStoreUser Error: $e');
      return false;
    }
  }


  /// Staff/local user login via Hive username + password.
  Future<bool> login(String username, String password) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isDeactivated: false,
      deactivationReason: null,
    );
    try {
      final user = await _repository.login(username, password);
      if (user != null) {
        if (!user.isActive) {
          state = state.copyWith(
            isLoading: false,
            isDeactivated: true,
            deactivationTarget: 'user',
            deactivationReason: user.deactivationReason.isNotEmpty
                ? user.deactivationReason
                : 'Your account has been deactivated.',
            errorMessage: null,
          );
          return false;
        }
        _ref.read(currentUserProvider.notifier).state = user;
        _startRealtimeDeactivationListeners(user);
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid username or password.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.signInWithGoogle();
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google sign-in was cancelled or failed.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      return false;
    }
  }

  Future<String?> sendPhoneVerificationCode(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final verificationId = await _repository.sendPhoneVerificationCode(
        phoneNumber,
      );
      state = state.copyWith(isLoading: false);
      return verificationId;
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('configuration-not-found')) {
        msg = 'Phone Auth is not configured for Web. Please use Username/Password.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return null;
    }
  }

  Future<bool> verifyPhoneCode(String verificationId, String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.verifyPhoneCode(verificationId, smsCode);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Phone verification failed. Please try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      return false;
    }
  }

  void setErrorMessage(String? message) {
    state = state.copyWith(errorMessage: message);
  }

  void clearDeactivation() {
    state = state.copyWith(
      isDeactivated: false,
      deactivationReason: null,
    );
  }

  Future<void> logout() async {
    _storeSubscription?.cancel();
    _userSubscription?.cancel();
    await _repository.logout();
    _ref.read(currentUserProvider.notifier).state = null;
  }

  Future<void> loadUsers() async {
    try {
      final list = await _repository.getAllUsers();
      state = state.copyWith(users: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.createUser(
        username: username,
        fullName: fullName,
        password: password,
        role: role,
      );
      await loadUsers();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getFriendlyErrorMessage(e));
      rethrow;
    }
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resetPassword(userId, newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Toggle a local (Hive) user's active status with an optional deactivation reason.
  Future<void> toggleUserStatus(
    String userId,
    bool isActive, {
    String reason = '',
  }) async {
    try {
      await _repository.toggleUserStatus(userId, isActive);
      // Save reason in Hive
      final db = _ref.read(localDbServiceProvider);
      final user = db.usersBox.get(userId);
      if (user != null) {
        user.deactivationReason = isActive ? '' : reason;
        user.isDirty = true;
        user.lastUpdated = DateTime.now();
        await user.save();
      }
      await loadUsers();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
      await loadUsers();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    return AuthController(repo, ref);
  },
);
