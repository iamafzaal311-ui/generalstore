import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/store_profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/local_db_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/sync_service.dart';

final localDbServiceProvider = Provider<LocalDbService>((ref) {
  throw UnimplementedError('The database service is provided in main().');
});

final syncServiceProvider = Provider<SyncService>((ref) {
  throw UnimplementedError('The sync service is provided in main().');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(localDbServiceProvider);
  FirebaseFirestore? firestore;
  FirebaseAuth? auth;
  try {
    if (Firebase.apps.isNotEmpty) {
      firestore = FirebaseFirestore.instance;
      auth = FirebaseAuth.instance;
    }
  } catch (_) {}

  final remoteDataSource = AuthRemoteDataSourceImpl(firestore, auth);
  final sync = ref.watch(syncServiceProvider);
  return AuthRepositoryImpl(db, remoteDataSource, sync);
});

final currentUserProvider = StateProvider<UserModel?>((ref) => null);
final currentRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});

final storeProfileProvider = StateProvider<StoreProfileModel?>((ref) => null);
