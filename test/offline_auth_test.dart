import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generalstore/data/datasources/auth_remote_data_source.dart';
import 'package:generalstore/data/datasources/local_db_service.dart';
import 'package:generalstore/data/models/user_model.dart';
import 'package:generalstore/data/repositories/auth_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDbService db;
  late AuthRepositoryImpl repository;

  setUp(() async {
    final _ = Directory.systemTemp.createTempSync('generalstore_test').path;
    db = LocalDbService();
    await db.init();
    repository = AuthRepositoryImpl(db, _StubRemoteDataSource());
    await repository.initialize();
  });

  tearDown(() async {
    
  });

  test('offline login works with the seeded admin user', () async {
    final user = await repository.login('admin', 'admin');

    expect(user, isNotNull);
    expect(user!.username, 'admin');
    expect(user.role, 'Super Admin');
  });
}

class _StubRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel?> login(String username, String password) async => null;

  @override
  Future<UserModel?> loginWithGoogle() async => null;

  @override
  Future<String> sendPhoneVerificationCode(String phoneNumber) async => '';

  @override
  Future<UserModel?> verifyPhoneCode(String verificationId, String smsCode) async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> syncUsers(List<UserModel> localUsers) async {}
}
