// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      uid: json['uid'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      team: $enumDecode(_$UserTeamEnumMap, json['team']),
      photoPath: json['photoPath'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'email': instance.email,
      'name': instance.name,
      'role': _$UserRoleEnumMap[instance.role]!,
      'team': _$UserTeamEnumMap[instance.team]!,
      'photoPath': instance.photoPath,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.manager: 'manager',
  UserRole.member: 'member',
};

const _$UserTeamEnumMap = {
  UserTeam.gaza: 'gaza',
  UserTeam.netherlands: 'netherlands',
};
