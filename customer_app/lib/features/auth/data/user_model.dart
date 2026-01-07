import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final int id;
  final String role;
  final String phone;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  final String? level;
  @JsonKey(name: 'ref_code')
  final String? refCode;
  @JsonKey(name: 'ref_count')
  final int? refCount;
  @JsonKey(name: 'profile_photo')
  final String? profilePhoto;
  @JsonKey(name: 'avg_rating')
  final dynamic avgRating; // Can be String or double from JSON
  @JsonKey(name: 'rating_count')
  final int? ratingCount;

  UserModel({
    required this.id,
    required this.role,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.level,
    this.refCode,
    this.refCount,
    this.profilePhoto,
    this.avgRating,
    this.ratingCount,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
