import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> adminLogin(String email, String password);
  Future<UserModel?> login(String username, String password);
  Future<UserModel?> signInWithGoogle();
  Future<String> sendPhoneVerificationCode(String phoneNumber);
  Future<UserModel?> verifyPhoneCode(String verificationId, String smsCode);
  Future<void> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
  });
  Future<void> resetPassword(String userId, String newPassword);
  Future<void> toggleUserStatus(String userId, bool isActive);
  Future<List<UserModel>> getAllUsers();
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
}
