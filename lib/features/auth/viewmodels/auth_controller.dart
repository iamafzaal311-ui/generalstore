import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/store_profile_model.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> users;

  AuthState({this.isLoading = false, this.errorMessage, this.users = const []});

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? users,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      users: users ?? this.users,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthController(this._repository, this._ref) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final user = await _repository.getCurrentUser();
    if (user != null) {
      _ref.read(currentUserProvider.notifier).state = user;
      if (Firebase.apps.isNotEmpty) {
        try {
          final adminUid = FirebaseAuth.instance.currentUser?.uid;
          if (adminUid != null) {
            final doc = await FirebaseFirestore.instance
                .collection('stores')
                .doc(adminUid)
                .collection('profile')
                .doc('info')
                .get();
            _ref.read(storeProfileProvider.notifier).state =
                StoreProfileModel.fromFirestore(doc);
          }
        } catch (_) {}
      }
    }
    await loadUsers();
  }

  Future<bool> adminLogin(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.adminLogin(email, password);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;

        try {
          final adminUid = FirebaseAuth.instance.currentUser!.uid;
          final doc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(adminUid)
              .collection('profile')
              .doc('info')
              .get();
          final profile = StoreProfileModel.fromFirestore(doc);
          if (!profile.isActive) {
            if (Firebase.apps.isNotEmpty) {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
            }
            _ref.read(currentUserProvider.notifier).state = null;
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'This store has been deactivated by the Developer.',
            );
            return false;
          }
          _ref.read(storeProfileProvider.notifier).state = profile;
        } catch (_) {}
      }
      await loadUsers(); // Load local employees after syncing
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

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

            // Log out immediately so developer can hand over credentials, or login as Admin manually.
            await FirebaseAuth.instance.signOut();
          }
        } catch (e) {
          state = state.copyWith(isLoading: false, errorMessage: e.toString());
          return false;
        }
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllStores() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('profile')
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        data['uid'] = d.reference.parent.parent?.id ?? '';
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> toggleStoreStatus(String uid, bool currentStatus) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('stores').doc(uid).set({
          'isActive': !currentStatus,
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(uid)
            .collection('profile')
            .doc('info')
            .update({'isActive': !currentStatus});
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.login(username, password);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid username/password or account deactivated',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
        msg =
            'Phone Auth is not configured for Web. Please use Username/Password or sign up locally.';
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  void setErrorMessage(String? message) {
    state = state.copyWith(errorMessage: message);
  }

  Future<void> logout() async {
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _repository.toggleUserStatus(userId, isActive);
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

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    return AuthController(repo, ref);
  },
);
