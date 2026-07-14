import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/local_db_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

final localDbServiceProvider = Provider<LocalDbService>((ref) {
  throw UnimplementedError('The database service is provided in main().');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(localDbServiceProvider);
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final remoteDataSource = AuthRemoteDataSourceImpl(firestore, auth);
  return AuthRepositoryImpl(db, remoteDataSource);
});

final currentUserProvider = StateProvider<UserModel?>((ref) => null);
final currentRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});
