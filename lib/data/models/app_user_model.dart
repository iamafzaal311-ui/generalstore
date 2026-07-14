/// A non-Isar plain Dart model representing the currently logged-in user session.
/// This is used in-memory for the session state, not for database persistence.
/// For database persistence, see [UserModel].
class AppUserModel {
  final String userId;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;

  const AppUserModel({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  /// Role check helpers
  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff' || isAdmin;

  /// Returns the initials of the full name for avatar display
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();
  }

  AppUserModel copyWith({
    String? userId,
    String? username,
    String? fullName,
    String? role,
    bool? isActive,
  }) {
    return AppUserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => 'AppUserModel($username, $role)';
}
