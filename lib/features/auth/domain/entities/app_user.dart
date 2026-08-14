import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';

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

    /// Object path of the avatar inside the storage bucket, not a URL — the
    /// bucket is private, so a viewable link is minted on demand and expires.
    String? photoPath,
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

/// Roles and teams are stored as bare enum names, which are fine as data but
/// were being shown to users as-is — "الفريق: gaza". These resolve them
/// through the translation tables instead.
extension UserRoleL10n on UserRole {
  String label(BuildContext context) =>
      AppLocalizations.of(context, 'role_$name');
}

extension UserTeamL10n on UserTeam {
  String label(BuildContext context) =>
      AppLocalizations.of(context, 'team_$name');
}
