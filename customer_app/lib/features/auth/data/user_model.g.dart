// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: (json['id'] as num).toInt(),
  role: json['role'] as String,
  phone: json['phone'] as String,
  firstName: json['first_name'] as String,
  lastName: json['last_name'] as String,
  level: json['level'] as String?,
  refCode: json['ref_code'] as String?,
  refCount: (json['ref_count'] as num?)?.toInt(),
  profilePhoto: json['profile_photo'] as String?,
  avgRating: json['avg_rating'],
  ratingCount: (json['rating_count'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'role': instance.role,
  'phone': instance.phone,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'level': instance.level,
  'ref_code': instance.refCode,
  'ref_count': instance.refCount,
  'profile_photo': instance.profilePhoto,
  'avg_rating': instance.avgRating,
  'rating_count': instance.ratingCount,
};
