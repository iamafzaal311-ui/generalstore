import 'package:flutter_test/flutter_test.dart';
import 'package:generalstore/core/utils/hash_helper.dart';

void main() {
  group('HashHelper Tests', () {
    test('generateSalt should return a non-empty base64 string', () {
      final salt = HashHelper.generateSalt();
      expect(salt, isNotEmpty);
      expect(salt.length, greaterThan(10));
    });

    test(
      'hashPassword should generate deterministic hashes for the same salt',
      () {
        const password = 'mySecretPassword123';
        final salt = HashHelper.generateSalt();

        final hash1 = HashHelper.hashPassword(password, salt);
        final hash2 = HashHelper.hashPassword(password, salt);

        expect(hash1, equals(hash2));
      },
    );

    test(
      'hashPassword should generate different hashes for different salts',
      () {
        const password = 'mySecretPassword123';
        final salt1 = HashHelper.generateSalt();
        final salt2 = HashHelper.generateSalt();

        final hash1 = HashHelper.hashPassword(password, salt1);
        final hash2 = HashHelper.hashPassword(password, salt2);

        expect(hash1, isNot(equals(hash2)));
      },
    );
  });
}
