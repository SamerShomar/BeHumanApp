import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum UserRole {
  admin,
  manager,
  member,
}

enum UserTeam {
  gaza,
  netherlands,
}

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String email,
    required String name,
    required UserRole role,
    required UserTeam team,
    String? photoUrl,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}

extension AppUserX on AppUser {
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isMember => role == UserRole.member;

  bool get canApprove => role == UserRole.admin || role == UserRole.manager;
  bool get canPropose => true; // All roles can propose
  bool get hasFinancialAccess => role == UserRole.admin || (role == UserRole.manager && team == UserTeam.netherlands);
}
